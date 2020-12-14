#Function to delete instance and both the provider as well as selfservice network
#!/bin/sh
source /root/autovm/globalvar.sh

delete_ins(){
###Source the demo credentials
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
	openstack server delete selfservice-instance
	sleep 10
	
	echo "Remove Subnet from the Router"
	openstack router remove subnet router selfservice
	sleep 10
	
	echo "Remove router"
	openstack router delete router
	sleep 10
	
	echo "Remove subnet Selfservice"
	openstack subnet delete selfservice
	sleep 10
	
	echo "Remove network selfservice"
	openstack network delete selfservice
	
	sleep 10
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
	
	echo "Remove Provider Subnet"
	openstack subnet delete provider
	sleep 10
	echo "Remove Provider network"
	openstack network delete provider
	openstack network list
	
	sleep 5
	
}

delete_ins