##############[ UNDEPLOYING BLOCK STORAGE SERVICE ON CONTROLLER AND BLOCK1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_controller(){

 echo -e "\n\e[36m###[ CONTROLLER ] : UNDEPLOYING CINDER ###\e[0m\n"

	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m DELETING CINDER VOLUMES..."

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

	for volume in `cinder list --all-tenants | grep false | awk '{print $2}'`;
	do
		cinder delete $volume
	done
	
	sleep 10 
	# Delete Service, which eventually delete all the endpoints
	echo -e "\n\e[36m[ CONTROLLER ] :\e[0m CINDER SERVICE DELETING.."
	
	
	if openstack service list | grep cinderv;then
	    openstack service delete cinderv2
		openstack service delete cinderv3
	fi
	
	
	echo "Delete user cinder"
	if openstack user list | grep cinder;then
		openstack user delete cinder
	fi

	drpdb=$(mysql -uroot -p$COMMON_PASS -e "SHOW DATABASES;" | grep "cinder")
	if [ ! -z $drpdb ];
	then
		mysql -u root -p$COMMON_PASS -e "DROP DATABASE cinder;DROP USER 'cinder'@'localhost';DROP USER 'cinder'@'%';"
	fi
	
	echo "--unconfig Cinder.conf file ---"
	cp /etc/cinder/cinder.conf.bak /etc/cinder/cinder.conf
	echo "---remove entry of cinder from nova.conf"
	sed -i '/os_region_name = RegionOne/d' /etc/nova/nova.conf

	echo "Restarting essential service...."
	service nova-api restart
	service cinder-scheduler restart
	service apache2 restart
	
	#Remove cinder packages
	apt remove cinder-api cinder-scheduler -y
	apt purge cinder-api cinder-scheduler -y

	echo -e "\n\e[36m### [ CONTROLLER ] : SUCCESSFULLY UNDEPLOYED CINDER ####### \e[0m\n"

}

remove_undelete_volumes(){

	echo "service tgt stop"
	service tgt stop

	#IFS=''

	for logical_volume in `lvdisplay | grep "LV Path" | awk '{print $3}'`;
	do
        	echo "Removing Logical volume $logical_volume"

        	expect -c '
        	spawn lvremove '$logical_volume'
        	expect "Do you really want to remove*"
        	send "y\r"
        	expect EOF'

        	echo "Successfully Removed Logical volume $logical_volume"
	done

	for volume_group in `vgdisplay | grep "VG Name" | awk '{print $3}'`;
	do
        	echo "Removing Logical volume $volume_group"
        	expect -c '
        	spawn vgremove '$volume_group'
        	expect "Do you really want to remove*"
        	send "y\r"
        	expect EOF'

   #     	vgremove $volume_group

        	echo "Successfully Removed Logical volume $volume_group"
	done

	if pvdisplay;then
		echo "Removing Physical Volume"
		pvremove /dev/$1
		echo "Successfully Removed Physical Volume"
	fi

}

unconfig_block1(){

echo -e "\n\e[36m######### [ BLOCK1 ] :  UNDEPLOY CINDER  ###### \e[0m\n"
	sleep 10

	#The Block Storage service creates logical volumes in this volume group.

    echo -e "\n\e[36m[ BLOCK1 ] :\e[0m REMOVE LVM FROM BLOCK STORAGE"

    ##if the cinder volume already exist
    vg_present=$(ssh root@$BLOCK1_MGT_IP vgdisplay | grep cinder-volumes)
        
#	file="/etc/lvm/lvm.conf"
#  file1="/etc/cinder/cinder.conf"

	sleep 10

    #Remote configuration of BLOCK Storage node.
    ssh root@$BLOCK1_MGT_IP << COMMANDS
			
		echo "unconfig cinder.conf file---"
		cp /etc/cinder/cinder.conf.bak /etc/cinder/cinder.conf
		
		echo "unconfig lvm.conf file--"
		cp /etc/lvm/lvm.conf.bak /etc/lvm/lvm.conf
		
		`declare -f remove_undelete_volumes`
		remove_undelete_volumes $BLOCK1_LVM_DISKNAME

		
		echo "__Restart The Services--"
		service tgt restart
        service cinder-volume restart
		apt remove cinder-volume -y
		apt purge cinder-volume -y

COMMANDS
		
		echo -e "\n\e[36m#### [ BLOCK1 ] :  SUCCESSFULLY UNDEPLOYED CINDER #### \e[0m\n"


}

unconfig_controller
unconfig_block1
