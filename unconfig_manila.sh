##############[ UNDEPLOYING MANILA SERVICE ON CONTROLLER AND BLOCK1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_manial_controller(){
echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETING MANILA DATABASE SERVICE AND USER..."

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

	drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "manila")
	if [ ! -z $drpdb ];
	then
		mysql -u root -p$COMMON_PASS -e "DROP DATABASE manila;DROP USER 'manila'@'localhost';DROP USER 'manila'@'%';"
	fi

	echo "--unconfig manila.conf file ---"
	cp /etc/manila/manila.conf.bakup /etc/manila/manila.conf
	
	service manila-scheduler restart
	service manila-api restart
	
	echo "..Remove All packages..."
	echo "apt remove manila-api manila-scheduler"
	apt remove manila-api manila-scheduler -y
	
	echo "Purge the packages..."
	echo "apt purge manila-scheduler"
	apt purge manila-scheduler
	
	echo "apt purge manila-api"
	apt purge manila-api
	sleep 5
	
	echo -e "\n\e[36m#### [ CONTROLLER ] :  SUCCESSFULLY UNDEPLOYED MANILA #### \e[0m\n"
}

unconfig_manila_block1(){

		ssh root@$BLOCK1_MGT_IP << COMMANDS
			
		echo "--unconfig manila.conf file ---"
		cp /etc/manila/manila.conf.bakup /etc/manila/manila.conf
		
		echo "..Remove All packages..."
		echo "apt remove manila-share python-pymysql python-mysqldb"
		apt remove manila-share python-pymysql python-mysqldb -y
		
		echo "apt purge manila-share python-pymysql python-mysqldb"
		apt purge manila-share python-pymysql python-mysqldb
		
COMMANDS
		
		echo -e "\n\e[36m#### [ BLOCK1 ] :  SUCCESSFULLY UNDEPLOYED MANILA #### \e[0m\n"

}

unconfig_linuxbridge_block1(){

echo -e "\n\e[36m### [ BLOCK1 ] : UNDEPLOYING NEUTRON_LINUXBRIDGE #### \e[0m\n"
	
	ssh root@$COMPUTE1_MGT_IP << COMMANDS
		echo "...Unconfig neutron.conf..."
		cp /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf
		
		echo "..Unconfig Linux-Bridge Agent...."
		cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak /etc/neutron/plugins/ml2/linuxbridge_agent.ini
		
		echo "..Restart AllEssential Services..."
		service nova-compute restart
		service neutron-linuxbridge-agent restart
		
		echo "..Remove Linux_bridge_agent package..."
		apt-get remove neutron-linuxbridge-agent -y
		
		echo "apt purge neutron-linuxbridge-agent"
		apt purge neutron-linuxbridge-agent
		
COMMANDS

#Verify Operation
echo "..Verify Undeployment of Linuxbridge from the block1 node..."
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
	
	echo "openstack network agent list"
	openstack network agent list

	echo -e "\n\e[36m### [ BLOCK1 ] : SUCESSFULLY UNDEPLOYED NEUTRON_LINUXBRIDGE #### \e[0m\n"
}
unconfig_manila_controller
unconfig_manila_block1
unconfig_linuxbridge_block1