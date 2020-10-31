#######[ DEPLYOMENT OF SWIFT- OBJECT STORAG ESERVICE ]########################
#Swift Service Does not use SQL DAtabase on the Controller Node
# Swift Service uses Distributed SQlite Databases
#!/bin/sh
source /root/autovm/globalvar.sh
source /root/autovm/chk_Connectivity.sh

swift_prereq_controller(){

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
	
	echo "--------Create Swift User---------------"
	echo "openstack user create --domain default --password $COMMON_PASS swift"
	openstack user create --domain default --password $COMMON_PASS swift
	
	echo "---Add the admin role to the User Swift----"
	echo "openstack role add --project service --user swift admin"
	openstack role add --project service --user swift admin
	
	sleep 2
	echo "----Create Swift Service Entry----"
	echo "openstack service create --name swift --description "OpenStack Object Storage" object-store"
	openstack service create --name swift --description "OpenStack Object Storage" object-store

	echo "---Create Object Storage END API----"
	
	echo "openstack endpoint create --region RegionOne object-store public http://controller:8080/v1/AUTH_%\(project_id\)s"
	openstack endpoint create --region RegionOne object-store public http://controller:8080/v1/AUTH_%\(project_id\)s
	
	echo "openstack endpoint create --region RegionOne object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s"
	openstack endpoint create --region RegionOne object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s
	
	echo "openstack endpoint create --region RegionOne object-store admin http://controller:8080/v1"
	openstack endpoint create --region RegionOne object-store admin http://controller:8080/v1
	
	sleep 2
	
}

controller_config(){

###installing Packages on Controller Node####

	PKG_FAILED=0
#	apt-get install swift swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached -y || PKG_FAILED=1
#	if [ $PKG_FAILED -gt 0 ];then
#		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
#		apt update
#		exit
#	else
#		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
#	fi

#	sleep 15
	
	echo "---Create /etc/swift directory---"
#	mkdir /etc/swift
	
	filepath1='/etc/swift/proxy-server.conf'
	
	if [ ! -f "$filepath1" ];then
		echo "Obtain Object Service Configuration file from the Object Repository--"
		echo "curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/proxy-server.conf-sample"
		curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/proxy-server.conf-sample
	fi
	sleep 5
	
	# Backup the original .conf file
	
	cp $filepath1 ${filepath1}.bak
	
	echo "---STARTED CONFIGURATION-----"
	
	grep -q "^user = swift" $filepath1|| sed -i '/^\[DEFAULT\]/ a user = swift\nswift_dir = \/etc\/swift' $filepath1
	
	sed  -i 's/tempurl ratelimit tempauth copy/ratelimit authtoken keystoneauth/' $filepath1
	
	grep -q "^account_autocreate = True" $filepath1 || sed -i '/^\[app:proxy-server\]/ a account_autocreate = True' $filepath1
	
	sed -i '/^user_test5_tester5 = testing5*/ a \\n[filter:authtoken]\npaste.filter_factory = keystonemiddleware.auth_token:filter_factory\nwww_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_id = default\nuser_domain_id = default\nproject_name = service\nusername = swift\npassword = '$COMMON_PASS'\ndelay_auth_decision = True\n\n[filter:keystoneauth]\nuse = egg:swift#keystoneauth\noperator_roles = admin,myrole' $filepath1
	
	
	grep -q "^memcache_servers = controller:11211" $filepath1 || sed -i '/^\[filter:cache\]/ a memcache_servers = controller:11211' $filepath1

}
	
swift_prereq_controller	
controller_config	
