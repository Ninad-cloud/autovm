##############[ DEPLOYING NEUTRON SERVICE ON CONTROLLER AND COMPUTE1 NODE ]#######################
#!/bin/sh
source /root/autovm/globalvar.sh
source /root/autovm/chk_Connectivity.sh
echo "${nodes[@]}"

Neutron_Installation(){

echo -e "\n\n\e[36m#########[ DEPLOYING NEUTRON PART ON CONTROLLER NODE ]######### \e[0m\n"
	
	echo -e "\n\e[36m[CONFIGURATION THE MYSQL DB ] \e[0m\n"
	
mysql << EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$COMMON_PASS';
EOF

	sleep 5
	###Source the admin credentials
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	sleep 2
	
echo "...Create Neutron User...."
echo "openstack user create --domain default --password $COMMON_PASS neutron"
openstack user create --domain default --password $COMMON_PASS neutron

echo "...Adding admin role to the Neutron User...."
echo "openstack role add --project service --user neutron admin"
openstack role add --project service --user neutron admin

########[ Creating the Neutron Services And API Endpoints ]##########
echo "openstack service create --name neutron --description "OpenStack Networking" network"
openstack service create --name neutron --description "OpenStack Networking" network
sleep 2

echo "openstack endpoint create --region RegionOne network public http://controller:9696"
openstack endpoint create --region RegionOne network public http://controller:9696

echo "openstack endpoint create --region RegionOne network internal http://controller:9696"
openstack endpoint create --region RegionOne network internal http://controller:9696

echo "openstack endpoint create --region RegionOne network admin http://controller:9696"
openstack endpoint create --region RegionOne network admin http://controller:9696
sleep 2

}

Neutron_Config_controller(){

###installing Packages on Controller Node####

PKG_FAILED=0
	apt install neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20
	
	filepath1='/etc/neutron/neutron.conf'
	# Backup the original .conf file
	
	cp $filepath1 ${filepath1}.bak
	
	echo "---STARTED CONFIGURATION-----"
	
	sed -i '/^core_plugin = ml2*/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\nservice_plugins = router\nauth_strategy = keystone\nallow_overlapping_ips = true\nnotify_nova_on_port_status_changes = true\nnotify_nova_on_port_data_changes = true' $filepath1
	
	
	sed -i 's/^connection = sqlite/#&/' $filepath1
	grep -q "^connection = mysql+pymysql" $filepath1 || sed -i '/^\[database\]/ a connection = mysql+pymysql://neutron:'$COMMON_PASS'@controller/neutron' $filepath1
	
	
	grep -q "^www_authenticate_uri = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = '$COMMON_PASS'' $filepath1
	
#	grep -q "^auth_url = http://controller:5000" $filepath1 || \
	sed -i '/^\[nova\]/ a auth_url = http://controller:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = '$COMMON_PASS'' $filepath1
	
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/neutron/tmp' $filepath1

	sleep 2

	###########[ CONFIGURE THE MODULE LAYER 2 ]#####################
	echo "---Configure the ML2 Plugin----"
	
	filepath2='/etc/neutron/plugins/ml2/ml2_conf.ini'
	# Backup the original .conf file
	
	cp $filepath2 ${filepath2}.bak
	
	##Directly start with selfservice(network Option-2)##
	
	sed -i '/^\[ml2\]/ a type_drivers = flat,vlan,vxlan\ntenant_network_types = vxlan\nmechanism_drivers = linuxbridge,l2population\nextension_drivers = port_security' $filepath2
	
	sed -i '/^\[ml2_type_flat\]/ a flat_networks = provider' $filepath2
	
	sed -i '/^\[ml2_type_vxlan\]/ a vni_ranges = 1:1000' $filepath2
	sed -i '/^\[securitygroup\]/ a enable_ipset = true' $filepath2
	
	sleep 2

	#########[ CONFIGURE THE LINUX BRIDGE AGENT ]###################
	echo "---Configure the Linux Bridge Agent----"
	
	filepath3='/etc/neutron/plugins/ml2/linuxbridge_agent.ini'
	# Backup the original .conf file
	
	cp $filepath3 ${filepath3}.bak
	
	sed -i '/^\[linux_bridge\]/ a physical_interface_mappings = provider:ens192' $filepath3
	
	sed -i '/^\[vxlan\]/ a enable_vxlan = true\nlocal_ip = '$CONTROLLER_MGT_IP'\nl2_population = true' $filepath3
	
	sed -i '/^\[securitygroup\]/ a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' $filepath3
	
	sleep 2

	########[ CONFIGURE THE LAYER-3 AGENT ]################
	echo "The Layer-3 agent for routing and NAT servies for self-service"
	## BAckUp The Original File
	cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
	
	sed -i '/^\[DEFAULT\]/ a interface_driver = linuxbridge' /etc/neutron/l3_agent.ini
	
	sleep 2
	###########[ CONFIGURE DHCP AGENT ]####################
	echo "-----The DHCP agent provides DHCP services-----"
	##BackUp The original file
	cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
	
	sed -i '/^\[DEFAULT\]/ a interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true' /etc/neutron/dhcp_agent.ini
	
	sleep 2

	############[ CONFIGURE THE METADATA AGENT ]############
	echo "---Configuring metadat agent provides credentials to instances---"
	##BAckUp The Original File####
	cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.bak
	
	sed -i '/^\[DEFAULT\]/ a nova_metadata_host = controller\nmetadata_proxy_shared_secret = '$ADMIN_TOKEN'' /etc/neutron/metadata_agent.ini
	
	sleep 2
	############[ CONFIGURE THE COMPUTE SEVICE TO USE THE NETWORKING ]######
	echo "--Configure the Compute Service to use the Networking---"
	
	sed -i '/^\[neutron\]/ a url = http://controller:9696\nauth_url = http://controller:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = '$COMMON_PASS'\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = '$ADMIN_TOKEN'' /etc/nova/nova.conf


	sleep 2
	###########[ FINALAIZE THE INSTALLATION ]######################
	echo "-----Populate The Database----"
	
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
	
	sleep 2
	
	echo "---Restart Compute API Service"
	echo "service nova-api restart"
	service nova-api restart
	sleep 5
	
	echo "---Restart Networking Services----"
	echo "service neutron-server restart"
	service neutron-server restart
	sleep 5
	
	echo "service neutron-linuxbridge-agent restart"
	service neutron-linuxbridge-agent restart
	sleep 5
	
	echo "service neutron-dhcp-agent restart"
	service neutron-dhcp-agent restart
	sleep 5
	
	echo "service neutron-metadata-agent restart"
	service neutron-metadata-agent restart
	sleep 5
	
	echo "---Restart Layer-3 Service----"
	echo "service neutron-l3-agent restart"
	service neutron-l3-agent restart
	sleep 5
}

