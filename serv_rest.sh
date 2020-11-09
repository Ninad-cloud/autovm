#!/bin/sh
source /root/autovm/globalvar.sh

restart_ser(){
	
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
