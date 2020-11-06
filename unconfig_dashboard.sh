##############[ UNDEPLOYING DASHBOARD SERVICE ON CONTROLLER ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh

unconfig_Horizon(){

	echo -e "\n\e[36m######### [ HORIZON ] : UNDEPLOY ON CONTROLLER NODE ########### \e[0m\n"
	
	cp /etc/openstack-dashboard/local_settings.py.bakup /etc/openstack-dashboard/local_settings.py
	
	echo "restart apache2"
	echo "service apache2 restart"
	service apache2 restart
	
	echo -e "\n\e[36m##### [ HORIZON ] : SUCCESSFULLY UNDEPLOYED HORIOZON ###### \e[0m\n"

}

unconfig_Horizon