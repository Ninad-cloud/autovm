######[ DEPLOYMENT OF MANILA-SERVICE (FILE SHARING) ]########
#!/bin/sh
source /root/autovm/globalvar.sh

manila_Prereq_controller(){

echo -e "\n\n\e[36m#########[ DEPLOYING MANILA PART ON CONTROLLER NODE ]######### \e[0m\n"
	
	echo -e "\n\e[36m[CONFIGURATION THE MYSQL DB ] \e[0m\n"
	
mysql << EOF
CREATE DATABASE manila;
GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%' IDENTIFIED BY '$COMMON_PASS';
EOF

	sleep 5

###Source the admin credentials
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "----Create Manila User----"
	echo "openstack user create --domain default --password $COMMON_PASS manila"
	openstack user create --domain default --password $COMMON_PASS manila
	
	echo "--Add the Admin Role to the Manila User---"
	echo "openstack role add --project service --user manila admin"
	openstack role add --project service --user manila admin
	
	echo "---Create The Manila & Manilav2 Service Entities---"
	echo "openstack service create --name manila --description "OpenStack Shared File Systems" share"
	openstack service create --name manila --description "OpenStack Shared File Systems" share
	
	echo "openstack service create --name manilav2 --description "OpenStack Shared File Systems V2" sharev2"
	openstack service create --name manilav2 --description "OpenStack Shared File Systems V2" sharev2
	
	echo "--Create API End Points For Manila---"
	echo "openstack endpoint create --region RegionOne share public http://controller:8786/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne share public http://controller:8786/v1/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne share internal http://controller:8786/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne share internal http://controller:8786/v1/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne share admin http://controller:8786/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne share admin http://controller:8786/v1/%\(tenant_id\)s
	
	echo "---Create End Points For Manilav2----"
	echo "openstack endpoint create --region RegionOne sharev2 public http://controller:8786/v2/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne sharev2 public http://controller:8786/v2/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne sharev2 internal http://controller:8786/v2/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne sharev2 internal http://controller:8786/v2/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne sharev2 admin http://controller:8786/v2/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne sharev2 admin http://controller:8786/v2/%\(tenant_id\)s

	sleep 5
	
}

config_manila_controller(){

echo "INSTALLATION AND CONFIGURATION OF MANILA STARTED!!!!"
	
	expect -c '
	spawn apt-get install manila-api manila-scheduler python-manilaclient -y
	expect "*Set up a database for this package*"
	send "\r"
	expect "*Configure RabbitMQ acces with debconf*"
	send "\r"
	expect "*Manage keystone_authtoken with debconf*"
	send "\r"
	expect "*Register this service in the Keystone endpoint catalog*"
	send "\r"
	interact'

	sleep 10
	
	echo "apt install python3-manila-ui"
	apt install python3-manila-ui -y
	
	#Reload and restart apache service
	service apache2 reload
	sleep 5
	service apache2 restart
	sleep 5
	
	filepath1='/etc/manila/manila.conf'
	# Backup the original .conf file
	cp $filepath1 ${filepath1}.bakup
	echo "......Configuration on $filepath1........"
	
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[database\]/ a connection = mysql+pymysql://manila:'$COMMON_PASS'@controller/manila' $filepath1
	
	
	sed -i '/^\[DEFAULT\]/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\ndefault_share_type = default_share_type\nshare_name_template = share-%s\nrootwrap_config = /etc/manila/rootwrap.conf\napi_paste_config = /etc/manila/api-paste.ini\nauth_strategy = keystone\nmy_ip = '$CONTROLLER_MGT_IP'' $filepath1
	
	sed -i 's/^region_name =*/#&/' $filepath1
	
	sed -i 's/^auth_url = http*/#&/' $filepath1
	sed -i 's/^www_authenticate_uri = http*/#&/' $filepath1
		
	sed -i '/^\[keystone_authtoken\]/ a memcached_servers = controller:11211\npassword = '$COMMON_PASS'\nauth_url = http://controller:5000\nwww_authenticate_uri = http://controller:5000' $filepath1
	
	## Populate the database and restart all essential service.
	
	echo "--Populate The Database---"
	echo "su -s /bin/sh -c "manila-manage db sync" manila"
	su -s /bin/sh -c "manila-manage db sync" manila
	sleep 5
	
	echo "--restart All The Essential Services---"
	echo "service manila-scheduler restart"
	service manila-scheduler restart
	sleep 5
	
	echo "service manila-api restart"
	service manila-api restart
	sleep 5
	
	echo "--Verify The Operation---"
	###Source the admin credentials
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"

	echo "manila service-list"
	manila service-list
	

}

