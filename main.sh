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

Installation(){
echo "[START]___MINIMAL DEPLOYMENT ALONG WITH DASHBOARD AND CINDER IS STARTED____"
local heatservice=$(Prompt "Do you want to add heatservice? ")
echo "$heatservice"
local swift=$(Prompt "Do you want to add swift? ")
echo "$swift"
local manila=$(Prompt "Do you want to add manila? ")
echo "$manila"


ssh-keygen_gen
add_ssh-keygen
config_Hostnames
source /root/autovm/ntp_install.sh
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

#########[ ADD MORE  PACKAGES ]#############

if [ "$heatservice" == "1" ]; then
	source /root/autovm/heatservice.sh
fi

if [ "$swift" == "1" ]; then
	source /root/autovm/swift1.sh
fi

if [ "$manila" == "1" ]; then
	source /root/autovm/manila.sh
fi

}

##########[ LAUNCH AN INSTANCE]#############
echo "..LANUCH A VIRTUAL MACHINE..."
source /root/autovm/launch_instance.sh

echo "LAUNCH ORCHESTRATION INSTANCES....."
source /root/autovm/launch_heat_instance.sh

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

