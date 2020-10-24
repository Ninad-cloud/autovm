#!/bin/sh
#CONTROLLER VARiABLES
#echo "reached 3" > /root/out3.txt
CONTROLLER_MGT_IP="10.0.0.11"
CONTROLLER_PUB_IP="10.116.32.11"
CONTROLLER_HOSTNAME="controller"

#COMPUTE VARIABLES

COMPUTE1_MGT_IP="10.0.0.31"
COMPUTE1_PUB_IP="10.116.32.12"
COMPUTE1_HOSTNAME="compute1"

#BLOCK1 STORAGE SERVICE
BLOCK1_MGT_IP="10.0.0.41"
BLOCK1_HOSTNAME="block1"
#IF NO PUBLIC IP GIVEN, THEN PROVIDE MAC ID OF UNUSED INETRFACE (dont give mac of mgt_ip interface)
#BLOCK1_PUB_IP="00:26:55:ea:b2:7c"
#BLOCK1_LVM_DISKNAME="sdb"

#GATEWAY NODE
GATEWAY_MGT_IP="10.0.0.1"
GATEWAY_HOSTNAME="gateway"

COMMON_PASS="redhat"
#DB_PASS="redhat"

ADMIN_TOKEN="$(openssl rand -hex 10)"

#ARRAY OF ALL THE AVILABLE NODES, MAKE SURE YOU HAVE ALL HOSTS IN THIS ARRAY, NEW ADDED NODE ENTRY SHOULD EXIST HERE.

declare -a nodes=("$COMPUTE1_MGT_IP" "$BLOCK1_MGT_IP")



chk_Connectivity(){

        echo -e "\nCHECKING THE CONNECTIVITY TO ALL NODE $1 \e[36m[ IN PROCESS ] \e[0m \n"
        PING_FAILED=0
        #Check first if all servers are pinging or not
        for i in "${nodes[@]}"
        do
		echo "$i"
		echo "connectivity"
		ping -c2 $i || PING_FAILED=1
        
		if [ $PING_FAILED -gt 0 ]
        	then
                	echo -e "\e[31m\nPING TO $i FAILED, PLEASE VERIFY CONNECTIVITY and RESUME SCRIPT AFTER CONNECTIVITY \e[0m\n"
                	exit
        	fi
        
	done 
        
	echo -e "\nALL NODES ARE \e[36m[ UP & RUNNING...!! ] \e[0m \n"
         

}


######################################################################################################################
#generate a key-gen at controller

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
	
		
}

config_Hostnames(){

	echo -e "\nADDING THE HOSTNAME TO ALL NODES IS IN \e[36m[ PROGRESS ] \e[0m \n"

	#hostname configuration on controller node
	sed -i 's/^127.0.1.1/#&/' /etc/hosts
        grep -q "^#controller" /etc/hosts || sed -i "$ a \\\n#controller\n$CONTROLLER_MGT_IP\t$CONTROLLER_HOSTNAME" /etc/hosts && sed -i "$ a \\\n#compute1\n$COMPUTE1_MGT_IP\t$COMPUTE1_HOSTNAME" /etc/hosts && sed -i "$ a \\\n#gateway\n$GATEWAY_MGT_IP\t$GATEWAY_HOSTNAME" /etc/hosts && sed -i "$ a \\\n#block1\n$BLOCK1_MGT_IP\t$BLOCK1_HOSTNAME" /etc/hosts && sed -i "$ a \\\n#object1\n$OBJECT1_MGT_IP\t$OBJECT1_HOSTNAME" /etc/hosts && sed -i "$ a \\\n#object2\n$OBJECT2_MGT_IP\t$OBJECT2_HOSTNAME" /etc/hosts  	

	#hostname configuration on other nodes.
	for i in "${nodes[@]}"
	do
		echo "/etc/hosts configuration on other nodes"
		chk_Connectivity $i
		ssh -t -T root@$i << EOF
		sed -i 's/^127.0.1.1/#&/' /etc/hosts
		grep -q "^#controller" /etc/hosts || sed -i '$ a  #gateway\n'$GATEWAY_MGT_IP'\t'$GATEWAY_HOSTNAME'\n#controller\n'$CONTROLLER_MGT_IP'\t'$CONTROLLER_HOSTNAME'\n#compute1\n'$COMPUTE1_MGT_IP'\t'$COMPUTE1_HOSTNAME'\n#block1\n'$BLOCK1_MGT_IP'\t'$BLOCK1_HOSTNAME'\n#object1\n'$OBJECT1_MGT_IP'\t'$OBJECT1_HOSTNAME'\n#object2\n'$OBJECT2_MGT_IP'\t'$OBJECT2_HOSTNAME'\n#end' /etc/hosts
EOF
	done
	echo -e "\nADDING HOSTNAME TO $i IS \e[36m[ DONE ] \e[0m \n"
}

chrony_install(){
	PKG_FAILED=0
	echo "INSTALL "chrony" PACKAGE IN ALL NODES TO COFIGURE NTP"
	apt install chrony -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ]
	then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
	fi
	#sleep 20
	
	echo "INSTALLING CHRONY ON THE OTHER NODES"
	for i in "${nodes[@]}"
	do
		PKG_FAILED=0
		chk_Connectivity $i
		ssh root@$i apt install chrony -y || PKG_FAILED=1

        if [ $PKG_FAILED -gt 0 ]
        then
                echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
                exit
        else
                echo -e "\n######## $1 PACKAGE INSTALLATION on $2 IS \e[36m[ DONE ] \e[0m##########\n"         
        fi
	done
	
}	
ntp_config(){

	echo -e "\n\e[36m######## NTP CONFIGURATION IS IN PROCESS ########### \e[0m\n"

####################[ NTP ON CONTROLLER NODE ]############################################
	    sed -i 's/^\<pool.*\>/#&/' /etc/chrony/chrony.conf 
		sed -i '/#pool 2.*/a server gaia.ecs.csus.edu iburst\nallow 10.0.0.0/24' /etc/chrony/chrony.conf
		service chrony restart
		sleep 10
		chronyc sources

	for i in "${nodes[@]}"
	do
		chk_Connectivity $i
		ssh root@$i << EOF
		grep -q "^server controller" /etc/chrony/chrony.conf || \
		sed -i 's/^\<pool.*\>/#&/' /etc/chrony/chrony.conf 
		sed -i '/#pool 2.*/a server controller iburst' /etc/chrony/chrony.conf
		service chrony restart
		sleep 10
		chronyc sources
EOF
		
	done

	 echo -e "\n\e[36m######### NTP CONFIGURATION ON ALL NODES IN DONE ########### \e[0m\n\n"
}