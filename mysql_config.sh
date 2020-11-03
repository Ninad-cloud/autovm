###################################  MYSQL  ##################################
#!/bin/bash
source /root/autovm/globalvar.sh

echo "INSTALL AND CONFIGURE MYSQL ON CONTROLLER NODE STARTED"
sleep 2
Mysql_config(){
PKG_FAILED=0
apt install mariadb-server python-pymysql -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi

sleep 3		
filepath="/etc/mysql/mariadb.conf.d/99-openstack.cnf"

if [ ! -f $filepath ]; then
echo "[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" >> $filepath
sleep 3
service mysql restart
sleep 10
fi

	echo -e "\n\n\e[36m######################## MYSQL INSTALL AND CONFIGURE ON CONTROLLER NODE IN DONE ################################# \e[0m\n"

}


Mysql_Secure_install(){

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$COMMON_PASS\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL" 

}
Mysql_config
Mysql_Secure_install
