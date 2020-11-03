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

##BACKUP THE ORIGINAL FILE
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak

#############################################################################################
echo "MODIFY keystone CONFIGURATION"
grep -q "^connection = mysql+pymysql" /etc/keystone/keystone.conf || sed -i '0,/^connection = sqlite/ s||connection = mysql+pymysql://keystone:'$COMMON_PASS'@controller/keystone\n#&|' /etc/keystone/keystone.conf

grep -q "^provider = fernet" /etc/keystone/keystone.conf || sed -i "/^\[token\]/ a provider = fernet" /etc/keystone/keystone.conf
sleep 2
echo "Populate The Identity Service"

echo "su -s /bin/sh -c "keystone-manage db_sync" keystone"

su -s /bin/sh -c "keystone-manage db_sync" keystone

echo "Database Populated for keystone!!!!!"
sleep 5

echo "######################INITIALIZE THE FERNET SETUP##############"

echo "keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone"
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sleep 2
echo "keystone-manage credential_setup --keystone-user keystone --keystone-group keystone"
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
sleep 2
echo "Check for the Bootstrap....."

echo "#########BOOTSTRAP THE IDENTITY SERVICE################"


echo "keystone-manage bootstrap --bootstrap-password redhat --bootstrap-admin-url http://controller:5000/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne"

keystone-manage bootstrap --bootstrap-password redhat --bootstrap-admin-url http://controller:5000/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne
  

  echo "DONE WITH THE BOOTSTRAP........."

  echo "#######################CONFIGURE APACHE HTTP SERVER#################"

  grep -q "^ServerName controller" /etc/apache2/apache2.conf || sed -i '$ a ServerName controller' /etc/apache2/apache2.conf
 echo "DONE CONFIGURING APACHE2......" 
  sleep 2
  echo "restart apache2"
  service apache2 restart
  sleep 5
  echo "DONE WITH SETTING APACHE HTTP"

echo "CONFIGURING ADMINISTRITIVE ACCOUNT......"

  export OS_USERNAME=admin
 echo "$OS_USERNAME"
  export OS_PASSWORD=$COMMON_PASS
 echo " $OS_PASSWORD"
  export OS_PROJECT_NAME=admin
 echo " $OS_PROJECT_NAME"
  export OS_USER_DOMAIN_NAME=Default
  echo "$OS_USER_DOMAIN_NAME"
  export OS_PROJECT_DOMAIN_NAME=Default
 echo " $OS_PROJECT_DOMAIN_NAME"
  export OS_AUTH_URL=http://controller:5000/v3
 echo " $OS_AUTH_URL"
  export OS_IDENTITY_API_VERSION=3
 echo " $OS_IDENTITY_API_VERSION"

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

echo "DONE WITH CREAING ADMIN AND DEMO ACCOUNT"
sleep 2
echo "#####CREATE domain, project,and user roles ########### "

source ./admin-openrc
echo "$OS_PROJECT_DOMAIN_NAME"
echo "$OS_PROJECT_NAME"
echo "$OS_USER_DOMAIN_NAME"
echo "$OS_USERNAME"
echo "$OS_PASSWORD"
echo "$OS_AUTH_URL"
echo "$OS_IDENTITY_API_VERSION"
echo "$OS_IMAGE_API_VERSION"

echo "openstack domain create --description "An Example Domain" example"
openstack domain create --description "An Example Domain" example
sleep 2
echo "openstack project create --domain default --description "Service Project" service"
openstack project create --domain default --description "Service Project" service

#sleep 5
#####DEMO PROJECT for non-Admin tasks##########
sleep 3
echo "openstack project create --domain default --description "Demo Project" myproject"
openstack project create --domain default --description "Demo Project" myproject
sleep 5
echo "openstack user create --domain default --password $COMMON_PASS myuser"
openstack user create --domain default --password $COMMON_PASS myuser
sleep 5
echo "openstack role create myrole"
openstack role create myrole
sleep 5
echo "openstack role add --project myproject --user myuser myrole"
openstack role add --project myproject --user myuser myrole

#####Verification Operations of the Identity SERVICE################

unset OS_AUTH_URL OS_PASSWORD
echo "unset= $OS_AUTH_URL $OS_PASSWORD"

ERROR=""
echo "openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin --os-password $COMMON_PASS token issue"
openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin --os-password $COMMON_PASS token issue || ERROR="YES"

####Request Authentication token for myuser user###############
echo "openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name myproject --os-username myuser --os-password $COMMON_PASS token issue"
openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name myproject --os-username myuser --os-password $COMMON_PASS token issue || ERROR="YES"

#####Using the Client Scripts Request Authentication#########

source ./admin-openrc
echo "$OS_PROJECT_DOMAIN_NAME"
echo "$OS_PROJECT_NAME"
echo "$OS_USER_DOMAIN_NAME"
echo "$OS_USERNAME"
echo "$OS_PASSWORD"
echo "$OS_AUTH_URL"
echo "$OS_IDENTITY_API_VERSION"
echo "$OS_IMAGE_API_VERSION"
  
echo "openstack token issue" 
openstack token issue || ERROR="YES"

if [ -z $ERROR ];then
	echo -e "\nKeyStone Service Installation Sucessful!"
else
	echo -e "\nKeyStone Service Installation FAILED, EXITING..!"	
	exit
fi

	echo -e "\n\e[36m[[Keystone]: SERVICE IS ALREADY CONFIGURED, IGNORING DUPLICATION..\e[0m\n"
	

	echo -e "\n\n\n\e[36m######################[ KEYSTONE ] : SERVICE DEPLOYED SUCCESFULLY #####################\e[0m\n\n\n"
  
}
keystone_service