Neutron_config_compute(){

echo "---Configuration of Neutron Service on Compute Node Started......."
##### Installing Packages####
	PKG_FAILED=0
	ssh root@$COMPUTE1_MGT_IP apt install neutron-linuxbridge-agent -y || PKG_FAILED=1
	if [ $PKG_FAILED -gt 0 ];then
		echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
		apt update
		exit
	else
		echo -e "\n---PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"
	fi

	sleep 20

  ### Declare And Take a BackUp OF all the File####
  filepath1='/etc/neutron/neutron.conf'
  filepath2='/etc/neutron/plugins/ml2/linuxbridge_agent.ini'
  filepath3='/etc/nova/nova.conf'
  
  ssh root@$COMPUTE1_MGT_IP << COMMANDS
	##Backup###
	cp $filepath1 ${filepath1}.bak
	cp $filepath2 ${filepath2}.bak
  
	sed -i '/^core_plugin = ml2*/ a transport_url = rabbit://openstack:'$COMMON_PASS'@controller\nauth_strategy = keystone' $filepath1
	sed -i 's/^core_plugin = ml2/#&/' $filepath1
  
	grep -q "^www_authenticate_uri = http://controller:5000" $filepath1 || \
	sed -i '/^\[keystone_authtoken\]/ a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = '$COMMON_PASS'' $filepath1
  
	sed -i '/^\[oslo_concurrency\]/ a lock_path = /var/lib/neutron/tmp' $filepath1
	
	sleep 2
	echo "----Configure Linux-Bridge----"
	sed -i '/^\[linux_bridge\]/ a physical_interface_mappings = provider:ens192' $filepath2
	
	sed -i '/^\[vxlan\]/ a enable_vxlan = true\nlocal_ip = '$COMPUTE1_MGT_IP'\nl2_population = true' $filepath2
	
	sed -i '/^\[securitygroup\]/ a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' $filepath2
	
	sleep 2
	echo "------Configure Neutron ON Compute Service----"
	sed -i '/^\[neutron\]/ a url = http://controller:9696\nauth_url = http://controller:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = '$COMMON_PASS'' $filepath3
	sleep 2
	
	echo "--Verify kernal supports Network Bridges---"
	echo "sysctl net.bridge.bridge-nf-call-iptables"
	sysctl net.bridge.bridge-nf-call-iptables
	
	echo "sysctl net.bridge.bridge-nf-call-ip6tables"
	sysctl net.bridge.bridge-nf-call-ip6tables
	
	echo "---Restart All The Essential Services---"
	echo "service nova-compute restart"
	service nova-compute restart
	sleep 2
	
	echo "service neutron-linuxbridge-agent restart"
	service neutron-linuxbridge-agent restart
	sleep 5
COMMANDS


##########[ VERIFY THE SUCCESSFUK LAUNCH OF THE NEUTRON AGENTS ]########

###Source the admin credentials
	source ./admin-openrc
	echo "$OS_PROJECT_DOMAIN_NAME"
	echo "$OS_PROJECT_NAME"
	echo "$OS_USER_DOMAIN_NAME"
	echo "$OS_USERNAME"
	echo "$OS_PASSWORD"
	echo "$OS_AUTH_URL"
	echo "$OS_IDENTITY_API_VERSION"
	echo "$OS_IMAGE_API_VERSION"
	sleep 2

echo "openstack network agent list"
openstack network agent list
sleep 2
}

Neutron_Installation
Neutron_Config_controller
Neutron_config_compute
