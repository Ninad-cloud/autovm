#!/bin/bash
source /root/autovm/globalvar.sh

rabbit_install(){
	
	PKG_FAILED=0
	echo "INSTALLING RABBITMQ ON CONTROLLER"
	
	apt install rabbitmq-server -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi
	sleep 3
	rabbitmqctl add_user openstack $COMMON_PASS
	sleep 3
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"
	sleep 3
	echo "INSTALING RABBITMQ DONE!!!!"

}

Rabbitmq_stop(){

	rabbitmqctl stop_app
	rabbitmqctl reset
	rabbitmqctl start_app
	
echo -e "\n\n\e[36m###################### MESSAGE QUEUE (RABBITMQ) UNINSTALL ON CONTROLLER NODE IN DONE ###################### \e[0m\n"

}

rabbit_install