config_manila_compute(){

##Install Packages on share-node
echo "---Started Package Intallation on  [ block1 ] (Share) Node---- "

		ssh root@$COMPUTE1_MGT_IP << EOF
	expect -c '
	spawn apt-get install manila-share python-pymysql python-mysqldb -y
	expect "*Set up a database for this package*"
	send "no\r"
	expect "*Configure RabbitMQ acces with debconf*"
	send "no\r"
	expect "*Manage keystone_authtoken with debconf*"
	send "no\r"
	expect "*Register this service in the Keystone endpoint catalog*"
	send "no\r"
	expect EOF'
	exit
EOF

	filepath1='/etc/manila/manila.conf'
	
	ssh root@$COMPUTE1_MGT_IP << COMMANDS
	
	# Backup the original .conf file
	cp $filepath1 ${filepath1}.bakup
	echo "......Configuration on $filepath1........"
	
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[database\]/ a connection = mysql+pymysql://manila:'$COMMON_PASS'@controller/manila' $filepath1
	
	
	sed -i '/^\[DEFAULT\]/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\ndefault_share_type = default_share_type\nrootwrap_config = /etc/manila/rootwrap.conf\nauth_strategy = keystone\nmy_ip = '$COMPUTE1_MGT_IP'\nenabled_share_backends = generic\nenabled_share_protocols = NFS' $filepath1
	
	sed -i 's/^lock_path =*/#&/' $filepath1
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/manila/tmp' $filepath1
	
	##keystone_authtoken Section
	sed -i 's/^region_name =*/#&/' $filepath1
	
	sed -i 's/^auth_url = http*/#&/' $filepath1
	sed -i 's/^www_authenticate_uri = http*/#&/' $filepath1
	
			
	sed -i '/^\[keystone_authtoken\]/ a memcached_servers = controller:11211\npassword = '$COMMON_PASS'\nauth_url = http://controller:5000\nwww_authenticate_uri = http://controller:5000' $filepath1
	
	sed -i '/^\[neutron\]/ a url = http://controller:9696\nwww_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = '$COMMON_PASS'' $filepath1
	
	sed -i '/^\[nova\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = '$COMMON_PASS'' $filepath1
	
	sed -i '/^\[cinder\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = cinder\npassword = '$COMMON_PASS'' $filepath1
	
	sed -i '/#control_exchange = openstack/ a \\\n[generic]\nshare_backend_name = GENERIC\nshare_driver = manila.share.drivers.generic.GenericShareDriver\ndriver_handles_share_servers = True\nservice_instance_flavor_id = 100\nservice_image_name = manila-service-image\nservice_instance_user = manila\nservice_instance_password = manila\ninterface_driver = manila.network.linux.interface.BridgeInterfaceDriver' $filepath1

	##Restart manila-share service
	echo"service manila-share restart"
	service manila-share restart
COMMANDS

##Verify the successful configuration
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "manila service-list"
	manila service-list

##Download the Manila-Service-image before Proceeding Further
echo "Started Downloading Manila-service-image on controller node..."

	if openstack image list | grep "manila-service-image";then
		echo "manila-service-image already exist, IGNORING..!!"
	else
		echo "curl https://tarballs.opendev.org/openstack/manila-image-elements/images/manila-service-image-master.qcow2 | glance image-create --name "manila-service-image" --disk-format qcow2 --container-format bare --visibility public --progress"
		curl https://tarballs.opendev.org/openstack/manila-image-elements/images/manila-service-image-master.qcow2 | glance image-create --name "manila-service-image" --disk-format qcow2 --container-format bare --visibility public --progress || exit
	fi

}

manila_Prereq_controller
config_manila_controller
config_manila_compute


