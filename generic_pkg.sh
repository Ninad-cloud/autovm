#!/bin/sh
source /root/autovm/globalvar.sh
echo "${nodes[@]}"
generic_pkg(){

	FAILED=""
	echo -e "\nGENERIC PACKAGE INSTALLATION TO ALL NODES IS \e[36m[ STARTED ] \e[0m \n"
	##Installing packages on Cotroller node.
	
	expect -c '
	spawn add-apt-repository cloud-archive:stein
	expect "Press * to continue*"
	send "\r"
	interact'
	
	apt update && apt dist-upgrade -y || FAILED="yes"

		if [ ! -z $FAILED ];then
			echo "\e[36mUPDATE ON CONTROLLER FAILED, EXITING\e"
			exit
		fi
	
	echo "INSTALLING OPENSTACK CLIENT ON CONTROLLER"

	apt install python3-openstackclient -y

	echo -e "\n\e[36m PACKAGE INSTALLATION ON CONTROLLER NODE IS DONE \e \n\n\n"	
	##Installation on other Nodes -Compute
		echo "$nodes"
        for i in "${nodes[@]}"
        do
		echo "first node $i "
		echo -e "\n\e[36m GENERIC PACKAGE INSTALLATION AND UPDATE ON $i NODE IN PROCESS \e \n\n\n"
		
		echo "ssh to $i"
		ssh root@$i << EOF
	expect -c '
	spawn add-apt-repository cloud-archive:stein
	expect "*to continue*"
	send "\r"
	sleep 5
	expect EOF'
	exit
EOF
		echo "ssh to $i complete" 
		
		echo -e "\n\e[36m[ STARTED ] APT_GET UPDATE AND UPGRADE ON $i NODE...\e\n\n"
		
		#source /root/autovm/chk_Connectivity.sh_b $i	
		ssh root@$i apt update && apt dist-upgrade -y || FAILED="yes"
		
		if [ ! -z $FAILED ];then
			echo "\e[36mUPDATE ON $i FAILED, EXITING\e"
			exit
		fi
		PKG_FAILED=0
		#source /root/autovm/chk_Connectivity.sh_b $i	
		#echo "Node $i"
		ssh root@$i apt install python3-openstackclient -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi

		sleep 30
		echo -e "\n\e[36m GENERIC PACKAGE INSTALLATION AND UPDATE ON $i NODE IS DONE \e \n"
	
	done
	
	echo -e "\n\e[36m GENERIC PACKAGE INSTALLATION AND UPDATE ON ALL NODE IS [ DONE ]\e[0m \n"

}
generic_pkg
