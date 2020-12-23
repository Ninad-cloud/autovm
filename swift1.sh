#######[ DEPLYOMENT OF SWIFT-OBJECT STORAG ESERVICE ]########################
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
	echo "openstack service create --name swift --description OpenStack Object Storage object-store"
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
	apt-get install swift swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 15
	
	echo "---Create /etc/swift directory---"
	if [ ! -d /etc/swift ];then
		mkdir /etc/swift
	fi
	filepath1='/etc/swift/proxy-server.conf'
	
	if [ ! -f "$filepath1" ];then
		echo "Obtain Object Service Configuration file from the Object Repository--"
		echo "curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/proxy-server.conf-sample"
		curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/proxy-server.conf-sample
	fi
	sleep 5
	# Backup the original .conf file
	
	cp $filepath1 ${filepath1}.bakup
	
	echo "---STARTED CONFIGURATION-----"
	
	grep -q "^user = swift" $filepath1|| sed -i '/^\[DEFAULT\]/ a user = swift\nswift_dir = \/etc\/swift' $filepath1
	sed  -i 's/tempurl ratelimit tempauth copy/ratelimit authtoken keystoneauth/' $filepath1
	
	grep -q "^account_autocreate = True" $filepath1 || \
	sed -i '/^\[app:proxy-server\]/ a account_autocreate = True' $filepath1
	sed -i '/^user_test5_tester5 = testing5*/ a \\n[filter:authtoken]\npaste.filter_factory = keystonemiddleware.auth_token:filter_factory\nwww_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_id = default\nuser_domain_id = default\nproject_name = service\nusername = swift\npassword = '$COMMON_PASS'\ndelay_auth_decision = True\n\n[filter:keystoneauth]\nuse = egg:swift#keystoneauth\noperator_roles = admin,myrole' $filepath1
	
	
	grep -q "^memcache_servers = controller:11211" $filepath1 || sed -i '/^\[filter:cache\]/ a memcache_servers = controller:11211' $filepath1

sleep 5
}

