iptables -F
service iptables save

#如果之前网卡命名为ethX，则执行如下命令：
########注意网卡初始化######
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

#更新源
cd /etc/yum.repos.d/
mkdir bak 
mv * bak
wget http://10.21.100.40/script/repo/base.repo  
wget http://10.21.100.40/script/repo/epel.repo  
wget http://10.21.100.40/script/repo/rdo-Icehouse.repo
yum clean all

setenforce 0
yum -y install ntp
yum -y install MySQL-python  iproute
yum -y install yum-plugin-priorities
yum -y install rdo-release-icehouse-3
rm -rf foreman.repo puppetlabs.repo rdo-release.repo
yum clean all
yum -y install crudini
yum -y install openstack-utils  openstack-selinux 
yum -y install kernel

#修改/boot/grub/grub.conf /boot
reboot
###################################################
mkdir /root/mistack
cd /root/mistack
export NETDEV=em1
export MYIP=`ifconfig $NETDEV|grep "inet addr:"|awk '{print $2}'|awk -F':' '{print $2}'`
export CONTROL='c3-pt-control01.bj'
export PASS='mistack9ijn0okm'
export TRUNKDEV=em3
echo $MYIP $CONTROL $PASS

################nova######################
#compute
yum -y install openstack-nova-compute libvirt
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$PASS@$CONTROL/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROL:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $CONTROL
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $PASS
###queue
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host $CONTROL
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_password guest
#openstack-config --set /etc/nova/nova.conf DEFAULT qpid_password guest
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_max_retries 0


openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $MYIP	
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $MYIP
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$CONTROL:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT resume_guests_state_on_host_boot True

openstack-config --set /etc/nova/nova.conf DEFAULT glance_host $CONTROL
openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm


service libvirtd start
service messagebus start
service openstack-nova-compute start 
chkconfig libvirtd on
chkconfig messagebus on
chkconfig openstack-nova-compute on
################neutron####################
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter=0/g'  /etc/sysctl.conf
echo  net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
sysctl -p

yum -y install  openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

cat > /etc/neutron/neutron.conf << EOF
[DEFAULT]
rabbit_host = $CONTROL
rabbit_password = guest
rabbit_userid = guest

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True

auth_strategy = keystone
nova_url = http://$CONTROL:8774/v2
nova_admin_username = nova
nova_admin_password = $PASS
nova_admin_auth_url = http://$CONTROL:35357/v2.0

core_plugin = ml2
service_plugins = router

[keystone_authtoken]
auth_uri = http://$CONTROL:5000
auth_host = $CONTROL
auth_protocol = http
auth_port = 35357
admin_tenant_name = service
admin_user = neutron
admin_password = $PASS


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
service openvswitch start

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

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

service openvswitch restart 
chkconfig openvswitch on
ovs-vsctl add-br br-int
########################test
ovs-vsctl add-br br-$TRUNKDEV
ovs-vsctl add-port br-$TRUNKDEV $TRUNKDEV

openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://$CONTROL:9696
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $PASS
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://$CONTROL:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron



###bug fixed
#cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
#sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent

#add by zhaowenwen 
#cd /usr/lib/python2.6/site-packages/nova/compute/
#mv manager.py manager_bk.py
#wget http://10.108.3.15/manager/manager.py /usr/lib/python2.6/site-packages/nova/compute/manager.py

service openstack-nova-compute restart
service neutron-openvswitch-agent restart 
chkconfig neutron-openvswitch-agent on
######################################################################
parted /dev/sdb -s mklabel gpt
parted /dev/sdb -s mkpart primary 0% 100%
mkfs.xfs /dev/sdb1
echo "/dev/sdb1 /var/lib/nova/instances xfs defaults 0 0" >> /etc/fstab
mount -t xfs /dev/sdb1 /var/lib/nova/instances
chown -R nova:nova /var/lib/nova/instances/
df -h
######################################################################

#升级qemu支持rbd
cd /etc/yum.repos.d/
wget http://10.21.100.40/script/repo/ceph.repo
cd /root/mistack  
yum -y install ceph-devel
yum -y install libfdt-devel
rpm -e qemu-kvm --nodeps
rpm -e qemu-img --nodeps
wget http://10.21.100.40/src/qemu-rbd.tgz
tar -xvf qemu-rbd.tgz
cd qemu
./configure --enable-rbd   --disable-gtk  --prefix=/usr
make -j8
make install

ln -s /usr/bin/qemu-system-x86_64 /usr/libexec/qemu-kvm
modprobe kvm
modprobe kvm-intel
chown root:kvm /dev/kvm
service libvirtd restart
service openstack-nova-compute restart

########################################################################
#推送到control和compute 
#先从sd-pt-cs00.bj登录c3-pt-storage01.bj(cd panxiaodong、cat host 第一个IP)
#先建立信任关系
ceph-deploy install {contorl && compute}
ceph-deploy --overwrite-conf config push {control && compute}
scp /etc/ceph/ceph.client.admin.keyring {control && compute}:/etc/ceph/
scp /etc/ceph/ceph.client.volumes.keyring {control && compute}:/etc/ceph/
scp /etc/ceph/ceph.client.images.keyring {control && compute}:/etc/ceph/   
scp /etc/ceph/ceph.client.backups.keyring {control && compute}:/etc/ceph/   
#####################################################################

############################################
#计算节点上
#修改nova.conf,在[libvirt]节点下添加
#控制节点uuid
cd /etc/ceph/
export MYUUID=52819656-78fd-4322-af9c-1c51995491f5
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

###ceph配置网络
#首先需要分配万兆IP
#配置em4 静态IP地址 
vi /etc/sysconfig/network-scripts/ifcfg-em4
#修改路由网关 
vi /etc/sysconfig/network
vi /etc/sysconfig/static-routes
route -n
#route del -net 169.254.0.0 netmask 255.255.0.0 dev em2