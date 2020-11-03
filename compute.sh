##############[ DEPLOYING COMUTE SERVICE ON CONTROLLER AND COMPUTE1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh
source /root/autovm/chk_Connectivity.sh
echo "${nodes[@]}"

Nova_Installtion(){
	
	echo -e "\n\n\e[36m#########[ DEPLOYING COMPUTE PART ON CONTROLLER NODE ]######### \e[0m\n"
	
	echo -e "\n\e[36m[CONFIGURATION THE MYSQL DB ] \e[0m\n"

	mysql << EOF
	CREATE DATABASE nova_api;
	CREATE DATABASE nova;
	CREATE DATABASE nova_cell0;
	GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$COMMON_PASS';
	GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$COMMON_PASS';
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$COMMON_PASS';
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$COMMON_PASS';
	GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$COMMON_PASS';
	GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$COMMON_PASS';
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
	sleep 2
	
	
	echo "......Create Nova Service....."
	echo "openstack user create --domain default --password $COMMON_PASS nova"
	openstack user create --domain default --password $COMMON_PASS nova
	sleep 2
	
	echo "Add admin role to nova user....."
	echo "openstack role add --project service --user nova admin"
	openstack role add --project service --user nova admin
	sleep 2
	
	echo "openstack service create --name nova --description "OpenStack Compute" compute"
	openstack service create --name nova --description "OpenStack Compute" compute
	sleep 2
	
	echo "###Create Compute API service endpoints#####"
	
	echo "openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1"
	openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
	sleep 2
	
	echo "openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1"
	openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
	sleep 2
	
	echo "openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1"
	openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
	sleep 2
	
	echo -e "\n\e[36m[COMPUTE SERVICE AND ENDPOINTS ARE CREATED\n"
	
}


Nova_config_controller(){
	
	###Installing Packages####
	echo "INSTALLATION AND CONFIGUATION OF COMPUTE SERVICE ON CONTROLLER NODE STARTED....."

	PKG_FAILED=0
	apt install nova-api nova-conductor nova-novncproxy nova-scheduler -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20
	
	filepath1='/etc/nova/nova.conf'
	# Backup the original .conf file
	
	cp $filepath1 ${filepath1}.bakup

	echo "--------STARTED CONFIGURATION--------"
	#comment the log_dir line under [DEFAULT]
	sed -i 's/^log_dir=*/#&/' $filepath1
	
	sed -i '/^state_path =*/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\nmy_ip = '$CONTROLLER_MGT_IP'\nuse_neutron = true\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver' $filepath1
	
	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[api_database\]/ a connection = mysql+pymysql://nova:'$COMMON_PASS'@controller/nova_api' $filepath1
	

	sed -i '/^\[database\]/ a connection = mysql+pymysql://nova:'$COMMON_PASS'@controller/nova' $filepath1


	sed -i '/^\[api]/ a auth_strategy = keystone\n' $filepath1
	
	
	grep -q "^auth_url = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a auth_url = http://controller:5000/v3\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = '$COMMON_PASS'' $filepath1
	
	grep -q "^enabled_true =" $filepath1 || \
	sed -i '/^\[vnc\]/ a enabled = true\nserver_listen = $my_ip\nserver_proxyclient_address = $my_ip' $filepath1
	
	grep -q "^api_servers" $filepath1 || \
	sed -i '/^\[glance\]/ a api_servers = http://controller:9292' $filepath1
	
	#grep -q "^lock_path" $filepath1 || \
#	grep -q "^lock_path" $filepath1 || \
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/nova/tmp' $filepath1
	
	
	sed -i 's/^os_region_name =/#&/' $filepath1
	grep -q "^region_name =" $filepath1 || \
	sed -i '/^\[placement\]/ a region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://controller:5000/v3\nusername = placement\npassword = '$COMMON_PASS'' $filepath1

	sleep 2
	
	echo "POPULATE THE nova-api DATABASE...."
	echo "su -s /bin/sh -c "nova-manage api_db sync" nova"
	su -s /bin/sh -c "nova-manage api_db sync" nova
	
	sleep 2
	
	echo "REGISTER THE cell0 DATABASE...."
	echo "su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova"
	su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
	
	sleep 2
	
	echo "...CREATE THE cell1 CELL....."

    echo "su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova"
	su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
	
	sleep 2
	
	echo "...POPULATE THE NOVA DATABASE...."
	echo "su -s /bin/sh -c "nova-manage db sync" nova"
	su -s /bin/sh -c "nova-manage db sync" nova
	
	sleep 2
	
	echo "VERIFY THE REGISTRATION OF NOVA cell0 AND cell1"
	echo "su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova"
	su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
	
	sleep 2
	
	echo "RESTART THE COMPUTE SERVICE....."
	echo "service nova-api restart"
	service nova-api restart
	
	sleep 2
	echo "service nova-scheduler restart"
	service nova-scheduler restart
	
	sleep 2
	echo "service nova-conductor restart"
	service nova-conductor restart
	
	sleep 2
	echo "service nova-novncproxy restart"
	service nova-novncproxy restart
	

}

