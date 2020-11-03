#!/bin/bash
source /root/autovm/globalvar.sh

##################[ ETCD INSTALLATION ]#######################

etcd_config(){
PKG_FAILED=0
echo "INSTALLING ETCD"
apt install etcd -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi

##BackUp The Original File
cp /etc/default/etcd /etc/default/etcd.bak
		
sleep 2
sed -i '/# ETCD_NAME="hostname"/a  ETCD_NAME="controller"\nETCD_DATA_DIR="/var/lib/etcd"\nETCD_INITIAL_CLUSTER_STATE="new"\nETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"\nETCD_INITIAL_CLUSTER="controller=http://10.0.0.11:2380"\nETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.0.11:2380"\nETCD_ADVERTISE_CLIENT_URLS="http://10.0.0.11:2379"\nETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"\nETCD_LISTEN_CLIENT_URLS="http://10.0.0.11:2379"' /etc/default/etcd

sleep 2
echo "systemctl enable etcd"
systemctl enable etcd
sleep 5
echo "systemctl restart etcd"
systemctl restart etcd
sleep 10


}
etcd_config
