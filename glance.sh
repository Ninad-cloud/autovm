#!/bin/sh
source /root/autovm/globalvar.sh

Image_service(){

	
echo "CREATE A DATABASE GLANCE"

mysql << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$COMMON_PASS';
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
echo "CREATE glance user and add admin role to it"
echo "openstack user create --domain default --password $COMMON_PASS glance"
openstack user create --domain default --password $COMMON_PASS glance
sleep 5
echo "openstack role add --project service --user glance admin"
openstack role add --project service --user glance admin
sleep 5

echo "############CREATE GLANCE SERVICE###############"
echo "openstack service create --name glance --description "OpenStack Image" image"
openstack service create --name glance --description "OpenStack Image" image
sleep 5
####Create Image service end-point#####
echo "NOW CREATING IMAGE SERVICE ENDPOINT"
echo "openstack endpoint create --region RegionOne image public http://controller:9292"
openstack endpoint create --region RegionOne image public http://controller:9292
sleep 5
echo "openstack endpoint create --region RegionOne image internal http://controller:9292"
openstack endpoint create --region RegionOne image internal http://controller:9292
sleep 5
echo "openstack endpoint create --region RegionOne image admin http://controller:9292"
openstack endpoint create --region RegionOne image admin http://controller:9292
sleep 5


}

glance_config(){

	echo "INSTALLATION AND CONFIGURATION OF GLANCE STARTED!!!!"
	PKG_FAILED=0
	apt install glance -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20


	filepath1='/etc/glance/glance-api.conf'
# Backup the original .conf file
	cp $filepath1 ${filepath1}.bakup
	echo "......Configuration on $filepath1........"
	
	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	sed -i 's/^backend = sqlal/#&/' $filepath1
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[database\]/ a connection = mysql+pymysql://glance:'$COMMON_PASS'@controller/glance' $filepath1
	
	grep -q "^www_authenticate_uri = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = '$COMMON_PASS'' $filepath1
	
	grep -q "^flavor = keystone" $filepath1 || \
	sed -i '/^\[paste_deploy\]/ a flavor = keystone' $filepath1
	
	grep -q "^stores = file,http" $filepath1 || \
	sed -i '/^\[glance_store\]/ a stores = file,http\ndefault_store = file\nfilesystem_store_datadir = /var/lib/glance/images/' $filepath1
	
######CONFIGURTAION GLANCE REGISTRY SERVICE################
	sleep 5


	filepath2='/etc/glance/glance-registry.conf'
# Backup the original .conf file
	cp $filepath2 ${filepath2}.bakup
	
	echo ".....Configuration on $filepath2....."

	grep -q "^connection = mysql+pymysql" $filepath2 || sed -i '/^\[database\]/ a connection = mysql+pymysql://glance:'$COMMON_PASS'@controller/glance' $filepath2
	
	grep -q "^www_authenticate_uri = http://controller:5000" $filepath2 || \
	sed -i '/^\[keystone_authtoken\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = '$COMMON_PASS'' $filepath2
	
	grep -q "^flavor = keystone" $filepath2 || \
	sed -i '/^\[paste_deploy\]/ a flavor = keystone' $filepath2
	
	echo "POPULATE THE IMAGE SERVICE DATABASE"
	echo -e "\n\e[36m[ GLANCE ] :\e[0m DB_SYNC and SERVICE START"

	# Sync the Database
	echo "su -s /bin/sh -c "glance-manage db_sync" glance"
	su -s /bin/sh -c "glance-manage db_sync" glance
	sleep 20
	# Restart the services
	
	echo -e "\n\e[36m[ GLANCE ] :\e[0m STARTING THE IMAGE SERVICE \n"

########glance-registry service is depricated########
#	echo "sudo service glance-registry restart"
############################################################

	echo "sudo service glance-api restart"
	sudo service glance-api restart
	sleep 10

	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"

	##Download the source image
	
        if [ ! -f "cirros-0.4.0-x86_64-disk.img" ];then
		echo "Downloading cirros-0.4.0-x86_64-disk.img Started......"
		wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
	fi
	sleep 10
	#Upload the image to the image serive
	if openstack image list | grep cirros;then
		echo "Image Already Exist!!!"
	else
		echo "openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public"
		openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
		sleep 5
	fi
	sleep 2

	echo "openstack image list"
	openstack image list
	sleep 2
	check_service=`openstack image list | grep cirros | grep active`
	if [ ! -z "$check_service" ];then
		echo -e "\n\n\n\e[36m[IMAGE SERVICE HAS BEEN INSTALLED SUCCESSFULLLY ] \e[0m\n\n\n"
	else
		echo -e "\n\n\n\e[34m[ IMAGE SERVICE CREATION FAILED>>> EXITING ]\e[0m\n\n\n"
		exit
	fi


}

Image_service
glance_config
