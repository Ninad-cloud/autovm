############[ UnConfiguration Of The OpenStack Deployment ]#####################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_hostname(){

###Copy the backup file with the existing
##On Controller Node

	echo "cp /etc/hosts.bak /etc/hosts"
	cp /etc/hosts.bak /etc/hosts

###ON the Other Nodes

	echo "${nodes}"
	for i in "${nodes[@]}"
		do 
			echo "$i"
			scp /etc/hosts root@$i:/etc/
		done
		
	echo -e "\nREMOVING THE HOSTNAME FROM ALL NODES IS DONE...\e[0m \n"	

}

unconfig_Ntp(){
	echo "--Copy the backup file--"
	cp /etc/chrony/chrony.conf.bak /etc/chrony/chrony.conf
	apt remove chrony -y
	apt purge chrony -y
	echo -e "\n\e[36m##### NTP UNCONFIGURATION ON ALL NODES IN PROCESS ##### \e[0m\n"
	
	for i in "${nodes[@]}"
	do
		echo "$i"
		scp /etc/chrony/chrony.conf root@$i:/etc/chrony/chrony.conf
	done
	
	for i in "${nodes[@]}"
	do
		echo "$i"
		ssh root@$i apt remove chrony -y
	done
	
	echo -e "\n\n\e[36m#### NTP UNCONFIGURATION ON ALL NODES IN DONE ####### \e[0m\n"

}


unconfig_Mysql(){

	echo -e "\n\n\e[36m###### MYSQL UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE ###### \e[0m\n"	
	mysql -u root -p$COMMON_PASS -e "DROP DATABASE IF EXISTS nova;"
	service mysql stop
	rm -rf /etc/mysql/mariadb.conf.d/99-openstack.cnf
#	service mysql start
	apt remove mariadb-server python-pymysql -y
	apt purge mariadb-server python-pymysql -y
	
	#remove openstackclient package for Stein
		
	apt remove python3-openstackclient -y
	for i in "${nodes[@]}"
	do
		echo "$i"
		ssh root@$i apt remove python3-openstackclient -y
	done
	
	
	echo -e "\n\n\e[36m######MYSQL UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE IN DONE #### \e[0m\n"

}

unconfig_Rabbitmq(){

	echo -e "\n\n\e[36m## MESSAGE QUEUE (RABBITMQ) UNINSTALL ON CONTROLLER NODE ##### \e[0m\n"

	rabbitmqctl stop_app
#	rabbitmqctl delete_user openstack
	rabbitmqctl reset
	rabbitmqctl start_app

	rabbitmqctl stop_app
	apt remove rabbitmq-server -y
	apt purge rabbitmq-server -y
	echo -e "\n\n\e[36m#### MESSAGE QUEUE (RABBITMQ) UNINSTALL ON CONTROLLER NODE IN DONE ####\e[0m\n"

}

unconfig_Memcached(){

        echo -e "\n\n\e[36m#### MEMCACHED INSTALL AND CONFIGURE ON CONTROLLER NODE ###### \e[0m\n"

        sed -i 's/^-l '$CONTROLLER_MGT_IP'/-l 127.0.0.1/' /etc/memcached.conf
        service memcached restart
		apt remove memcached python-memcache -y
		apt purge memcached python-memcache -y
		
        echo -e "\n\n\e[36m### MEMCACHED UNINSTALL AND UNCONFIGURE ON CONTROLLER NODE IS DONE ##### \e[0m\n"

}

unconfig_etcd(){

	echo "--Reset The original File Using BackUp File---"
	cp /etc/default/etcd.bak /etc/default/etcd

	apt remove etcd -y
	apt purge etcd -y
	echo -e "\n\n\e[36m### ETCD UNINSTALL ON CONTROLLER NODE IS DONE ##### \e[0m\n"
}

######################[ UNCONFIG OPENSTACK SERVICES ]##################

unsetting_openrc(){
	
	unset OS_PROJECT_DOMAIN_NAME
        unset OS_USER_DOMAIN_NAME
        unset OS_PROJECT_NAME
        unset OS_USERNAME
        unset OS_PASSWORD
        unset OS_AUTH_URL
        unset OS_IDENTITY_API_VERSION
        unset OS_IMAGE_API_VERSION

}

