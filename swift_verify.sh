#######[ DEPLYOMENT OF SWIFT-OBJECT STORAG ESERVICE ]########################
#Verification for SWIFT-OBJECT
# Swift Service uses Distributed SQlite Databases
#!/bin/sh
source /root/autovm/globalvar.sh

verfiy_operation(){

# Verify the operation

echo -e "\n\e[36m[ SWIFT_ON_CONTROLLER ] :\e[0m VERIFYING THE SWIFT SERVICE DEPLOYMENT"
	service swift-proxy restart
	
	
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
	
	echo "---swift stat"
	swift stat
	
	sleep 2
	if openstack container list | grep container1;then
		echo "Container Already Created...!!!"
	else
		echo "openstack container create container1"
		openstack container create container1
	fi
	
	#openstack container create container1
	echo "This is for Demo Purpose..." > test_file.txt
	
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
	
	echo "openstack object create container1"
	openstack object create container1 test_file.txt
	
	sleep 5

	for i in 1 2 3;
	do
		if openstack object list container1 | grep test_file.txt;then
		break
		else
			echo -e "\nRound $i of list container"
			sleep 5
		fi
	done
	
	echo "create test directory"
	mkdir test
	cd test
	openstack object save container1 test_file.txt
	echo "..See The Result..."
	cat test_file.txt
	
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
	
	echo "Verify The Operation....."
	if openstack object list container1 | grep test_file.txt;then
		echo -e "\n\e[36m#####[ SUCCESSFULLY DEPLOYED SWIFT SERVICE ]######## \e[0m\n"
	else
		echo -e "\n\e[31m##### SWIFT SERVICE FAILED, EXITING..!! ########### \e[0m\n"
		exit
	fi


}

verfiy_operation