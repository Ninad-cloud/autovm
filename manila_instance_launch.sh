#Function To Launch Manila Instances
#Following are the OpenStack Commands allows to Launch Instances
 
#!/bin/sh
source /root/autovm/globalvar.sh

launch_manila_instance(){

echo -e "\n\e[36m[ LAUNCH_INSTANCE STARTED ] : \e[0mFOR DHSS OPTION - 2"

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
	
	#Create manila-flavor with id 100
	if openstack flavor list | grep manila-service-flavor;then
		echo "Manila-Service-Flavour already exist"
	else
		openstack flavor create manila-service-flavor --id 100 --ram 512 --disk 0 --vcpus 1
	fi

	#manila-service-image
	echo "openstack image list"
	openstack image list
	
	#Create a default share type with DHSS enabled. 
	echo "manila type-create default_share_type True"
	manila type-create default_share_type True
	
	#Restart manila-api
	service manila-api restart
	
	#Create Share-network using selfservice network ID and Subnet-ID
	###Source the demo credentials
	source ./demo-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "openstack network list"
	openstack network list
	
	SELFSERVICE_NET_ID=$(openstack network list | grep selfservice | awk 'NR == 1 {print $2; exit}')
	SELFSERVICE_SUBNET_ID=$(openstack network list | grep selfservice | awk 'NR == 1 {print $6; exit}')
	echo "$SELFSERVICE_NET_ID"
	echo "$SELFSERVICE_SUBNET_ID"
	
	###Source the demo credentials
	source ./demo-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	if manila share-network-list | grep demo-share-network1; then
		echo "Manila share network Already exist..."
	else	
		echo "manila share-network-create --name demo-share-network1 --neutron-net-id $SELFSERVICE_NET_ID --neutron-subnet-id $SELFSERVICE_SUBNET_ID"
		manila share-network-create --name demo-share-network1 --neutron-net-id $SELFSERVICE_NET_ID --neutron-subnet-id $SELFSERVICE_SUBNET_ID
	fi
	
	###Source the demo credentials
	source ./demo-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	if manila list | grep demo-share1;then
		echo "Manila share Already exist..."
	else
		echo "manila create NFS 1 --name demo-share1 --share-network demo-share-network1"
		manila create NFS 1 --name demo-share1 --share-network demo-share-network1
	fi
	
	sleep 250
	
	##Check for creation of manila-share-instance
	echo "manila list"
	manila list
	
	if manila list | grep "available";then
		echo "---SELFSERVICE_INSTANCE SUCCESSFULLY LAUNCH---"
	else
		echo "---CHECK FOR CONFIGURATION AGAIN AND RESTART ESSENTIAL SERVICES---"
		exit
	fi

	
	#Determine export IP address of the share
	echo "manila show demo-share1"
	manila show demo-share1 | grep path
	

}