object_config(){

#nstall and configure storage nodes that operate the account, container, and object services
	sleep 5
	echo "${object_node[@]}"
	echo "$OBJECT_DISK1"
	echo "$OBJECT_DISK2"
	
	filepath1="/etc/fstab"
	filepath2="/etc/rsyncd.conf"
	filepath3="/etc/default/rsync"
	
	
	for i in "${object_node[@]}"
	do
		echo -e "\n\e[36m#### [ SWIFT_ON_OBJECT: ] :  DEPLOY SWIFT ON OBJECT NODE ###### \e[0m\n"
		echo "[ object_node $i ]"
		disk1_formated=$(ssh root@$i fsck -N /dev/$OBJECT_DISK1 | grep xfs)
		echo "$disk1_formated"
		disk2_formated=$(ssh root@$i fsck -N /dev/$OBJECT_DISK2 | grep xfs)
		echo "$disk2_formated"
		
	done

	#configuration of OBJECT Storage node.
      
	for i in "${object_node[@]}"
	do
		echo "[ object_node $i ]"
		sleep 2
		ssh root@$i  << COMMANDS

		echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m FORMATING DISK'S WITH XFS AND MOUNTING ON OBJECT NODE"
		echo "DISK1: $OBJECT_DISK1"
		echo "DISK2: $OBJECT_DISK2"
		PKG_FAILED=0
		apt-get install xfsprogs rsync -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			apt update
			exit
		else
			echo -e "\n--- $i PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
		fi
		
			if [ -z "$disk1_formated" ];then
				echo "mkfs.xfs -f /dev/$OBJECT_DISK1"
				sleep 2
				mkfs.xfs -f /dev/$OBJECT_DISK1
			fi
			
			if [ -z "$disk2_formated" ];then
				echo "mkfs.xfs -f /dev/$OBJECT_DISK2"
				sleep 2
				mkfs.xfs -f /dev/$OBJECT_DISK2
			fi
			sleep 2
			echo "Create Mount Point Directory Structure"
			if [ ! -d "/srv/node/$OBJECT_DISK2" ]; then
				echo "mkdir -p /srv/node/$OBJECT_DISK1"
				sleep 2
				mkdir -p /srv/node/$OBJECT_DISK1
				sleep 2	
				echo "mkdir -p /srv/node/$OBJECT_DISK2"
				mkdir -p /srv/node/$OBJECT_DISK2
			fi
			
			##Backup of the all Files
			cp $filepath1 ${filepath1}.bakup
			cp $filepath3 ${filepath3}.bakup
			
			echo "--Edit /etc/fstab File---"
			sleep 2
			grep -q "^\/dev\/$OBJECT_DISK2" $filepath1 || \
			sed -i '$ a /dev/'$OBJECT_DISK1'        /srv/node/'$OBJECT_DISK1'   xfs     noatime,nodiratime,nobarrier,logbufs=8 0 2\n/dev/'$OBJECT_DISK2'        /srv/node/'$OBJECT_DISK2'   xfs     noatime,nodiratime,nobarrier,logbufs=8 0 2' $filepath1
			
			sleep 2

			echo "--Mount The Device---"
			if mount | grep -q /dev/$OBJECT_DISK2; then
				echo "DEVICES ARE ALREDY MOUNTED"
			else
				echo "MOUNTING THE OBJECT HARD DRIVES"
				mount /srv/node/$OBJECT_DISK1
				mount /srv/node/$OBJECT_DISK2
			fi
			
			echo "---Create And Edit /etc/rsyncd.conf---"
			
			echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m CONFIGURE RSYNC ON OBJECT STORAGE NODE"
			
			if [ ! -f "$filepath2" ];then
			   echo "####rsync serice####" > /etc/rsyncd.conf
			   grep -q "^lock file = \/var\/lock\/object.lock" /etc/rsyncd.conf || \
			   sed -i '$ a uid = swift\ngid = swift\nlog file = /var/log/rsyncd.log\npid file = /var/run/rsyncd.pid\naddress = '$i'\n\n[account]\nmax connections = 2\npath = /srv/node/\nread only = False\nlock file = /var/lock/account.lock\n\n[container]\nmax connections = 2\npath = /srv/node/\nread only = False\nlock file = /var/lock/container.lock\n\n[object]\nmax connections = 2\npath = /srv/node/\nread only = False\nlock file = /var/lock/object.lock' /etc/rsyncd.conf
			fi

			sleep 2
			sed -i 's/^RSYNC_ENABLE=false/RSYNC_ENABLE=true/' $filepath3

		echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m STARTING RSYNC SERVICE ON OBJECT STORAGE NODE"
		echo "service rsync start"
		service rsync start
		
		echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m SWIFT COMPONENTS CONFIGURATION"
		
		###installing Packages on OBJECT NODE:####

		PKG_FAILED=0
		apt-get install swift swift-account swift-container swift-object -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			apt update
			exit
		else
			echo -e "\n--- $i PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
		fi
	sleep 2	
		if [ ! -f /etc/swift/account-server.conf.bak ];then
			curl -o /etc/swift/account-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/account-server.conf-sample
			cp /etc/swift/account-server.conf /etc/swift/account-server.conf.bak
		fi
		sleep 2
	
		if [ ! -f /etc/swift/container-server.conf.bak ];then
			curl -o /etc/swift/container-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/container-server.conf-sample
			cp /etc/swift/container-server.conf /etc/swift/container-server.conf.bak
		fi
		
		sleep 2
		if [ ! -f /etc/swift/object-server.conf.bak ];then
			curl -o /etc/swift/object-server.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/object-server.conf-sample
			cp /etc/swift/object-server.conf /etc/swift/object-server.conf.bak
		fi
		
		sleep 2
		###### CONFIG /etc/swift/account-server.conf #####
		sed -i '/^bind_port = 6202*/ a bind_ip = $i\nuser = swift\nswift_dir = /etc/swift\ndevices = /srv/node\nmount_check = True' /etc/swift/account-server.conf
		
		sed -i '/^\[filter:recon\]/ a recon_cache_path = /var/cache/swift' /etc/swift/account-server.conf
		sleep 2
		
		##### CONFIG /etc/swift/container-server.conf #####
		sed -i '/^bind_port = 6201*/ a bind_ip = $i\nuser = swift\nswift_dir = /etc/swift\ndevices = /srv/node\nmount_check = True' /etc/swift/container-server.conf
		
		sed -i '/^\[filter:recon\]/ a recon_cache_path = /var/cache/swift' /etc/swift/container-server.conf 
		sleep 2
		
		##### CONFIG  /etc/swift/object-server.conf ######
		sed -i '/^bind_port = 6200*/ a bind_ip = $i\nuser = swift\nswift_dir = /etc/swift\ndevices = /srv/node\nmount_check = True' /etc/swift/object-server.conf
		
		sed -i '/^\[filter:recon\]/ a recon_cache_path = /var/cache/swift\nrecon_lock_path = /var/lock' /etc/swift/object-server.conf
		sleep 2
		
		echo -e "\n\e[36m[ SWIFT_ON_OBJECT: $i ] :\e[0m SETTING RIGHT OWNERSHIP ON SWIFT CONFIGURATION DIRECTORY'S."
		
		echo "chown -R swift:swift /srv/node"
		chown -R swift:swift /srv/node
		
		if [ ! -d "/var/cache/swift" ]; then
			echo "mkdir -p /var/cache/swift"
			mkdir -p /var/cache/swift
		fi

		echo "chown -R root:swift /var/cache/swift"
		chown -R root:swift /var/cache/swift
		
		echo "chmod -R 775 /var/cache/swift"
		chmod -R 775 /var/cache/swift
COMMANDS
	done
			
	sleep 10	

}

