#Init System
```
iptables -F
service iptables save
yum -y install ntp
export PASS=`openssl rand -hex 10`
export MYIP=`ifconfig eth1|grep "inet addr:"|awk '{print $2}'|awk -F':' '{print $2}'`
```

###Config MySQL
```
yum -y install mysql mysql-server MySQL-python
cat /etc/my.cnf << EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
symbolic-links=0

default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF
```

###Start MySQL
```
service mysqld start
chkconfig mysqld on
```

###Config Yum
```
yum -y install yum-plugin-priorities
yum -y install http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
yum -y install ftp://ftp.is.co.za/mirror/fedora.redhat.com/epel/6/i386/crudini-0.3-2.el6.noarch.rpm
yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install openstack-utils  openstack-selinux 
yum -y install kernel
```


#Install RabbitMQ
```
yum -y install rabbitmq-server
chkconfig rabbitmq-server on
service  rabbitmq-server start
rabbitmqctl status
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/etc/init.d/rabbitmq-server restart
curl http://localhost:55672/mgmt/  #user:guest:guest 
```


#Install Keystone
```
yum -y install openstack-keystone python-keystoneclient
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:$PASS@$MYIP/keystone 

cat > keystone.sql << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY "$PASS"; 
exit
EOF

mysql -uroot < keystone.sql
su -s /bin/sh -c "keystone-manage db_sync" keystone
```

###flush token
```
(crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '01 * * * * /usr/bin/keystone-manage token_flush >/var/log/keystone/ keystone-tokenflush.log 2>&1' >> /var/spool/cron/keystone

ADMIN_TOKEN=$(openssl rand -hex 10)
echo $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/ssl 
chmod -R o-rwx /etc/keystone/ssl
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://$MYIP:35357/v2.0

keystone user-create --name=admin --pass=$PASS --email=admin@test.com
keystone role-create --name=admin
keystone tenant-create --name=admin --description="Admin Tenant"
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin

keystone user-create --name=demo --pass=$PASS --email=demo@test.com
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo
keystone tenant-create --name=service --description="Service Tenant"

keystone service-create --name=keystone --type=identity  --description="OpenStack Identity"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ identity / {print $2}')  \
--publicurl=http://$MYIP:5000/v2.0  \
--internalurl=http://$MYIP:5000/v2.0  \
--adminurl=http://$MYIP:35357/v2.0

keystone --os-username=admin --os-tenant-name=admin --os-password=$PASS --os-auth-url=http://$MYIP:35357/v2.0 token-get

cat > admin_openrc.sh << EOF
export OS_USERNAME=admin
export OS_PASSWORD=$PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$MYIP:35357/v2.0
EOF
source admin_openrc.sh

keystone token-get
keystone user-list
```


#Install Glance
```
yum -y install openstack-glance python-glanceclient
openstack-config --set /etc/glance/glance-api.conf database  connection mysql://glance:$PASS@$MYIP/glance
openstack-config --set /etc/glance/glance-registry.conf database  connection mysql://glance:$PASS@$MYIP/glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/glance/glance-api.conf DEFAULT qpid_hostname $MYIP

cat > glance.sql << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost'  IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%'  IDENTIFIED BY "$PASS";
EOF
mysql -uroot < glance.sql
su -s /bin/sh -c "glance-manage db_sync" glance

keystone user-create --name=glance --pass=$PASS  --email=glance@test.com
keystone user-role-add --user=glance --tenant=service --role=admin


openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$MYIP:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host $MYIP
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password $PASS
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$MYIP:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken  auth_host $MYIP
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.confkeystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $PASS
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

keystone service-create --name=glance --type=image --description="OpenStack Image Service" 
keystone endpoint-create --service-id=$(keystone service-list | awk '/ image / {print $2}')  --publicurl=http://$MYIP:9292  --internalurl=http://$MYIP:9292  --adminurl=http://$MYIP:9292

service openstack-glance-api start
service openstack-glance-registry start 
chkconfig openstack-glance-api on
chkconfig openstack-glance-registry on

wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 --container-format bare --is-public True --progress < cirros-0.3.2-x86_64-disk.img
glance image-list
```


#Install Nova
```
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$PASS@$MYIP/nova

openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_username guest
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_password guest

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $MYIP	
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $MYIP

cat > nova.sql << EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%'  IDENTIFIED BY "$PASS";
EOF
mysql -uroot < nova.sql

su -s /bin/sh -c "nova-manage db sync" nova
 
keystone user-create --name=nova --pass=$PASS --email=nova@test.com
keystone user-role-add --user=nova --tenant=service --role=admin
```

