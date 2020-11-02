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




