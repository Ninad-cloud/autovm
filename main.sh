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
#source /root/autovm/heatservice.sh
#source /root/autovm/launch_instance.sh
