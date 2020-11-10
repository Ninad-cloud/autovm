#!/bin/sh
source /root/autovm/globalvar.sh

placement_pre(){
echo "CREATE A DATABASE PLACEMENT-----"

mysql << EOF
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$COMMON_PASS';
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

echo "..Create Placement Service and add role to it...."

echo "openstack user create --domain default --password $COMMON_PASS placement"
openstack user create --domain default --password $COMMON_PASS placement
sleep 4

echo "Add the placement user to the service project with the admin role"
echo "openstack role add --project service --user placement admin"
openstack role add --project service --user placement admin
sleep 2

echo "openstack service create --name placement --description "Placement API" placement"
openstack service create --name placement --description "Placement API" placement
sleep 5

echo "Create API end Point for Placement Service...."

echo "openstack endpoint create --region RegionOne placement public http://controller:8778"
openstack endpoint create --region RegionOne placement public http://controller:8778
sleep 5

echo "openstack endpoint create --region RegionOne placement internal http://controller:8778"
openstack endpoint create --region RegionOne placement internal http://controller:8778
sleep 5

echo "openstack endpoint create --region RegionOne placement admin http://controller:8778"
openstack endpoint create --region RegionOne placement admin http://controller:8778
sleep 5

}

placement_config(){

echo "INSTALLATION AND CONFIGURATION OF PlACEMENT STARTED!!!!"
	PKG_FAILED=0
	apt install placement-api -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20

	filepath1=' /etc/placement/placement.conf'
# Backup the original .conf file
	cp $filepath1 ${filepath1}.bakup
	echo "......Configuration on $filepath1........"

	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[placement_database\]/ a connection = mysql+pymysql://placement:'$COMMON_PASS'@controller/placement' $filepath1
	
	grep -q "^auth_strategy = keystone" $filepath1 || sed -i '/^\[api\]/ a auth_strategy = keystone' $filepath1
	
	grep -q "^auth_url = http://controller:5000" $filepath1 || sed -i '/^\[keystone_authtoken\]/ a auth_url = http://controller:5000/v3\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = placement\npassword = '$COMMON_PASS'' $filepath1


	sleep 5
	####Sync the Database###
	echo "Populate the Placement Database......"
	echo "su -s /bin/sh -c "placement-manage db sync" placement"
	su -s /bin/sh -c "placement-manage db sync" placement
	sleep 20
	
	echo "restart apache2"
	echo "service apache2 restart"
	service apache2 restart
	sleep 5
	
	
	echo "..Now Verify Operation with osc-placement..."
	
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "Perform Status Check to See everything is in order.."
	echo "placement-status upgrade check"
	placement-status upgrade check
	sleep 5
	
	echo "Install osc-placement to check against placement API..."
	PKG_FAILED=0
	pip3 install osc-placement || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20
	
	##List Available resource classes
	
	echo "openstack --os-placement-api-version 1.2 resource class list --sort-column name"
	openstack --os-placement-api-version 1.2 resource class list --sort-column name
	
	echo "openstack --os-placement-api-version 1.6 trait list --sort-column name"
	openstack --os-placement-api-version 1.6 trait list --sort-column name

}

placement_pre
placement_config
