#!/bin/sh
source /root/autovm/globalvar.sh
source	/root/autovm/chk_Connectivity.sh_b

chrony_install(){
	PKG_FAILED=0
	echo "INSTALL "chrony" PACKAGE IN ALL NODES TO COFIGURE NTP"
	apt install chrony -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ]
	then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ON CONTROLLER NODE] \e[0m ----\n"		
	fi
	sleep 10
	
	echo "INSTALLING CHRONY ON THE OTHER NODES"
	echo "${nodes[@]}"
	for i in "${nodes[@]}"
	do
		PKG_FAILED=0
	     #source  /root/autovm/chk_Connectivity.sh_b $i
	     	sleep 5
		echo "Node $i"
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
		
		##BackUp Of the Original File
		cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
		
####################[ NTP ON CONTROLLER NODE ]############################################
	    sed -i 's/^\<pool.*\>/#&/' /etc/chrony/chrony.conf 
		sed -i '/#pool 2.*/a server gaia.ecs.csus.edu iburst\nallow 10.0.0.0/24' /etc/chrony/chrony.conf
		service chrony restart
		sleep 10
		chronyc sources
		sleep 5
		echo "NTP CONFIG ON CONTROLLER DONE"

	for i in "${nodes[@]}"
	do
		#chk_Connectivity $i
		echo "Node $i"
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
chrony_install
ntp_config
