#!/bin/sh
source /root/autovm/globalvar.sh


Horizon_config(){


	echo -e "\n\e[36m######### [ HORIZON ] : DEPLOY HORIOZON ON CONTROLLER NODE ########### \e[0m\n"

	echo "INSTALLATION AND CONFIGURATION OF HORIZON STARTED!!!!"
	PKG_FAILED=0
	apt install openstack-dashboard -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20
	
	filepath1='/etc/openstack-dashboard/local_settings.py'
# Backup the original .conf file
	cp $filepath1 ${filepath1}.bakup
	echo "......Configuration on $filepath1........"
	
#	sed -i 's/^OPENSTACK_HOST = "127.0.0.1"/OPENSTACK_HOST = "controller"/' $filepath1 
	sed -i 's/^ALLOWED_HOSTS = '\''\*'\''/ ALLOWED_HOSTS = ['\''*'\'', ]/' $filepath1 
	
<<'COMMENTS'
	grep -q "^SESSION_ENGINE =" $filepath1 || sed -i '/^CACHES =/ i SESSION_ENGINE = '\''django.contrib.sessions.backends.cache'\''' $filepath1
	sed -i 's/'\''LOCATION'\'': '\''127.0.0.1/'\''LOCATION'\'': '\''controller/' $file

	sed -i 's|^OPENSTACK_KEYSTONE_URL = "http:\/\/%s:5000\/v2.0"|OPENSTACK_KEYSTONE_URL = "http:\/\/%s:5000\/v3"|' $filepath1

	grep -q "^OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" $filepath1 || \
	sed -i '/^#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT/ a OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True' $filepath1

	grep -q "^OPENSTACK_API_VERSIONS" $filepath1 || \
	sed -i '/^#OPENSTACK_API_VERSIONS/ i OPENSTACK_API_VERSIONS = {\n"identity": 3,\n"image": 2,\n"volume": 3,\n}\n' $filepath1

    sed -i '/^#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN/ s/#//' $filepath1

	sed -i 's/^OPENSTACK_KEYSTONE_DEFAULT_ROLE = "_member_"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"/' $filepath1
	
	timezone=`cat /etc/timezone`
	echo "Timezone is $timezone"
	
	sed -i 's|^TIME_ZONE = "UTC"|TIME_ZONE = "'$timezone'"|' $file

	sleep 2
	#Handle the bug, or else dashboard doesn't load
	grep -q "^WSGIApplicationGroup %{GLOBAL}" /etc/apache2/conf-enabled/openstack-dashboard.conf || \
	sed -i '/^WSGIProcessGroup horizon/ a WSGIApplicationGroup %{GLOBAL}' /etc/apache2/conf-enabled/openstack-dashboard.conf

	sleep 2
	
	echo "restart apache2"
	echo "service apache2 restart"
	service apache2 restart
	sleep 5
	
	echo -e "\n\e[36mAccess the dashboard using a web browser at http://controller/horizon\e[0m\n"

	echo -e "\n\e[36m######### [ HORIZON ] : SUCCESSFULLY DEPLOYED ########### \e[0m\n"
COMMENTS

}
Horizon_config