Nova_config_compute(){

echo -e "\n\e[36m######### [ COMPUTE ] : CONFIGURING THE NOVA SERVICE ON COMPUTE NODE ##### \e[0m\n"
echo "$nodes[0]"
echo "#######[ INSTALL AND CONFIGURATION OF NOVA ON COMPUTE NODE ] #########"
PKG_FAILED=0
	
	ssh root@$COMPUTE1_MGT_IP apt install nova-compute -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi
	
	sleep 10

	filepath1='/etc/nova/nova.conf'

	ssh root@$COMPUTE1_MGT_IP << COMMANDS
	
	#Backup the original .conf file

	cp $filepath1 ${filepath1}.bakup

	sed -i 's/^log_dir=*/#&/' $filepath1
	sed -i '/^state_path =*/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\nmy_ip = '$COMPUTE1_MGT_IP'\nuse_neutron = true\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver' $filepath1
	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	sed -i '/^\[database\]/ a connection = mysql+pymysql://nova:'$COMMON_PASS'@controller/nova' $filepath1
	
	sed -i '/^\[api]/ a auth_strategy = keystone\n' $filepath1
	
	grep -q "^auth_url = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a auth_url = http://controller:5000/v3\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = '$COMMON_PASS'' $filepath1
	
	grep -q "^enabled_true =" $filepath1 || \
	sed -i '/^\[vnc\]/ a enabled = true\nserver_listen = 0.0.0.0\nserver_proxyclient_address = '$COMPUTE1_MGT_IP'\nnovncproxy_base_url = http://controller:6080/vnc_auto.html' $filepath1
	
	grep -q "^api_servers" $filepath1 || \
	sed -i '/^\[glance\]/ a api_servers = http://controller:9292' $filepath1
	
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/nova/tmp' $filepath1
	
	sed -i 's/^os_region_name =/#&/' $filepath1
	grep -q "^region_name =" $filepath1 || \
	sed -i '/^\[placement\]/ a region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://controller:5000/v3\nusername = placement\npassword = '$COMMON_PASS'' $filepath1

	
	if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) = "0" ]];then
		sed -i 's/^virt_type=kvm/virt_type = qemu/' "/etc/nova/nova-compute.conf"
	fi
	
	echo "---Restarting Nova-Compute Service----"
	echo "service nova-compute restart" 
	service nova-compute restart
	sleep 5
COMMANDS

	
}	

verify_compute_controller(){

echo "----Verify Successful INstallation of Compute Service on Controller Node-----"
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

echo "Confirm There Are Compute Hosts In The Database"
echo "openstack compute service list --service nova-compute"
openstack compute service list --service nova-compute
sleep 5

echo "Discover Compute Host"
echo "su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova"
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

sleep 5

source ./admin-openrc
echo "$OS_PROJECT_DOMAIN_NAME"
echo "$OS_PROJECT_NAME"
echo "$OS_USER_DOMAIN_NAME"
echo "$OS_USERNAME"
echo "$OS_PASSWORD"
echo "$OS_AUTH_URL"
echo "$OS_IDENTITY_API_VERSION"
echo "$OS_IMAGE_API_VERSION"
sleep 2

openstack compute service list 

echo -e "\n\n\e[36m##### [ COMPUTE_SERVICE ] : SUCCESFULLY DEPLOYED COMPUTE NODE #### \e[0m\n\n"

#####Verify All the Operation#####

echo "openstack catalog list"
openstack catalog list
sleep 2

echo "openstack image list"
openstack image list
sleep 2

echo "nova-status upgrade check"
nova-status upgrade check
sleep 2


}
Nova_Installtion
Nova_config_controller
Nova_config_compute
verify_compute_controller