unconfig_Identity(){
	
	echo -e "\n\n\n\e[36m####[ KEYSTONE ] : UNDEPLOY IDENTITY SERVICE  ####\e[0m\n\n\n"
		
	#Delete Keystone Service Project user domain and role
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
		
	if openstack service list | grep keystone;then
        	openstack service delete keystone
	fi
	
	if openstack role list | grep myrole;then
		openstack role delete myrole
	fi
	
	if openstack user list | grep myuser;then
		openstack user delete myuser
	fi
	
	if openstack project list | grep myproject;then
		openstack project delete myproject
	fi
	
	if openstack project list | grep service;then
		openstack project delete service
	fi
	
	if openstack domain list | grep example;then
		openstack domain delete example
	fi

	#remove client env. scripts
    echo "..Unset the Env Scripts.."
	unsetting_openrc
	
	if [ -f "./admin-openrc" ];then
		rm ./admin-openrc
	fi
	if [ -f "./demo-openrc" ];then
		rm ./demo-openrc
	fi	

	echo -e "\n\e[36m[ KEYSTONE ] :\e[0m Droping the MYSQL DB.."
	# DROP Mysql datatbse for keystone
	drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "keystone")
	if [ ! -z "$drpdb" ];
	then
		mysql -u root -p$COMMON_PASS -e "DROP DATABASE keystone;DROP USER 'keystone'@'localhost';DROP USER 'keystone'@'%';"
	fi
       	
	echo -e "\n\e[36m[ KEYSTONE ] :\e[0m Removing the config parameter"
	# Remove Config parameter
	cp /etc/keystone/keystone.conf.bak /etc/keystone/keystone.conf
	
	cp /etc/apache2/apache2.conf.bak /etc/apache2/apache2.conf
	
	service apache2 stop
	echo "remove pkgs..."
	apt remove keystone -y
	apt purge keystone -y
	
}