Create_accnt_ring(){
	##This Funcion Create Account Ring tom maintain lists of containers#
	echo "----Create Account Ring---"
	cd /etc/swift
	pwd

	echo "Create the base account.builder---"
	#echo "swift-ring-builder account.builder create 10 3 1"
	echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m CREATE SWIFT ACCOUNT RING ON CONTROLLER NODE"
		if [ ! -f "/etc/swift/account.ring.gz" ]; then
			swift-ring-builder account.builder create 10 3 1
			echo "swift-ring-builder account.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6202 --device $OBJECT1_DISK1 --weight 100"
			swift-ring-builder account.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6202 --device $OBJECT1_DISK1 --weight 100
			echo "swift-ring-builder account.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6202 --device $OBJECT1_DISK2 --weight 100"
			swift-ring-builder account.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6202 --device $OBJECT1_DISK2 --weight 100
			echo "swift-ring-builder account.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6202 --device $OBJECT2_DISK1 --weight 100"
			swift-ring-builder account.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6202 --device $OBJECT2_DISK1 --weight 100
			echo "swift-ring-builder account.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6202 --device $OBJECT2_DISK2 --weight 100"
			swift-ring-builder account.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6202 --device $OBJECT2_DISK2 --weight 100
			

			echo "Verify the Ring Contents:"
			swift-ring-builder account.builder
			
			echo "Rbalnce The Ring"
			swift-ring-builder account.builder rebalance
			sleep 2
		fi
	#Create container ring
        echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m CREATE SWIFT CONTAINER RING ON CONTROLLER NODE"
		
		if [ ! -f "/etc/swift/container.ring.gz" ];then
			swift-ring-builder container.builder create 10 3 1
			echo "swift-ring-builder container.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6201 --device $OBJECT1_DISK1 --weight 100"
			swift-ring-builder container.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6201 --device $OBJECT1_DISK1 --weight 100
			echo "swift-ring-builder container.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6201 --device $OBJECT1_DISK2 --weight 100"
			swift-ring-builder container.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6201 --device $OBJECT1_DISK2 --weight 100
			echo "swift-ring-builder container.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6201 --device $OBJECT2_DISK1 --weight 100"
			swift-ring-builder container.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6201 --device $OBJECT2_DISK1 --weight 100
			echo "swift-ring-builder container.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6201 --device $OBJECT2_DISK2 --weight 100"
			swift-ring-builder container.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6201 --device $OBJECT2_DISK2 --weight 100
			
			echo "Verify the Ring Contents"
			swift-ring-builder container.builder
			
			echo "Rebalace The Ring"
			swift-ring-builder container.builder rebalance
			sleep 2
		fi
		
		#Create object ring
        echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m CREATE SWIFT OBJECT RING ON CONTROLLER NODE"
		
		if [ ! -f "/etc/swift/object.ring.gz" ];then
			swift-ring-builder object.builder create 10 3 1
			echo "Create The Rings"
			echo "swift-ring-builder object.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6200 --device $OBJECT1_DISK1 --weight 100"
			swift-ring-builder object.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6200 --device $OBJECT1_DISK1 --weight 100
			echo "swift-ring-builder object.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6200 --device $OBJECT1_DISK2 --weight 100"
			swift-ring-builder object.builder add --region 1 --zone 1 --ip $OBJECT1_MGT_IP --port 6200 --device $OBJECT1_DISK2 --weight 100
			echo "swift-ring-builder object.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6200 --device $OBJECT2_DISK1 --weight 100"
			swift-ring-builder object.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6200 --device $OBJECT2_DISK1 --weight 100
			echo "swift-ring-builder object.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6200 --device $OBJECT2_DISK2 --weight 100"
			swift-ring-builder object.builder add --region 1 --zone 2 --ip $OBJECT2_MGT_IP --port 6200 --device $OBJECT2_DISK2 --weight 100
			
			echo "Verify the Ring Contents"
			swift-ring-builder object.builder
			
			echo "Rebalace The Ring"
			swift-ring-builder object.builder rebalance
			sleep 2
		fi
		
		echo "#####[ CHECK FOR THE RING FILES IN GZIP FORMAT ]######"
		
		ls -l /etc/swift
		### DIstribut The Created Rings on The Object Nodes######
		echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m DISTRIBUTE RING CONFIGURATIONS TO ALL PROXY AND OBJECT NODES"
		
		
		for i in "${object_node[@]}"
		do 
			echo "$i"
			scp *.ring.gz root@$i:/etc/swift
		done
	
	#Finalise configurations

	echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m FINALISING THE SWIFT INSTALLATION"

		if [ ! -f "/etc/swift/swift.conf" ]; then
			echo "curl -o /etc/swift/swift.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/swift.conf-sample"
			 curl -o /etc/swift/swift.conf https://opendev.org/openstack/swift/raw/branch/stable/stein/etc/swift.conf-sample
		fi
		
		
		file=/etc/swift/swift.conf
		##Take A Backup
		cp $file ${file}.bakup
		sed -i 's/swift_hash_path_suffix = changeme/swift_hash_path_suffix = '$HASH_PATH_SUFFIX'/' $file
		sed -i 's/swift_hash_path_prefix = changeme/swift_hash_path_prefix = '$HASH_PATH_PREFIX'/' $file
		
		## Copy /etc/swift/swift.conf file on both the Object Nodes ##
		
		for i in "${object_node[@]}"
		do 
			echo "Object_Node: $i"
			scp -r /etc/swift/swift.conf root@$i:/etc/swift
		done
		
		
		####Ensure Proper OwnerShip Of the Config File All All The Nodes And Restart The Services.
		echo "chown -R root:swift /etc/swift"
		chown -R root:swift /etc/swift
		
		echo "service memcached restart"
		service memcached restart
		sleep 2
		
		echo "service swift-proxy restart"
		service swift-proxy restart
		sleep 2
			
	
	echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m STARTING THE SWIFT-INIT SERVICE ON ALL OBJECT NODES"
		ssh -t root@$OBJECT1_MGT_IP swift-init all start
		sleep 5
		ssh -t root@$OBJECT2_MGT_IP swift-init all start
		sleep 5

	
	
}


swift_prereq_controller	
controller_config
object_config
Create_accnt_ring	

	