###auth
```
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$MYIP:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $MYIP
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $PASS
```

###keystone
```
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ compute / {print $2}')  \
--publicurl=http://$MYIP:8774/v2/%\(tenant_id\)s  \
--internalurl=http://$MYIP:8774/v2/%\(tenant_id\)s  \
--adminurl=http://$MYIP:8774/v2/%\(tenant_id\)s
```

###start service
```
service openstack-nova-api start
service openstack-nova-cert start
service openstack-nova-consoleauth start 
service openstack-nova-scheduler start 
service openstack-nova-conductor start 
service openstack-nova-novncproxy start 
chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-consoleauth on 
chkconfig openstack-nova-scheduler on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-novncproxy on
```

###test nova
```
nova image-list
```

###ompute
```
yum -y install openstack-nova-compute libvirt
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$PASS@$MYIP/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$MYIP:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $MYIP
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $PASS
```

###queue
```
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_username guest
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_password guest

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $MYIP	
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$MYIP:6080/vnc_auto.html

openstack-config --set /etc/nova/nova.conf DEFAULT glance_host $MYIP
openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
```

###start service
```
service libvirtd start
service messagebus start
service openstack-nova-compute start 
chkconfig libvirtd on
chkconfig messagebus on
chkconfig openstack-nova-compute on
```

#Install Neutron
```
cat > neutron.sql << EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY "$MYIP";
EOF
mysql -uroot < neutron.sql

keystone user-create --name neutron --pass $PASS --email neutron@test.com
keystone user-role-add --user neutron --tenant service --role admin

keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create --service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://$MYIP:9696 \
--adminurl http://$MYIP:9696 \
--internalurl http://$MYIP:9696

yum -y install openstack-neutron openstack-neutron-ml2 python-neutronclient
```

###auth
```
openstack-config --set /etc/neutron/neutron.conf database connection  mysql://neutron:$PASS@$MYIP/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT  auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_uri http://$MYIP:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_host $MYIP
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_password $PASS
```

###queue
```
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_host $MYIP
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_password guest
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_userid guest

openstack-config --set /etc/neutron/neutron.conf DEFAULT  notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT  notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT  nova_url http://$MYIP:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT  nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT  nova_admin_tenant_id $(keystone tenant-list | awk '/ service / { print $2 }')
openstack-config --set /etc/neutron/neutron.conf DEFAULT  nova_admin_password $PASS
openstack-config --set /etc/neutron/neutron.conf DEFAULT  nova_admin_auth_url http://$MYIP:35357/v2.0

openstack-config --set /etc/neutron/neutron.conf DEFAULT  core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT  service_plugins router


openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True

openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://$MYIP:9696
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $PASS
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://$MYIP:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron

service openstack-nova-api restart
service openstack-nova-scheduler restart 
service openstack-nova-conductor restart

service neutron-server start 
chkconfig neutron-server on
```

###network
```
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward=1/g'  /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter=0/g'  /etc/sysctl.conf
echo  net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
sysctl -p

yum -y install openstack-neutron openstack-neutron-ml2  openstack-neutron-openvswitch
```

###l3
```
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT  interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT  use_namespaces True
```

###dhcp
```
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  auth_url http://$MYIP:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  admin_password $PASS
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  nova_metadata_ip $MYIP
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT  metadata_proxy_shared_secret $PASS

openstack-config --set /etc/nova/nova.conf DEFAULT  service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT  neutron_metadata_proxy_shared_secret $PASS
service openstack-nova-api restart
```

###gre setting
```
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  local_ip $MYIP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  enable_tunneling True

service openvswitch start 
chkconfig openvswitch on
ovs-vsctl add-br br-int

ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

###bug fixed
```
cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent
```

###start service
```
service openvswitch start 
service neutron-openvswitch-agent start 
service neutron-l3-agent start
service neutron-dhcp-agent start
service neutron-metadata-agent start
chkconfig neutron-openvswitch-agent on 
chkconfig neutron-l3-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-metadata-agent on
chkconfig openvswitch on
ovs-vsctl add-br br-int
```

###nova
```
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://$MYIP:9696
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $PASS
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://$MYIP:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron

service openstack-nova-compute restart
service neutron-openvswitch-agent start 
chkconfig neutron-openvswitch-agent on
```

#Install DashBoard
```
yum -y install memcached python-memcached mod_wsgi openstack-dashboard
service memcached start

sed -i 's/horizon.example.com/0.0.0.0/g' /etc/openstack-dashboard/local_settings
service httpd start
service memcached start
chkconfig httpd on
chkconfig memcached on
```















