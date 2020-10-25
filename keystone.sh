#!/bin/bash
source /root/autovm/globalvar.sh


######################[ KEYSTONE SERVICE ]########################

keystone_service(){

echo "CREATE A DATABASE keystone"

mysql << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$COMMON_PASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$COMMON_PASS';
EOF

sleep 5
PKG_FAILED=0
apt install keystone -y || PKG_FAILED=1
		if [ $PKG_FAILED -gt 0 ];then
			echo -e "\e[31m\n$1 PACKAGE INSTALLATION FAILED, EXITING THE SCRIPT [ INSTALLATION FAILED ] \e[0m\n"
			exit
		else
			echo -e "\n--- $1 PACKAGE INSTALLATION IS \e[36m[ DONE ] \e[0m ----\n"		
		fi


echo "MODIFY keystone CONFIGURATION"
grep -q "^connection = mysql+pymysql" /etc/keystone/keystone.conf || sed -i '0,/^connection = sqlite/ s||connection = mysql+pymysql://keystone:'$COMMON_PASS'@controller/keystone\n#&|' /etc/keystone/keystone.conf

sleep 2
grep -q "^provider = fernet" /etc/keystone/keystone.conf || sed -i "/^\[token\]/ a provider = fernet" /etc/keystone/keystone.conf
sleep 2
echo "Populate The Identity Service"

su -s /bin/sh -c "keystone-manage db_sync" keystone
echo "Database Populated for keystone!!!!!"
sleep 5
echo "######################INITIALIZE THE FERNET SETUP##############"
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sleep 2
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
sleep 2

echo "#########BOOTSTRAP THE IDENTITY SERVICE################"

keystone-manage bootstrap --bootstrap-password $COMMON_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
  
  
  echo "#######################CONFIGURE APACHE HTTP SERVER#################"
  

  grep -q "^ServerName controller" /etc/apache2/apache2.conf || sed -i '$ a ServerName controller' /etc/apache2/apache2.conf
  
  sleep 2
  echo "restart apache2"
  service apache2 restart
  sleep 5
  echo "DONE WITH SETTING APACHE HTTP"

  export OS_USERNAME=admin
  export OS_PASSWORD=$COMMON_PASS
  export OS_PROJECT_NAME=admin
  export OS_USER_DOMAIN_NAME=Default
  export OS_PROJECT_DOMAIN_NAME=Default
  export OS_AUTH_URL=http://controller:5000/v3
  export OS_IDENTITY_API_VERSION=3

  #########ADMIN USER##################  
  echo "export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$COMMON_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" > admin-openrc
#remove starting space
sed -i 's/^[\t]*//g' admin-openrc


#####DEMO USER########################
echo "export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=myproject
export OS_USERNAME=myuser
export OS_PASSWORD=$COMMON_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" > demo-openrc
# remove starting space
sed -i 's/^[\t]*//g' demo-openrc


echo "#####CREATE domain, project,and user roles ########### "
source /root/autovm/admin-openrc

openstack domain create --description "An Example Domain" example
sleep 2
openstack project create --domain default --description "Service Project" service
sleep 2


#####DEMO PROJECT for non-Admin tasks##########
openstack project create --domain default --description "Demo Project" myproject

openstack user create --domain default --password $COMMON_PASS myuser
openstack role create myrole
openstack role add --project myproject --user myuser myrole

#####Verification Operations of the Identity SERVICE################

unset OS_AUTH_URL OS_PASSWORD

openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin --os-password $COMMON_PASS token issue

####Request Authentication token for myuser user###############

openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name myproject --os-username myuser --os-password $COMMON_PASS token issue

#####Using the Client Scripts Request Authentication#########

source ./admin-openrc
  
openstack token issue

  
}
keystone_service
