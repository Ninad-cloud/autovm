###################################################################
##	OPENSTACK STEIN RELEASE AUTOMATION SCRIPT		 ##
##	MASTER'S PROJECT					 ##	 	
##								 ##				
###################################################################

#!bin/sh
source /root/autovm/globalvar.sh
source /root/autovm/chk_Connectivity.sh_b

ssh-keygen_gen(){
		
	echo -e "\nTO GENERATE THE SSH-KEYGEN FIRST REMOVE EXISTING KEY \e[36m[ PROGRESS FOR ALL NODES] \e[0m \n"
	[ -f /root/.ssh/id_rsa ] && rm -rf /root/.ssh/id_rsa
	expect -c '
	spawn ssh-keygen -q -N ""
	expect "Enter file in which to save the key (/root/.ssh/id_rsa):"
	send "\r"
	interact'
	sleep 2
	echo -e "\nGENERATE THE SSH-KEYGEN IS \e[36m[ DONE ] \e[0m"
}


add_ssh-keygen(){

	AUTO_LOGIN_FAILED=0
 	echo -e "\nADDING THE SSH-KEYGEN TO ALL THE OPENSTACK NODES IN PROCESS \n"
	
        for i in "${nodes[@]}"
        do
		echo "ADDING KEY OF CONTROLLER NODE IN ALL THE NODES"
		expect -c "
		spawn ssh-copy-id $i
		expect "*password:"
		send \"$COMMON_PASS\r\"
		interact "

	done 
sleep 5	
		
}

config_Hostnames(){

	echo -e "\nADDING THE HOSTNAME TO ALL NODES IS IN \e[36m[ PROGRESS ] \e[0m \n"
	##BackUp The original file
	cp /etc/hosts /etc/hosts.bak
	
	#hostname configuration on controller node
	sed -i 's/^127.0.1.1/#&/' /etc/hosts
		grep -q "^#controller" /etc/hosts || sed -i '$ a  #gateway\n'$GATEWAY_MGT_IP'\t'$GATEWAY_HOSTNAME'\n#controller\n'$CONTROLLER_MGT_IP'\t'$CONTROLLER_HOSTNAME'\n#compute1\n'$COMPUTE1_MGT_IP'\t'$COMPUTE1_HOSTNAME'\n#block1\n'$BLOCK1_MGT_IP'\t'$BLOCK1_HOSTNAME'\n#object1\n'$OBJECT1_MGT_IP'\t'$OBJECT1_HOSTNAME'\n#object2\n'$OBJECT2_MGT_IP'\t'$OBJECT2_HOSTNAME'\n#end' /etc/hosts  	

		sleep 10
	#hostname configuration on other nodes.
	echo "${nodes}"
	echo "Start with Other Nodes!!!!!!!"
	for i in "${nodes[@]}"
	do
		echo "/etc/hosts configuration on other nodes"
		echo "[ Node $i ]"
		ssh -t -T root@$i << EOF
		cp /etc/hosts /etc/hosts.bak
		sed -i 's/^127.0.1.1/#&/' /etc/hosts
		grep -q "^#controller" /etc/hosts || sed -i '$ a  #gateway\n'$GATEWAY_MGT_IP'\t'$GATEWAY_HOSTNAME'\n#controller\n'$CONTROLLER_MGT_IP'\t'$CONTROLLER_HOSTNAME'\n#compute1\n'$COMPUTE1_MGT_IP'\t'$COMPUTE1_HOSTNAME'\n#block1\n'$BLOCK1_MGT_IP'\t'$BLOCK1_HOSTNAME'\n#object1\n'$OBJECT1_MGT_IP'\t'$OBJECT1_HOSTNAME'\n#object2\n'$OBJECT2_MGT_IP'\t'$OBJECT2_HOSTNAME'\n#end' /etc/hosts
EOF
	done
	echo -e "\nADDING HOSTNAME TO $i IS \e[36m[ DONE ] \e[0m \n"

}

Install_pkg(){
#Install expect and paramiko on Controller Node
echo "Installa expect and paramiko on controller node....."
apt install python3-pip -y
sleep 5
pip3 install paramiko

##Install expect and python3-pip on other nodes
    echo "Start installing expect and pip3..."
	for i in "${nodes[@]}"
	do
		echo "Start package on other nodes"
		echo "[ Node $i ]"
		ssh root@$i apt install python3-pip -y
	done
	sleep 5
	
##Install paramiko on all the other nodes
	echo "Start installing paramiko.."
	for i in "${nodes[@]}"
	do
		echo "Start package on other nodes"
		echo "[ Node $i ]"
		ssh root@$i pip3 install paramiko 
	done	
 
}

verify_pkg(){
#Verify on controller Node
pip3 show paramiko

# Verify on Other nodes
for i in "${nodes[@]}"
	do
		echo "package on other nodes"
		echo "[ Node $i ]"
		ssh root@$i pip3 show paramiko
	done
	sleep 5



}

Prompt(){
while true; do
    read -p "$1" yn
    case $yn in
        [Yy]* ) echo 1;break;;
        [Nn]* ) echo 0;break;;
        * ) echo "Please answer yes or no.";;
    esac
done
#echo $yn
return 
}

deploy(){
echo "Press Y/y to start deployment and N/n to start Instance...."

local di=$(Prompt "Do you want to Jump to Deployment/Undeployment or Jump to Instance Operations if deployment present? ")
echo "$di"
if [ "$di" == "1" ];
then
	Start
else
	Instance
fi


}


