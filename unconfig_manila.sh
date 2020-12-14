##############[ UNDEPLOYING MANILA SERVICE ON CONTROLLER AND BLOCK1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_manila_controller(){
echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETING MANILA DATABASE SERVICE AND USER..."

	##Remove manila service and user
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
	
	if openstack service list | grep manila;then
	    openstack service delete manila
		openstack service delete manilav2
	fi
	
	
	echo "Delete user manila"
	if openstack user list | grep manila;then
		openstack user delete manila
	fi

	##Remove manila service entry bt dopping database
	drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "manila")
	if [ ! -z $drpdb ];
	then
		mysql -u root -p$COMMON_PASS -e "DROP DATABASE manila;DROP USER 'manila'@'localhost';DROP USER 'manila'@'%';"
	fi

	echo "--unconfig manila.conf file ---"
	cp /etc/manila/manila.conf.bakup /etc/manila/manila.conf
	
	service manila-scheduler restart
	service manila-api restart
	
	##remove packages
	echo "..Remove All packages..."
	echo "apt remove manila-api manila-scheduler"
	apt remove manila-api manila-scheduler -y
	
	echo "Purge the packages..."
	echo "apt purge manila-scheduler"
	apt purge manila-scheduler -y
	
	echo "apt purge manila-api"
	apt purge manila-api -y
	sleep 5
	
	#Remove manila-ui
	echo "apt remove python3-manila-ui"
	apt remove python3-manila-ui -y
	
	apt purge python3-manila-ui -y
	
	service apache2 restart
	
	echo -e "\n\e[36m#### [ CONTROLLER ] :  SUCCESSFULLY UNDEPLOYED MANILA #### \e[0m\n"
}

unconfig_manila_compute(){

		ssh root@$COMPUTE1_MGT_IP << COMMANDS
			
		echo "--unconfig manila.conf file ---"
		cp /etc/manila/manila.conf.bakup /etc/manila/manila.conf
		
		echo "..Remove All packages..."
		echo "apt remove manila-share python-pymysql python-mysqldb"
		apt remove manila-share python-pymysql python-mysqldb -y
		
		echo "apt purge manila-share python-pymysql python-mysqldb"
		apt purge manila-share python-pymysql python-mysqldb -y
		
COMMANDS
		
		echo -e "\n\e[36m#### [ COMPUTE1 ] :  SUCCESSFULLY UNDEPLOYED MANILA #### \e[0m\n"

}

unconfig_manila_controller
unconfig_manila_compute
