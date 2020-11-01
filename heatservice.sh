#######################[ ORCHESTRATION SERVICE (HEAT) ]###############

#!/bin/sh
source /root/autovm/globalvar.sh

heat_pre(){

echo -e "\n\n\e[36m#########[ DEPLOYING HEAT SERIVE ON CONTROLLER NODE ]######### \e[0m\n"
	
	echo -e "\n\e[36m[CONFIGURATION THE MYSQL DB ] \e[0m\n"
	
mysql << EOF
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY '$COMMON_PASS';
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
	
	echo "--Create The Heat User-----"
	echo "openstack user create --domain default --password $COMMON_PASS heat"
	openstack user create --domain default --password $COMMON_PASS heat
	
	echo "--Add the Admin Role To The Heat User---"
	echo "openstack role add --project service --user heat admin"
	openstack role add --project service --user heat admin
	
	echo "--Create Heat And Heat-cfn Service Entities---"
	echo "openstack service create --name heat --description "Orchestration" orchestration"
	openstack service create --name heat --description "Orchestration" orchestration
	
	echo "openstack service create --name heat-cfn --description "Orchestration"  cloudformation"
	openstack service create --name heat-cfn --description "Orchestration"  cloudformation
	sleep 2
	
	echo "Create the Orchestration service API endpoints"
	echo "openstack endpoint create --region RegionOne orchestration public http://controller:8004/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne orchestration public http://controller:8004/v1/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne orchestration internal http://controller:8004/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne orchestration internal http://controller:8004/v1/%\(tenant_id\)s
	
	echo "openstack endpoint create --region RegionOne orchestration admin http://controller:8004/v1/%\(tenant_id\)s"
	openstack endpoint create --region RegionOne orchestration admin http://controller:8004/v1/%\(tenant_id\)s
	
	sleep 2
	echo "openstack endpoint create --region RegionOne cloudformation public http://controller:8000/v1"
	openstack endpoint create --region RegionOne cloudformation public http://controller:8000/v1
	
	echo "openstack endpoint create --region RegionOne cloudformation internal http://controller:8000/v1"
	openstack endpoint create --region RegionOne cloudformation internal http://controller:8000/v1
	
	echo "openstack endpoint create --region RegionOne cloudformation admin http://controller:8000/v1"
	openstack endpoint create --region RegionOne cloudformation admin http://controller:8000/v1
	
	sleep 5
	echo "----Create The Heat Domain---"
	echo "openstack domain create --description "Stack projects and users" heat"
	openstack domain create --description "Stack projects and users" heat
	
	echo "openstack user create --domain heat --password $COMMON_PASS heat_domain_admin"
	openstack user create --domain heat --password $COMMON_PASS heat_domain_admin
	
	echo "openstack role add --domain heat --user-domain heat --user heat_domain_admin admin"
	openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
	
	echo "--Create Heat Stack Owner---"
	echo "openstack role create heat_stack_owner"
	openstack role create heat_stack_owner
	
	echo "openstack role add --project myproject --user myuser heat_stack_owner"
	openstack role add --project myproject --user myuser heat_stack_owner
	
	echo "openstack role create heat_stack_user"
	openstack role create heat_stack_user
	sleep 5

}

Heat_config(){
	
	###installing Packages on Controller Node####

	PKG_FAILED=0
	apt-get install heat-api heat-api-cfn heat-engine -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 15
	filepath1='/etc/heat/heat.conf'
	cp $filepath1 ${filepath1}.bak
	echo -e "\n\e[36m[ HEAT_ON_CONTROLLER ] :\e[0m SETTING HEAT CONFIGURATION PARAMETER"
	
	grep -q "^connection = mysql+pymysql" $filepath1 || \
    sed -i '/^\[database\]/ a connection = mysql+pymysql://heat:'$COMMON_PASS'@controller/heat' $filepath1
		
	grep -q "^transport_url =" $filepath1 || \
	sed -i '/^\[DEFAULT\]/ a \\ntransport_url = rabbit://openstack:'$COMMON_PASS'@controller\nheat_metadata_server_url = http://controller:8000\nheat_waitcondition_server_url = http://controller:8000/v1/waitcondition\nstack_domain_admin = heat_domain_admin\nstack_domain_admin_password = '$COMMON_PASS'\nstack_user_domain_name = heat' $filepath1
	
	grep -q "^auth_uri =" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a \\nauth_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = heat\npassword = '$COMMON_PASS'' $filepath1
	
	
#	grep -q "^auth_type =" $filepath1 || \
	sed -i '/^\[trustee\]/ a \\nauth_type = password\nauth_url = http://controller:5000\nusername = heat\npassword = '$COMMON_PASS'\nuser_domain_name = default' $filepath1

#	grep -q "^auth_uri =" $filepath1 || \
	sed -i '/^\[clients_keystone\]/ a \\nauth_uri = http://controller:5000' $filepath1
	sleep 5
	##### Populate The Datatabse #############
	echo "---Populate The Orchestration Database---"
	echo "su -s /bin/sh -c "heat-manage db_sync" heat"
	su -s /bin/sh -c "heat-manage db_sync" heat
	
	####### Restart The Orchestration Services #####
	
	echo "service heat-api restart"
	service heat-api restart
	sleep 2
	
	echo "service heat-api-cfn restart"
	service heat-api-cfn restart
	sleep 2
	
	echo "service heat-engine restart"
	service heat-engine restart
	sleep 2
	
}

Verify_heatOp(){

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
	
	echo "--List service components to verify successful launch and registration of each process--"
	echo "openstack orchestration service list"
	openstack orchestration service list
	
}


heat_pre
Heat_config
Verify_heatOp