Start(){
echo "Press Y to start Installation and n to start Uninstallation...."

local IU=$(Prompt "Do you want to start Installation or Uninstallation? ")
echo "$IU"
if [ "$IU" == "1" ];
then
	Installation
else
	Uninstallation
fi

}

Instance(){
echo "Press y/Y to launch instance and n/N to delete Instance...."

local Ins=$(Prompt "Do you want to Launch Instances or Delete Instances? ")
echo "$Ins"
if [ "$Ins" == "1" ];
then
	launch
else
	delete_ins
fi

}

minimal_deploy(){
echo "Minimal Deployment Starts here...!"
ssh-keygen_gen
add_ssh-keygen
config_Hostnames
source /root/autovm/ntp_install.sh
verify_pkg
source /root/autovm/generic_pkg.sh
source /root/autovm/mysql_config.sh
source /root/autovm/rabbitmq.sh
source /root/autovm/memcached.sh
source /root/autovm/etcd.sh
source /root/autovm/keystone.sh
source /root/autovm/glance.sh
source /root/autovm/placement.sh
source /root/autovm/dashboard.sh
source /root/autovm/compute.sh
source /root/autovm/neutron.sh
source /root/autovm/cinder.sh

}


Installation(){
echo "[START]___MINIMAL DEPLOYMENT ALONG WITH DASHBOARD AND CINDER IS STARTED____"
local min_dep=$(Prompt "Do you want to start with only minimal deployment? ")
echo "$min_dep"
local heatservice=$(Prompt "Do you want to add heatservice? ")
echo "$heatservice"
local swift=$(Prompt "Do you want to add swift? ")
echo "$swift"
local manila=$(Prompt "Do you want to add manila? ")
echo "$manila"


if [ "$min_dep" == "1" ]; then
	minimal_deploy
fi

#########[ ADD MORE  PACKAGES ]#############

if [ "$heatservice" == "1" ]; then
	source /root/autovm/heatservice.sh
fi

if [ "$manila" == "1" ]; then
	source /root/autovm/manila.sh
fi

if [ "$swift" == "1" ]; then
	source /root/autovm/swift1.sh
fi

sleep 10

}

launch(){
local launch=$(Prompt "Do you want to launch instance? ")
echo "$launch"
local launch_heat=$(Prompt "Do you want to launch heat instance? ")
echo "$launch_heat"
local verify_swift=$(Prompt "Do you want to verify swift operations? ")
echo "$verify_swift"
local launch_manila=$(Prompt "Do you want to launch manila instance? ")
echo "$launch_manila"

if [ "$launch" == "1" ]; then
	source /root/autovm/launch_instance.sh
	sleep 5
fi

if [ "$launch_heat" == "1" ]; then
	source /root/autovm/launch_heat_instance.sh
	sleep 5
fi

if [ "$verify_swift" == "1" ]; then
	source /root/autovm/swift_verify.sh
	sleep 5
fi

if [ "$launch_manila" == "1" ]; then
	source /root/autovm/manila_instance_launch.sh
fi


}

delete_ins(){
sleep 10
echo "..[Delete Lunched instances] First Instances..."

local delete_manila=$(Prompt "Do you want to delete manila instances? ")
echo "$delete_manila" 

local delete_heat=$(Prompt "Do you want to remove heat stack? ")
echo "$delete_heat"

local delete_in=$(Prompt "Do you want to delete instances? ")
echo "$delete_in"

if [ "$delete_manila" == "1" ]; then
	sleep 5
	source /root/autovm/delete_manila_instance.sh
fi

if [ "$delete_heat" == "1" ]; then
	sleep 5
	source ./demo-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	
	echo "openstack stack delete --yes stack"
	openstack stack delete --yes stack
	
fi

if [ "$delete_in" == "1" ]; then
	sleep 5
	source /root/autovm/delete_instance.sh
fi

}

Uninstallation(){
echo "___[START] Undeploying CLOUD_____"

local unconfig_heatservice=$(Prompt "Do you want to Uninstall heatservice? ")
echo "$unconfig_heatservice"
local unconfig_swift=$(Prompt "Do you want to Uninstall swift? ")
echo "$unconfig_swift"
local unconfig_manila=$(Prompt "Do you want to Uninstall manila? ")
echo "$unconfig_manila"
local unconfig_horizon=$(Prompt "Do you want to Uninstall Horizon? ")
echo "$unconfig_horizon"
local unconfig_cinder=$(Prompt "Do you want to Uninstall cinder? ")
echo "$unconfig_cinder"
local unconfig_minimalDepl=$(Prompt "Do you want to Uninstall Minimal Deployment? ")
echo "$unconfig_minimalDepl"


if [ "$unconfig_heatservice" == "1" ]; then
	source /root/autovm/unconfig_heat.sh
fi

if [ "$unconfig_swift" == "1" ]; then
	source /root/autovm/unconfig_swift.sh
fi

if [ "$unconfig_manila" == "1" ]; then
	source /root/autovm/unconfig_manila.sh
fi

if [ "$unconfig_horizon" == "1" ]; then
	source /root/autovm/unconfig_dashboard.sh
fi

if [ "$unconfig_cinder" == "1" ]; then
	source /root/autovm/unconfig_cinder.sh
fi

echo "..Before Starting unistall for Minimal Deployment make sure to remove all extra services....."
if [ "$unconfig_minimalDepl" == "1" ]; then
	source /root/autovm/unconfig_minimalDeploy.sh
fi

}
deploy
