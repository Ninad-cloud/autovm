#!/bin/sh
source /root/autovm/globalvar.sh
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
chk_Connectivity $1
