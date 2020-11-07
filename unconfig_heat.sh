##############[ UNDEPLOYING ORCHESTRATION SERVICE ON CONTROLLER NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_heat(){

	echo -e "\n\e[36m#####[ CONTROLLER ] : UNDEPLOYING HEAT ######\e[0m\n"
	sleep 5
	
	# Delete Heat Service, which eventually delete all the endpoints
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETING THE HEAT SERVICE.."

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
	
	#chk_heat_stack_user=`openstack role list | grep heat_stack_user`

			
	if openstack service list | grep heat;then
       		 openstack service delete heat
		openstack service delete heat-cfn
	else
		echo -e "\n\e[36m[ CONTROLLER ] :\e[0m HEAT SERVICE AND API ENDPOINTS DOESN'T EXIST, IGNORING..!!\n"
	fi
			
			
    # Droping the compute databases-manila
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DROPING HEAT DATABASE"
    drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "heat")
   
    if [ ! -z $drpdb ];
    then
		mysql -u root -p$COMMON_PASS -e "DROP DATABASE heat;DROP USER 'heat'@'localhost';DROP USER 'heat'@'%';"
    fi

	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETING HEAT DOMAIN, USER AND ROLES"
		
	if openstack role list | grep heat_stack_user; then
		if openstack domain list | grep heat;
		then
			echo "First disable the domain heat"
			openstack domain set --disable heat
			echo "deleting the domain heat"
			openstack domain delete heat
		fi
		
		if openstack user list | grep heat;
		then
			openstack user delete heat
			#openstack user delete heat_domain_admin
		fi
		
		if openstack role list | grep heat_stack_owner;
		then
			openstack role delete heat_stack_owner
			openstack role delete heat_stack_user
		fi
		
		
	
	else
		echo -e "\n\e[36m[ HEAT_ON_CONTROLLER ] :\e[0m HEAT DOMAIN, USERS. ROLES FOR HEAT STACK ALREADY EXIST, IGNORING..!!\n"
    fi


	#Removing the configuration parameters from heat.conf file.
	cp /etc/heat/heat.conf.bak /etc/heat/heat.conf
	
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m SERVICE RESTART AFTER HEAT CONFIGURATION REMOVAL\n"

    service heat-api restart
	service heat-api-cfn restart
	service heat-engine restart


	echo -e "\n\e[36m######[ CONTROLLER ] : SUCCESSFULLY UNDEPLOYED HEAT ######\e[0m\n"
	

}

unconfig_heat
