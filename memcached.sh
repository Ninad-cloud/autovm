#!/bin/bash
source /root/autovm/globalvar.sh

#########################[ INSTALLING MEMCACHED ]##################################################
echo "INSTALLING MEMCACHED"

Memcached_config(){
	PKG_FAILED=0
    apt install memcached python-memcache -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi
    sleep 2
    sed -i 's/^-l 127.0.0.1/-l '$CONTROLLER_MGT_IP'/' /etc/memcached.conf
	sleep 2
	echo "service memcached restart"	
    service memcached restart
	sleep 5
    echo -e "\n\n\e[36m###################### MEMCACHED INSTALL AND CONFIGURE ON CONTROLLER NODE IS DONE ###################### \e[0m\n"

}


Memcached_config
