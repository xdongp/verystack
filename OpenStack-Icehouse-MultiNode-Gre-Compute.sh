#初始化工作
#all
iptables -F
service iptables save
yum -y install ntp
export PASS=`openssl rand -hex 10`
export MYIP=`ifconfig eth1|grep "inet addr:"|awk '{print $2}'|awk -F':' '{print $2}'`


yum -y install MySQL-python

#all
yum -y install yum-plugin-priorities
yum -y install http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
yum -y install ftp://ftp.is.co.za/mirror/fedora.redhat.com/epel/6/i386/crudini-0.3-2.el6.noarch.rpm
yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install openstack-utils  openstack-selinux 
yum -y install kernel



################nova######################
#compute
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

###queue
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

service libvirtd start
service messagebus start
service openstack-nova-compute start 
chkconfig libvirtd on
chkconfig messagebus on
chkconfig openstack-nova-compute on


################neutron####################
#compute
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter=0/g'  /etc/sysctl.conf
echo  net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
sysctl -p

yum -y install openstack-neutron-ml2 openstack-neutron-openvswitch

###auth
openstack-config --set /etc/neutron/neutron.conf DEFAULT  auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_uri http://$MYIP:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_host $MYIP
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken  admin_password $PASS

###queue
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_host $MYIP
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_password guest
openstack-config --set /etc/neutron/neutron.conf DEFAULT  rabbit_userid guest

###ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT  core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT  service_plugins router


openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  local_ip $MYIP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs  enable_tunneling True

service openvswitch start 
chkconfig openvswitch on
ovs-vsctl add-br br-int


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

ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

###bug fixed
cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent

service openstack-nova-compute restart
service neutron-openvswitch-agent start 
chkconfig neutron-openvswitch-agent on
