unconfig_glance(){

	echo -e "\n\n\n\e[36m##### [ GLANCE ] : UNDEPLOYING THE GLANCE SERVICE #####\e[0m\n\n\n"

	#Remove image
	echo "rm -rf /var/lib/glance/images/*"
	rm -rf /var/lib/glance/images/*	
	sleep 2
	
	# Remove glance service and user
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "Delete glance service"
	if openstack service list | grep glance;then
        	openstack service delete glance
	fi
	
	echo "Delete user glance"
	if openstack user list | grep glance;then
		openstack user delete glance
	fi
	

    # Droping the Glance Mysql database
	echo -e "\n\e[36m[ GLANCE ] : DROPING THE GLANCE DB....\n"

    drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "glance")
        if [ ! -z $drpdb ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE glance;DROP USER 'glance'@'localhost';DROP USER 'glance'@'%';"
        fi
	
	#Remove all configurations of Glance Service
	echo -e "\n[GLANCE] : REMOVING THE CONFIGURATION PARAMETER\n"
	
	# Unconfigure image config of glance-api
	cp /etc/glance/glance-api.conf.bakup /etc/glance/glance-api.conf
	
	# Configuration parameters of glance-regisery
     cp /etc/glance/glance-registry.conf.bakup /etc/glance/glance-registry.conf

	if [ -f "cirros-0.4.0-x86_64-disk.img" ]; then
		echo "Deleting cirros image"
		rm -rf cirros-0.4.0-x86_64-disk.img
	fi
	
	echo "--Remove All the existing Images--"
	rm -rf *.img*
	
	echo "--Restart Service--"
	service glance-registry restart
	service glance-api restart

	# Remove packages
	echo "Verify Undeployment of glance"
	openstack image list
	apt remove glance -y
	apt purge glance -y

	echo -e "\n\n\e[36m###[ GLANCE ] : SUCCESSFULLY UNINSTALLED GLACE IMAGE SERVICE ###\e[0m\n\n\n"
	
}

unconfig_placement(){

	#Remove placement service and user
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

	echo "Delete glance service"
	
	if openstack service list | grep placement;then
        	openstack service delete placement
	fi
	
	echo "Delete user placement"
	if openstack user list | grep placement;then
		openstack user delete placement
	fi
	

    # Droping the Placement Mysql database
	echo -e "\n\e[36m[ PLACEMENT ] : DROPING THE PLACEMENT DB....\n"

    drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "placement")
        if [ ! -z $drpdb ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE placement;DROP USER 'placement'@'localhost';DROP USER 'placement'@'%';"
        fi
	
	#Remove all configurations of Placement Service
	echo -e "\n[PLACEMENT] : REMOVING THE CONFIGURATION PARAMETER\n"
	
	# Unconfigure Placement
	cp /etc/placement/placement.conf.bakup /etc/placement/placement.conf
	
	echo "Restart Services"
	service apache2 restart
	
	# Remove Packages
	echo "Removing pkgs..."
	apt remove placement-api -y
	apt purge placement-api -y


}

unconfig_nova_controller(){

echo -e "\n\e[36m###### [ CONTROLLER ] : UNINSTALL COMPUTE SERVICE #######\e[0m\n\n"


	# Remove all the instance , before deleting actual service.
	echo -e "\n\n\e[36m[ CONTROLLER ] : DEELETING ALL VIRTUAL MACHINES.. #### \e[0m\n"
    
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
#	for instance_id in `nova list --all-tenants | awk '{ print $2 }'`;
#	do
#	    if [ "$instance_id" == "ID" ];then
#		    echo $instance_id
#	    else
#		    nova delete $instance_id
#	    fi
#		sleep 5
 #      done

  #  sleep 10

	# Delete Service, which eventually delete all the endpoints
        echo -e "\n\e[36m[ COMPUTE_ON_CONTROLLER ] :\e[0m DELETE NOVA COMPUTE SERVICE...."
	
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	if openstack service list | grep nova;then
		openstack service delete nova
	fi
	
	echo "Delete user nova"
	if openstack user list | grep nova;then
		openstack user delete nova
	fi
	
	
	# Droping the compute databases-nova_api and nova.
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DROPPING COMPUTE NOVA MYSQL DB...."
	
	drpdb1=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "nova_api")
        if [ ! -z $drpdb1 ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE nova_api;DROP USER 'nova'@'localhost';DROP USER 'nova'@'%';"
                #mysql -u root -p$COMMON_PASS -e "DROP DATABASE nova_api;"
        fi

	drpdb2=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "nova")
        if [ ! -z $drpdb2 ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE nova;"
        fi
	
	drpdb3=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "nova_cell0")
        if [ ! -z $drpdb3 ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE nova_cell0;"
        fi

	echo "Removing Configuration from nova.conf"
	cp /etc/nova/nova.conf.bakup /etc/nova/nova.conf
	sleep 2
	
	ERROR=""
	echo "Restart The All Services....."
	service nova-api restart || ERROR="yes"
	service nova-scheduler restart || ERROR="yes"
	service nova-conductor restart || ERROR="yes"
	service nova-novncproxy restart || ERROR="yes"
	
	##Remove Packages
	echo "..Removing pkgs..."
	apt remove nova-api nova-conductor nova-novncproxy nova-scheduler nova-placement-api -y
	apt purge nova-api nova-conductor nova-novncproxy nova-scheduler nova-placement-api -y
	
	if [ ! -z $ERROR ];then
		echo -e "\n\n\n\e[36mERROR OCCURED in CONTROLLER_NODE, EXITING. RECTIFY ERROR \e[0m\n\n"
		exit
	fi
	echo -e "\n\n\n\e[36m#####[ CONTROLLER ] : SUCCESFULLY UNDEPLOYED COMPUTE ###### \e[0m\n\n\n"

}

unconfig_nova_compute(){
	echo -e "\n\e[36m#### [ COMPUTE1 ] : UNDEPLOYING COMPUTE SERVICE ####\e[0m\n"
    
	##Unconfig nova.conf file
	ssh root@$COMPUTE1_MGT_IP << COMMANDS
	
	cp /etc/nova/nova.conf.bakup /etc/nova/nova.conf
	echo "---Restarting Nova-Compute Service----"
	echo "service nova-compute restart" 
	service nova-compute restart
	echo "Removing pkg..."
	apt remove nova-compute -y
	apt purge nova-compute -y
	
	sleep 2
COMMANDS
echo -e "\n\n\n\e[36m#####[ COMPUTE1 ] : SUCCESFULLY UNDEPLOYED COMPUTE ###### \e[0m\n\n\n"

}

unconfig_neutron_controller(){
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETE NEUTRON SERVICE...."
	echo "Before deleting Neutron Service Make sure Your Instances are deleted...."
	sleep 10
	
	##Remove naetwork service and user
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	if openstack service list | grep neutron;then
		openstack service delete neutron
	fi
	
	echo "Delete user neutron"
	if openstack user list | grep neutron;then
		openstack user delete neutron
	fi
	
	
	# Droping the Neutron.
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DROPPING NEUTRON MYSQL DB...."
	
	drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "neutron")
        if [ ! -z $drpdb ];
        then
                mysql -u root -p$COMMON_PASS -e "DROP DATABASE neutron;DROP USER 'neutron'@'localhost';DROP USER 'neutron'@'%';"
        fi
		
	##unconfig neutron.conf
	cp /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf
	
	##unconfig Network Option-2
	cp /etc/neutron/plugins/ml2/ml2_conf.ini.bak /etc/neutron/plugins/ml2/ml2_conf.ini
	
	##Unconfig Linux Bridge Agent
	cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak /etc/neutron/plugins/ml2/linuxbridge_agent.ini
	
	##UNconfig Layer-3
	cp /etc/neutron/l3_agent.ini.bak /etc/neutron/l3_agent.ini
	
	##Unconfig DHCP
	cp /etc/neutron/dhcp_agent.ini.bak /etc/neutron/dhcp_agent.ini
	
	##Unconfig Metadata
	cp /etc/neutron/metadata_agent.ini.bak /etc/neutron/metadata_agent.ini
	
	##Unconfig neutron from nova.conf
	
        sed -i '/url = http/,+10d' /etc/nova/nova.conf
		
	echo "...Restart All the Essential Services"
	ERROR=""
	#Restart the Compute-API service
	service nova-api restart || ERROR="yes"

    #Restart the Networking services
	
    service neutron-server restart || ERROR="yes"
    service neutron-linuxbridge-agent restart || ERROR="yes"
    service neutron-dhcp-agent restart || ERROR="yes"
    service neutron-metadata-agent restart || ERROR="yes"

    #Restart the layer-3 service:
    service neutron-l3-agent restart || ERROR="yes"
	
	if [ ! -z $ERROR ];then
		echo -e "\n\n\n\e[36mERROR OCCURED IN NEUTRON_ON_CONTROLLER_NODE. EXITING!!!!CHECK FOR THE ERROR & RERUN THE SCRIPT \e[0m\n\n"
		exit
    fi
	
	##Remove Packages
	echo "removing pkgs..."
	apt remove neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y
	
	apt purge neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y
	echo -e "\n\n\n\e[36m###### [ CONTROLLER ] : SUCCESFULLY UNDEPLOYED NEUTRON #### \e[0m\n\n\n"
	

}

unconfig_neutron_compute(){
	
	echo -e "\n\e[36m### [ COMPUTE1 ] : UNDEPLOYING NEUTRON #### \e[0m\n"
	
	ssh root@$COMPUTE1_MGT_IP << COMMANDS
		echo "...Unconfig neutron.conf..."
		cp /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf
		
		echo "..Unconfig Linux-Bridge Agent...."
		cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak /etc/neutron/plugins/ml2/linuxbridge_agent.ini
		
		echo "..Unconfig nova.conf...."
		sed -i '/url = http/,+8d' /etc/nova/nova.conf
		
		echo "..Restart AllEssential Services..."
		service nova-compute restart
		service neutron-linuxbridge-agent restart
		
		echo "..Remove Linux_bridge_agent package..."
		apt-get remove neutron-linuxbridge-agent -y
		apt purge neutron-linuxbridge-agent -y
		
COMMANDS

	echo -e "\n\e[36m### [ COMPUTE1 ] : SUCESSFULLY UNDEPLOYED NEUTRON #### \e[0m\n"
}

unconfig_neutron_controller
unconfig_neutron_compute
unconfig_nova_controller
unconfig_nova_compute
unconfig_placement
unconfig_glance
unconfig_Identity
unconfig_etcd
unconfig_Memcached
unconfig_Rabbitmq
unconfig_Mysql
unconfig_Ntp
unconfig_hostname
