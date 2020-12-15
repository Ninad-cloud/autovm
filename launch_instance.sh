#Function To Launch Instances
#Following are the OpenStack Commands allows to Launch Instances
#And provides URL for the "selfservice-instance" 
#!/bin/sh
source /root/autovm/globalvar.sh

launch_instance(){

#source /root/autovm/serv_rest.sh
echo -e "\n\e[36m[ LAUNCH_INSTANCE STARTED ] : \e[0mProvider Network Create"
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
	
	
	####CREATE PROVIDER NETWORK####
	if openstack network list | grep provider;then
		echo "PROVIDER NET ALREADY EXIST, IGNORING..!!"
	else
		echo "openstack network create  --share --external --provider-physical-network provider --provider-network-type flat provider"
		openstack network create --share --external --provider-physical-network provider --provider-network-type flat provider || exit
	fi
	
	

	####CREATE PROVIDER SUBNET#####
	if openstack subnet list | grep provider;then
		echo "PROVIDER SUBNET ALREADY EXIST, IGNORING..!!"
	else
		echo "openstack subnet create --network provider --allocation-pool start=$START_IP,end=$END_IP --dns-nameserver $PROVIDER_DNS_IP --gateway $PROVIDER_GW --subnet-range $PROVIDER_SUBNET provider"
		openstack subnet create --network provider --allocation-pool start=$START_IP,end=$END_IP --dns-nameserver $PROVIDER_DNS_IP --gateway $PROVIDER_GW --subnet-range $PROVIDER_SUBNET provider || exit
	fi
	sleep 2
	
	echo -e "\n\e[36m[ LAUNCH_INSTANCE STARTED ] : \e[0mSelf-service Network creation"
	sleep 2
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
	
	
	if openstack network list | grep selfservice;then
		echo "selfservice network already exist, IGNORING...!!"
	else
		echo "openstack network create selfservice"
		openstack network create selfservice || exit
	fi
	
	####CREATE selfservice SUBNET#####
	if openstack subnet list | grep selfservice;then
		echo "SELFSERVICE SUBNET ALREADY EXIST, IGNORING..!!"
	else
		echo "openstack subnet create --network selfservice --dns-nameserver $PROVIDER_DNS_IP --gateway $SELFSERV_GW --subnet-range $SELFSERV_SUBNET selfservice"
		openstack subnet create --network selfservice --dns-nameserver $PROVIDER_DNS_IP --gateway $SELFSERV_GW --subnet-range $SELFSERV_SUBNET selfservice || exit
	fi
	
	sleep 2
	
	#Create a router to enable selfservice network to connect to provider network, to give the internet access to an Instance.
	
    echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m Create a router...."
	sleep 2
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
	
	
	if openstack router list | grep router;then
		echo "Router Already exist.. IGNORING..!!"
	else
		echo "openstack router create router"
		openstack router create router || exit
		echo "openstack router add subnet router selfservice"
		openstack router add subnet router selfservice || exit
	fi
	
	#####[ OPENSTACK ROUTER SET TO EXTERNAL_GATEWAY Critical ]##################
	echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m SET GATEWAY(EXTERNAL IP) for router"
	echo "openstack router set router --external-gateway provider"
	openstack router set router --external-gateway provider

	#############################################################################
	echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m VERIFY OPERATION...."
	sleep 2
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
	
	
	echo "ip netns"
	ip netns
	
	success=`openstack port list --router router || grep "$END_IP"`
	if [ ! -z "$success" ];then
		echo "NETWORK CREATED SUCCESSFULLY..!!"
	fi
	sleep 2	
	###### OPENSTACK PORT LIST ROUTER #########
	echo "openstack port list --router router"
	openstack port list --router router
	
	sleep 2

	echo "Create "m1.nano" Flavor"
	sleep 2
	
	if openstack flavor list | grep "m1.nano";then
		echo "m1.nano flavour already exist, IGNORING..!!"
	else
		echo "openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano"
		openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano || exit
	fi
	
	echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m Create Kaypair and Security group..."
	sleep 2

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
	sleep 2
	
	if openstack keypair list | grep "mykey";then
		echo "KEYPAIR-ALREADY EXIST..!!"
	else
		echo "openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey"
		openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey || exit
		echo "openstack keypair list"
		openstack keypair list
	fi
	
	echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m CREATE TCP & ICMP SECURITY RULES"
	sleep 2
	#rules_exist=`openstack security group list | grep "default" | wc -l`
	#echo "$rules_exist"
	#if [ "$rules_exist" -gt 0 ];then
	#	echo "TCP & ICMP SECURITY RULES ALREADY EXIST..!!"
	#else
	#	echo "openstack security group rule create --proto icmp default"
	#	openstack security group rule create --proto icmp default
	#	echo "openstack security group rule create --proto tcp --dst-port 22 default"
	#	openstack security group rule create --proto tcp --dst-port 22 default
	#fi
	
	if openstack security group rule list | grep "tcp";then
		echo "TCP & ICMP rule already exist.!!"
	else
		echo "openstack security group rule create --proto icmp default"
		openstack security group rule create --proto icmp default
		echo "openstack security group rule create --proto tcp --dst-port 22 default"
		openstack security group rule create --proto tcp --dst-port 22 default
	fi
	
	sleep 5
	echo -e "\n\e[36m[ LAUNCH_INSTANCE ] : \e[0m DETERMINE INSTANCE OPTIONS"
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
	
	echo "openstack flavor list"
	openstack flavor list
	
	echo "openstack image list"
	openstack image list
	
	echo "openstack network list"
	openstack network list
	
	SELFSERVICE_NET_ID=$(openstack network list | grep selfservice | awk 'NR == 1 {print $2; exit}')
	
	echo "$SELFSERVICE_NET_ID"
	
	echo "openstack security group list"
	openstack security group list

	
	echo "Launch An INSTANCE....."
	echo "openstack server create --flavor m1.nano --image cirros --nic net-id=$SELFSERVICE_NET_ID --security-group default --key-name mykey selfservice-instance"
	
	openstack server create --flavor m1.nano --image cirros --nic net-id=$SELFSERVICE_NET_ID --security-group default --key-name mykey selfservice-instance
	
	sleep 6
	echo "openstack server list"
	openstack server list
	sleep 6

	if openstack server list | grep "ACTIVE";then
		echo "---SELFSERVICE_INSTANCE SUCCESSFULLY LAUNCH---"
#		echo "openstack console url show selfservice-instance"
#		openstack console url show selfservice-instance
#		sleep 10
		#Heat_Instance
	else
		echo "---CHECK FOR CONFIGURATION AGAIN AND RESTART ESSENTIAL SERVICES---"
		exit
		sleep 20
	#	recreate_ins
		
	fi

	
}



launch_instance
#sleep 5
#Heat_Instance

