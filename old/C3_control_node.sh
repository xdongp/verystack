iptables -F
service iptables save

#如果之前网卡命名为ethX，则执行如下命令：
cd /etc/udev/rules.d && mv 70-persistent-net.rules /root/ 
cd /etc/sysconfig/network-scripts/
mv ifcfg-eth0  ifcfg-eth2.bak
mv ifcfg-eth1  ifcfg-eth3.bak
mv ifcfg-eth2  ifcfg-eth0
mv ifcfg-eth3  ifcfg-eth1
mv ifcfg-eth2.bak  ifcfg-eth2
mv ifcfg-eth3.bak  ifcfg-eth3
sed  -i "s/eth2/eth0/g" ifcfg-eth0
sed  -i "s/eth3/eth1/g" ifcfg-eth1
sed  -i "s/eth0/eth2/g" ifcfg-eth2
sed  -i "s/eth1/eth3/g" ifcfg-eth3
    
mv ifcfg-eth0 ifcfg-em1 && sed  -i "s/eth0/em1/g" ifcfg-em1
mv ifcfg-eth1 ifcfg-em2 && sed  -i "s/eth1/em2/g" ifcfg-em2
mv ifcfg-eth2 ifcfg-em3 && sed  -i "s/eth2/em3/g" ifcfg-em3
mv ifcfg-eth3 ifcfg-em4 && sed  -i "s/eth3/em4/g" ifcfg-em4

cd /etc/yum.repos.d/	
mkdir bak 
mv * bak
wget http://10.21.100.40/script/repo/base.repo  
wget http://10.21.100.40/script/repo/epel.repo  
wget http://10.21.100.40/script/repo/rdo-Icehouse.repo
yum clean all

setenforce 0
yum -y install ntp

yum -y install mysql mysql-server MySQL-python  iproute

cat > /etc/my.cnf << EOF
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

service mysqld start
chkconfig mysqld on


cd /etc/yum.repos.d/ && rm -f foreman.repo puppetlabs.repo rdo-release.repo
yum clean all
yum -y install crudini
yum -y install openstack-utils  openstack-selinux 
yum -y install kernel

#修改/boot/grub/grub.conf /boot
reboot
###################################################
export NETDEV=em1
export PASS='mistack9ijn0okm'
export TRUNKDEV=em3
export MYIP=`ifconfig $NETDEV|grep "inet addr:"|awk '{print $2}'|awk -F':' '{print $2}'`
export GATEWAY=`route -n|grep UG|awk '{print $2}' |head -n 1`
export MYMAC=`ifconfig $NETDEV|grep HW|awk  '{print $5}'`
echo $NETDEV $PASS $MYIP $GATEWAY $MYMAC


#Install RabbitMQ
yum -y install rabbitmq-server
chkconfig rabbitmq-server on
service  rabbitmq-server start
rabbitmqctl status
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/etc/init.d/rabbitmq-server restart
curl http://localhost:55672/mgmt/  #user:guest:guest 

#Install Keystone
yum -y install openstack-keystone python-keystoneclient
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:$PASS@$MYIP/keystone 

cat > keystone.sql << EOF
use  mysql
delete from user where user='';
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY "$PASS";

GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY "$PASS"; 
flush privileges;
EOF

mysql -uroot < keystone.sql
su -s /bin/sh -c "keystone-manage db_sync" keystone

(crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '01 * * * * /usr/bin/keystone-manage token_flush >/var/log/keystone/ keystone-tokenflush.log 2>&1' >> /var/spool/cron/keystone

ADMIN_TOKEN=$(openssl rand -hex 10)
echo $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/ssl 
chmod -R o-rwx /etc/keystone/ssl
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://$MYIP:35357/v2.0

service  openstack-keystone start
chkconfig openstack-keystone on
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

unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT OS_ENDPOINT SERVICE_TOKEN
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

#Install Glance
yum -y install openstack-glance python-glanceclient
openstack-config --set /etc/glance/glance-api.conf database  connection mysql://glance:$PASS@$MYIP/glance
openstack-config --set /etc/glance/glance-registry.conf database  connection mysql://glance:$PASS@$MYIP/glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_host $MYIP
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_userid guest
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_password guest



cat > glance.sql << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost'  IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%'  IDENTIFIED BY "$PASS";
EOF
mysql -uroot < glance.sql
mv  /usr/lib/python2.6/site-packages/glance/common/crypt.py /usr/lib/python2.6/site-packages/glance/common/crypt_bk.py
ln /usr/lib64/python2.6/crypt.py /usr/lib/python2.6/site-packages/glance/common/crypt.py
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
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
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

#Install Nova
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$PASS@$MYIP/nova

openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_password guest

#openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $MYIP
#openstack-config --set /etc/nova/nova.conf DEFAULT qpid_username guest
#openstack-config --set /etc/nova/nova.conf DEFAULT qpid_password guest

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

###auth
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$MYIP:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $MYIP
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $PASS
 
 ###keystone
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
keystone endpoint-create --service-id=$(keystone service-list | awk '/ compute / {print $2}')  \
--publicurl=http://$MYIP:8774/v2/%\(tenant_id\)s  \
--internalurl=http://$MYIP:8774/v2/%\(tenant_id\)s  \
--adminurl=http://$MYIP:8774/v2/%\(tenant_id\)s

###start service
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

###test nova
nova image-list

#Install Neutron
cat > neutron.sql << EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY "$PASS";
flush privileges;
EOF
mysql -uroot < neutron.sql

keystone user-create --name neutron --pass $PASS --email neutron@test.com
keystone user-role-add --user neutron --tenant service --role admin

keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create --service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://$MYIP:9696 \
--adminurl http://$MYIP:9696 \
--internalurl http://$MYIP:9696

###network
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward=1/g'  /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter=0/g'  /etc/sysctl.conf
echo  net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
sysctl -p

yum -y install openstack-neutron openstack-neutron-ml2  openstack-neutron-openvswitch
service openvswitch start



#neutron.conf
cat > /etc/neutron/neutron.conf << EOF
[DEFAULT]
rabbit_host = $MYIP
rabbit_password = guest
rabbit_userid = guest

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True

auth_strategy = keystone
nova_url = http://$MYIP:8774/v2
nova_admin_username = nova
nova_admin_tenant_id = $(keystone tenant-list | awk '/ service / { print $2 }')
nova_admin_password = $PASS
nova_admin_auth_url = http://$MYIP:35357/v2.0

core_plugin = ml2
service_plugins = router

[keystone_authtoken]
auth_uri = http://$MYIP:5000
auth_host = $MYIP
auth_protocol = http
auth_port = 35357
admin_tenant_name = service
admin_user = neutron
admin_password = $PASS

[database]
connection = mysql://neutron:$PASS@$MYIP/neutron

[service_providers]
service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default
EOF
service neutron-openvswitch-agent start 

cat > /etc/neutron/plugins/ml2/ml2_conf.ini << EOF
[ml2]
type_drivers = vlan
tenant_network_types = vlan
mechanism_drivers = openvswitch

[ml2_type_flat]

[ml2_type_vlan]
network_vlan_ranges = physnet1:1:4000

[ml2_type_gre]

[ml2_type_vxlan]

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF

cat > /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini << EOF
[ovs]
enable_tunneling = False
integration_bridge=br-int
network_vlan_ranges = physnet1
bridge_mappings = physnet1:br-$TRUNKDEV

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF
#mv /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugins/openvswitch/ovs_neutron_plugin_bk.ini
#cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

###l3
cat > /etc/neutron/l3_agent.ini  << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
use_namespaces = True
EOF

###dhcp
cat > /etc/neutron/dhcp_agent.ini  << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
use_namespaces = True
ovs_integration_bridge = br-int
EOF

###meta
cat > /etc/neutron/metadata_agent.ini << EOF
[DEFAULT]
auth_url = http://$MYIP:5000/v2.0
auth_region = regionOne
admin_tenant_name = service
admin_user = neutron
admin_password = $PASS
nova_metadata_ip = $MYIP
metadata_proxy_shared_secret = $PASS
EOF

###nova
openstack-config --set /etc/nova/nova.conf DEFAULT  service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT  neutron_metadata_proxy_shared_secret $PASS

###nova
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
#
service openvswitch restart
ovs-vsctl add-br br-int
ovs-vsctl add-br br-$TRUNKDEV
ovs-vsctl add-port br-$TRUNKDEV $TRUNKDEV

service neutron-openvswitch-agent restart 
service openstack-nova-api restart
service openstack-nova-scheduler restart 
service openstack-nova-conductor restart
service neutron-server start 
service openvswitch start
#service openstack-nova-compute restart
#service neutron-l3-agent start
service neutron-dhcp-agent start
service neutron-metadata-agent start

chkconfig neutron-openvswitch-agent on
chkconfig neutron-server on
#chkconfig neutron-l3-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-metadata-agent on
chkconfig openvswitch on

#Install DashBoard
yum -y install memcached python-memcached mod_wsgi openstack-dashboard
service memcached start


sed -i 's/horizon.example.com/*/g' /etc/openstack-dashboard/local_settings
service httpd start
service memcached start
chkconfig httpd on
chkconfig memcached on

#安装Cinder
cat > cinder.sql << EOF
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY "$PASS";
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY "$PASS";
flush privileges;
EOF
mysql -uroot < cinder.sql


###创建用户
keystone user-create --name cinder --pass $PASS
keystone user-role-add --user cinder --tenant service --role admin
keystone service-create --name cinder --type volume --description "OpenStack Block Storage"

keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ volume / {print $2}') \
  --publicurl http://$MYIP:8776/v1/%\(tenant_id\)s \
  --internalurl http://$MYIP:8776/v1/%\(tenant_id\)s \
  --adminurl http://$MYIP:8776/v1/%\(tenant_id\)s \
  --region regionOne
#keystone endpoint-create \
#  --service-id $(keystone service-list | awk '/ volumev2 / {print $2}') \
#  --publicurl http://$MYIP:8776/v2/%\(tenant_id\)s \
#  --internalurl http://$MYIP:8776/v2/%\(tenant_id\)s \
#  --adminurl http://$MYIP:8776/v2/%\(tenant_id\)s \
#  --region regionOne

yum install -y openstack-cinder python-cinderclient python-oslo-db

openstack-config --set /etc/cinder/cinder.conf database  connection mysql://cinder:$PASS@$MYIP/cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host $MYIP
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_userid guest
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_password guest
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $MYIP


openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$MYIP:5000/v2.0
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$MYIP:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $PASS

su -s /bin/sh -c "cinder-manage db sync" cinder
service  openstack-cinder-api start
service  openstack-cinder-scheduler start
service openstack-cinder-volume start
chkconfig openstack-cinder-api on
chkconfig openstack-cinder-scheduler on
chkconfig openstack-cinder-volume on

######################################################
#配置ceph,不适用ceph以下可以不配置[@ceph mon]
#安装ceph，参见《ceph安装.sh》
###在ceph mon上
#1.创建pool
ceph osd pool create volumes 128
ceph osd pool create images 128
ceph osd pool create backups 128
#2.创建image key
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.images.keyring
sudo chmod +r /etc/ceph/ceph.client.images.keyring
sudo ceph-authtool /etc/ceph/ceph.client.images.keyring -n client.images --gen-key
sudo ceph-authtool -n client.images --cap mon 'allow r' --cap osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' /etc/ceph/ceph.client.images.keyring
ceph auth add client.images -i /etc/ceph/ceph.client.images.keyring
#3.创建volumes key
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.volumes.keyring
sudo chmod +r /etc/ceph/ceph.client.volumes.keyring
sudo ceph-authtool /etc/ceph/ceph.client.volumes.keyring -n client.volumes --gen-key
sudo ceph-authtool -n client.volumes --cap mon 'allow r' --cap osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rx pool=images' /etc/ceph/ceph.client.volumes.keyring
ceph auth add client.volumes -i /etc/ceph/ceph.client.volumes.keyring
#4.创建backups key
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.backups.keyring
sudo chmod +r /etc/ceph/ceph.client.backups.keyring
sudo ceph-authtool /etc/ceph/ceph.client.backups.keyring -n client.backups --gen-key
sudo ceph-authtool -n client.backups --cap mon 'allow r' --cap osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups' /etc/ceph/ceph.client.backups.keyring
ceph auth add client.backups -i /etc/ceph/ceph.client.backups.keyring
#5.在mon节点的ceph.conf下添加
[client.images]
keyring = /etc/ceph/ceph.client.images.keyring

[client.volumes]
keyring = /etc/ceph/ceph.client.volumes.keyring

[client.backups]
keyring = /etc/ceph/ceph.client.backups.keyring
#推送到control和compute
ceph-deploy install {contorl && compute}
ceph-deploy --overwrite-conf config push {control && compute}
scp /etc/ceph/ceph.client.admin.keyring {control && compute}:/etc/ceph/
scp /etc/ceph/ceph.client.volumes.keyring {control && compute}:/etc/ceph/
scp /etc/ceph/ceph.client.images.keyring {control && compute}:/etc/ceph/   
scp /etc/ceph/ceph.client.backups.keyring {control && compute}:/etc/ceph/   


##################[config libvirt]#######################
#配置Libvirt key,配置迁移需要所有key uuid一样
export MYUUID=`uuidgen`
ceph auth get-key client.volumes | sudo tee client.volumes.key
cat >  secret.xml  << EOF 
   <secret ephemeral='no' private='no'>
  	  <uuid>$MYUUID</uuid>
      <usage type='ceph'>
         <name>client.volumes secret</name>
      </usage>
   </secret>
EOF
virsh secret-define --file secret.xml 
virsh secret-set-value --secret $MYUUID --base64 $(cat client.volumes.key) && rm -f client.volumes.key secret.xml

##################[ceph glance]##########################
#修改配置glance-api.conf，添加：
   default_store=rbd
   rbd_store_user=images
   rbd_store_pool=images
   show_image_direct_url=True
   rbd_store_ceph_conf=/etc/ceph/ceph.conf
   rbd_store_chunk_size=8
#重启
   service openstack-glance-api restart


####################[ceph cinder]#######################
#修改配置cinder.conf，添加
   volume_driver=cinder.volume.drivers.rbd.RBDDriver
   rbd_user=volumes
   rbd_secret_uuid=457eb676-33da-42ec-9a8c-9293d545c337
   rbd_pool=volumes
   rbd_ceph_conf=/etc/ceph/ceph.conf
   rbd_flatten_volume_from_snapshot=false
   rbd_max_clone_depth=5
#重启
   service openstack-cinder-volume restart
   rados -p images ls
   rados -p volumes ls
	   
####################[ceph cinder backup]##################
   backup_driver=cinder.backup.drivers.ceph
   backup_ceph_conf=/etc/ceph/ceph.conf
   backup_ceph_user=cinder-backup
   backup_ceph_pool=backups
   backup_ceph_chunk_size=134217728
   backup_ceph_stripe_unit=0
   backup_ceph_stripe_count=0
   restore_discard_excess_bytes=true
#重启  
   service openstackcinder-backup restart

   

##################[ceph nova]############################
#在计算节点上使用ceph,配置nova和libvirt,升级qemu[@计算节点]
###升级qemu支持rbd
yum install ceph-devel
yum install libfdt-devel
rpm -e qemu-kvm --nodeps
rpm -e qemu-img --nodeps
wget http://10.21.100.40/src/qemu-rbd.tgz
tar -xvf qemu-rbd.tgz
cd qemu
./configure --enable-rbd --disable-gtk --prefix=/usr
make -j8
make install
service libvirtd restart
service openstack-nova-compute restart

#修改nova.conf,在[libvirt]节点下添加
export MYUUID=52819656-78fd-4322-af9c-1c51995491f5
cat > rbd.tmp << EOF
libvirt_images_type=rbd
libvirt_images_rbd_pool=volumes
libvirt_images_rbd_ceph_conf=/etc/ceph/ceph.conf
libvirt_inject_password=false
libvirt_inject_key=false
libvirt_inject_partition=-2
rbd_user=volumes
rbd_secret_uuid=$MYUUID 
live_migration_flag=VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE,VIR_MIGRATE_PERSIST_DEST
EOF
sed -i '/\[libvirt\]/ r ./rbd.tmp' /etc/nova/nova.conf
rm  -f ./rbd.tmp

#配置迁移，修改libvirt配置
#修改/etc/libvirt/libvirtd.conf
sed -i 's/#listen_tls = 0/listen_tls = 0/g' /etc/libvirt/libvirtd.conf
sed -i 's/#listen_tcp = 1/listen_tcp = 1/g' /etc/libvirt/libvirtd.conf
sed -i 's/#auth_tcp = "sasl"/auth_tcp = "none"/g' /etc/libvirt/libvirtd.conf

#修改 /etc/sysconfig/libvirtd 
sed -i 's/#LIBVIRTD_ARGS="--listen"/LIBVIRTD_ARGS="--listen"/g' /etc/sysconfig/libvirtd 

#重启libvirtd
service libvirtd restart
#重启nova
service  openstack-nova-compute restart
