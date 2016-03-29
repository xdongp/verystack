### Openstack常用命令
-----

#### 查看虚拟化支持
egrep "(vmx|svm)" –color=always /proc/cpuinfo  

#### 镜像添加
glance add name="cirros" is_public=true container_format=ovf disk_format=raw< ./cirros-0.3.0-x86_64-disk.img

#### Qemu镜像转换

#### 虚拟机迁移
nova list
nova show vm
nova host-list
nova live-migration test-991ca991-a510-493a-8117-4962df336b02 lg-pt-computenode01.bj

#### Openstack创建网络
内网
tenant=$(keystone tenant-list|awk '/admin/ {print $2}')
vlanid=200
net=192.168.200
neutron net-create --tenant-id $tenant vnet$vlanid \
     --provider:network_type vlan \
    --provider:physical_network physnet1 \
    --provider:segmentation_id $vlanid 
neutron subnet-create --tenant-id $tenant --name vsubnet$vlanid  vnet$vlanid  $net.0/24   --gateway $net.254

neutron subnet-create --tenant-id $tenant --name vsubnet$vlanid  vnet$vlanid  10.21.254.0/24   --disable-dhcp  --gateway 10.21.254.254  --allocation-pool start=10.21.254.200,end=10.21.254.253
外网
neutron net-create net_external --router:external=True --shared
neutron subnet-create net_external --gateway 10.102.20.254 10.102.20.0/24 --enable_dhcp=False  --allocation_pool start=10.102.20.50,end=10.102.20.253 


#### Nova命令：
删除僵尸主机
nova reset-state c6bbbf26-b40a-47e7-8d5c-eb17bf65c485  
nova delete c6bbbf26-b40a-47e7-8d5c-eb17bf65c485

带磁盘迁移
nova live-migration  --block-migrate myvm computenode02（迁移以后，获取console需要重启）

虚拟机重启
nova reboot --hard centos-sa010 （硬重启）
nova reboot centos-sa010 （软重启）

停止服务
nova-manage service disable wcc-pt-control01.bj  nova-consoleauth

列出主机
nova host-list

列出服务
nova service-list

启动主机
nova boot --image c9149bfe-9a80-4ddc-b97d-0bf7e4a57aee --flavor d99cc0c6-9b56-43c7-ba62-1813a8efc796 --availability-zone nova:c3-pt-compute08.bj  --nic net-id=531cc5b8-a37a-4ac9-b574-421bc3fedf74 c3-pt-ovs-test02.bj

网卡热插拔
quantum net-list
nova list
nova interface-attach --net-id e79f5d1a-289e-44b6-8070-943535cbbeae 54ca2943-46e7-4e2e-b470-a015f23797c0 # <-- instance id
nova interface-detach  54ca2943-46e7-4e2e-b470-a015f23797c0 d4911c36-2c8d-4dd3-a128-2d7e411ce877 # <--port-uuid

### virsh相关用法
列出主机
virsh list
virsh list --uuid (以uuid方式显示)

关闭主机
virsh shutdown dominName

重启主机
virsh reboot domaiName

强制关闭主机
virsh destroy domainName （这个命令在虚拟机无法重启或者关闭的时候使用，强制关闭主机，但是不删除镜像，千万注意不要和nova destroy混淆）

获取主机信息
virsh dominfo dominName

获取节点信息
virsh nodeinfo

### 虚拟机调整大小（目前好像不行）
nova show lg-game-phpsession01.bj
nova flavor-list
nova resize 20978f29-7a9d-4ed6-9153-164d5ebcdf8f（vm-id）  53af27c0-7a3d-477d-b8c8-8f768f2294c5(flavor-id) --poll
nova resize-confirm 20978f29-7a9d-4ed6-9153-164d5ebcdf8f(vm-id)


### OVS相关命令
查看ovs规则
ovs-ofctl dump-flows br-int
tcpdump -tnei eth2