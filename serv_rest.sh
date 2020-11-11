#!/bin/sh
source /root/autovm/globalvar.sh

restart_ser(){
	### NOVA Service
	##Populate The database
	su -s /bin/sh -c "nova-manage api_db sync" nova
	su -s /bin/sh -c "nova-manage db sync" nova
	########
	
	##restart The nova services
	echo "service nova-api restart"
	service nova-api restart
	
	echo "service nova-scheduler restart"
	service nova-scheduler restart
	
	echo "service nova-conductor restart"
	service nova-conductor restart
	
	echo "service nova-novncproxy restart"
	service nova-novncproxy restar
	
	ssh root@$COMPUTE1_MGT_IP service nova-compute restart	

	#####Neutron Service
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
	
	sleep 2
	
	echo "service nova-api restart"
	service nova-api restart
	sleep 5
	
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
	
	echo "service neutron-l3-agent restart"
	service neutron-l3-agent restart

  ssh root@$COMPUTE1_MGT_IP << COMMANDS

	echo "service nova-compute restart"
	sleep 2
	
	echo "service neutron-linuxbridge-agent restart"
	service neutron-linuxbridge-agent restart
	sleep 5
COMMANDS
}
restart_ser
