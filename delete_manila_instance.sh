#Function To delete Share Instances

#!/bin/sh
source /root/autovm/globalvar.sh

delete_share_instance(){
echo "Before deleting Share-instances make sure to UMOUNT share from Compute Instances"
sleep 5
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
	
	IP1=$(manila access-list demo-share1 | grep active | awk 'NR == 1 {print $2; exit}')
	
	echo "manila access-deny demo-share1 $IP1"
	manila access-deny demo-share1 $IP1
	
	IP2=$(manila access-list demo-share1 | grep active | awk 'NR == 1 {print $2; exit}')
	
	echo "manila access-deny demo-share1 $IP2"
	manila access-deny demo-share1 $IP2

	sleep 30
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
	
	echo "manila force-delete demo-share1"
	manila force-delete demo-share1
	
	sleep 30
	source ./demo-openrc
	echo "manila list"
	manila list

	echo "manila share-network-delete demo-share-network1"
	manila share-network-delete demo-share-network1
	
	manila share-network-list
	sleep 5
	echo "---DELETEING INSTANCES.........."
	source ./demo-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	sleep 2

	echo "Delete The Instance"
	openstack server delete share-instance1
	sleep 5
	openstack server delete share-instance2
	sleep 10
	openstack server list

}

delete_share_instance