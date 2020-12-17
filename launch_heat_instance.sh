#Function To Launch HEAT Instances
#Following are the OpenStack Commands allows to Launch ORCHESTRATION Instances 
#!/bin/sh
source /root/autovm/globalvar.sh
Heat_Instance(){

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
	
	
	echo "Determine Available Network--"
	echo "openstack network list"
	openstack network list
	
	echo "---Set the NET_ID environment variable to reflect the ID of a network----"
	echo "export NET_ID=$(openstack network list | awk '/ provider / { print $2 }')"
	export NET_ID=$(openstack network list | awk '/ provider / { print $2 }')
	
	echo "--Create Stack On The Provider Network----"
	echo "openstack stack create -t demo-template.yml --parameter "NetID=$NET_ID" stack"
	openstack stack create -t demo-template.yml --parameter "NetID=$NET_ID" stack
	
	echo "---Successful Stack List---"
	echo "openstack stack list"
	openstack stack list
	
	echo "--Compare the Instance with The Stack info---"
	echo "openstack stack output show --all stack"
	openstack stack output show --all stack
	
	sleep 20
	echo "openstack server list"
	openstack server list
	
	

	
}
Heat_Instance
