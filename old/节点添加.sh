export CTRLIP=10.21.100.41                     #控制节点ip
export NEUTRON_MYSQL_PASS="807788807cfd43e0"   #/etc/nova/nova.conf中neutron_admin_password值
export BR_ETH=em3                              #虚拟机上网的网卡
export MYIP=`ifconfig em1|grep "inet addr:"|awk '{print $2}'|awk -F':' '{print $2}'`
#安装Nova

cd /etc/yum.repos.d/
mkdir bak
mv * bak
wget http://10.21.100.40/script/repo/base.repo
wget http://10.21.100.40/script/repo/epel.repo
wget http://10.21.100.40/script/repo/puppet.repo
wget http://10.21.100.40/script/repo/rdo-release.repo
wget http://10.21.100.40/script/repo/ssl.repo
yum clean all

yum -y install puppet

yum -y install openstack-utils  openstack-selinux mysql
yum -y install openstack-nova-compute
#若要指定版本：
yum -y install python-nova-2013.2.1-1.el6
yum -y install openstack-nova-compute-2013.2.1-1.el6
yum -y install openstack-utils-2013.2-1.el6.1
yum -y install openstack-selinux-0.1.2-11.el6

cd /etc/nova && mv nova.conf nova.conf.bak
wget http://10.21.100.56/src/package/openstack/nova.conf
sed -i "s/10.200.100.25/$CTRLIP/g" nova.conf
sed -i "s/10.200.100.19/$MYIP/g" nova.conf
#修改neutron密码(neutron_admin_password=2b0da7d15d0b4a21)
sed -i -e "s/^neutron_admin_password=.*/neutron_admin_password=$NEUTRON_MYSQL_PASS/g" /etc/nova/nova.conf
sed -i 's/#resume_guests_state_on_host_boot=false/resume_guests_state_on_host_boot=true/g' /etc/nova/nova.conf
#sed -i 's/569e79bcb80f487e/$NEUTRON_MYSQL_PASS/g' nova.conf
chkconfig  openstack-nova-compute  on
chkconfig libvirtd on
chkconfig messagebus on
service messagebus start 
service libvirtd start

#安装Neutron
iptables -F
service iptables save 
sed -i 's/call-ip6tables = 0/call-ip6tables=1/g' /etc/sysctl.conf
sed -i 's/call-iptables = 0/call-iptables=1/g' /etc/sysctl.conf
sed -i 's/call-arptables = 0/call-arptables=1/g'  /etc/sysctl.conf
sysctl -p

yum -y install openstack-neutron-openvswitch
#若要指定版本
yum -y install openstack-neutron-2013.2-1.el6
yum -y install python-neutron-2013.2-1.el6
yum -y install openstack-neutron-openvswitch-2013.2-1.el6
 
service openvswitch start
chkconfig openvswitch on

ovs-vsctl add-br br-int
ovs-vsctl add-br br-$BR_ETH
ovs-vsctl add-port br-$BR_ETH $BR_ETH
cd /etc/neutron
mv neutron.conf neutron.conf.bak 
wget http://10.21.100.56/src/package/openstack/neutron.conf
sed -i "s/10.200.100.25/$CTRLIP/g" neutron.conf
cd plugins/openvswitch/
mv ovs_neutron_plugin.ini  ovs_neutron_plugin.ini.bak
wget http://10.21.100.56/src/package/openstack/ovs_neutron_plugin.ini
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini   DATABASE sql_connection "mysql://neutron:${NEUTRON_MYSQL_PASS}@${CTRLIP}/ovs_neutron"
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini   OVS bridge_mappings "physnet1:br-$BR_ETH"
cd ../../
ln -s  /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini plugin.ini
chkconfig neutron-openvswitch-agent on

cd /usr/lib/python2.6/site-packages/nova/compute/
mv -f manager.py manager_bk.py
#海航
wget http://10.200.100.25/manager/manager.py /usr/lib/python2.6/site-packages/nova/compute/manager.py
#鲁谷
wget http://10.21.100.41/manager/manager.py /usr/lib/python2.6/site-packages/nova/compute/manager.py
#总参
wget http://10.99.16.10/manager/manager.py /usr/lib/python2.6/site-packages/nova/compute/manager.py

service  neutron-openvswitch-agent start
service  openstack-nova-compute start