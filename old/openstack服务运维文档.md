# OpenStack服务运维文档


日期|修订者|说明
-|:---:|:---:
2015-01-23|潘晓东|运维文档第一版

### 说明
---
此文档为OpenStack服务运维文档

### 服务介绍
OpenStack是一套云服务软件，包括技术服务，存储服务，网络服务等，目前小米OpenStack已经部署了4个机房：LG,HH,C3,ZC。服务包括3个模块：控制节点，技术节点，存储节点。

机房|控制节点|计算节点|备份节点|存储节点|版本|
-|:---:|:---:|
LG|lg-pt-controlnode02.bj| lg-pt-computenode01.bj  <br> lg-pt-computenode02.bj  <br> lg-pt-computenode03.bj  <br> lg-pt-computenode04.bj  <br> lg-pt-computenode05.bj  <br> lg-pt-computenode06.bj  <br> lg-pt-computenode07.bj  <br> lg-pt-computenode08.bj  <br> lg-pt-computenode10.bj  <br> lg-pt-computenode11.bj  <br> lg-pt-computenode12.bj  <br> lg-pt-computenode13.bj  <br> lg-pt-computenode14.bj  <br> lg-pt-computenode15.bj  <br> lg-pt-computenode16.bj  <br> lg-pt-computenode17.bj  <br> lg-pt-computenode18.bj  <br> lg-pt-computenode19.bj  <br> lg-pt-computenode20.bj  <br> lg-pt-computenode21.bj  <br> lg-pt-computenode22.bj  <br>|lg-pt-controlnode01.bj||havana
HH|hh-pt-control01.bj| hh-pt-compute01.bj  <br> hh-pt-compute02.bj  <br> hh-pt-compute03.bj  <br> hh-pt-compute04.bj  <br> hh-pt-compute05.bj  <br> hh-pt-compute06.bj  <br> hh-pt-compute07.bj  <br> hh-pt-compute08.bj  <br> hh-pt-compute09.bj  <br> hh-pt-compute10.bj  <br> hh-pt-compute11.bj  <br> hh-pt-compute12.bj  <br> hh-pt-compute13.bj  <br>|hh-pt-control02.bj||havana|
C3|c3-pt-control01.bj| c3-pt-compute01.bj  <br> c3-pt-compute02.bj  <br> c3-pt-compute03.bj  <br> c3-pt-compute04.bj  <br> c3-pt-compute05.bj  <br> c3-pt-compute06.bj  <br> c3-pt-compute07.bj  <br> c3-pt-compute08.bj  <br> c3-pt-compute09.bj  <br> c3-pt-compute10.bj  <br> c3-pt-compute11.bj  <br> c3-pt-compute12.bj  <br> c3-pt-compute13.bj  <br> c3-pt-compute14.bj  <br> c3-pt-compute15.bj  <br> c3-pt-compute16.bj  <br> c3-pt-compute17.bj  <br>|c3-pt-control02.bj|c3-pt-storage01.bj <br>c3-pt-storage02.bj <br>c3-pt-storage03.bj <br>c3-pt-storage04.bj <br>c3-pt-storage05.bj <br>c3-pt-storage06.bj <br>c3-pt-storage07.bj <br>c3-pt-storage08.bj <br>c3-pt-storage09.bj <br>c3-pt-storage10.bj <br>||icehouse|
ZC|zc-pt-control01.bj|zc-pt-compute01.b<br> zc-pt-compute02.b<br> zc-pt-compute03.b<br> zc-pt-compute04.b<br> zc-pt-compute05.b<br> zc-pt-compute06.b<br> zc-pt-compute07.b<br> zc-pt-compute08.b<br> zc-pt-compute09.b<br> zc-pt-compute10.b<br> zc-pt-compute11.b<br> zc-pt-compute12.b<br> zc-pt-compute13.b<br> zc-pt-compute14.b<br> zc-pt-compute15.b<br> zc-pt-compute16.b<br> zc-pt-compute17.b<br> zc-pt-compute18.b<br> zc-pt-compute19.b<br> zc-pt-compute20.b<br> zc-pt-compute21.b<br> zc-pt-compute22.b<br> |zc-pt-control02.bj||havana|

**控制节点**：控制集成中所有计算节点，运行的服务有：
			
	keystone:Openstack认证服务
	nova-Api:Nova服务API
	nova-Schedule:Nova调度服务，负责虚拟机的分配和调度
	nova-novnc: vnc转发服务
	glance:OpenStack镜像服务
	neutron-server:OpenStack网络服务，服务OpenStack网络分配管理,安全组管理
	qpid/rabbitmq-server: 队列服务，所以服务间通过队列进行交互
	mysql: 数据库
	apache: web服务，负责dashboard展现
	
**计算节点**：控制集成中所有计算节点，运行的服务有：
	
	nova-compute: 计算服务，负责虚拟机的创建，重启，关闭等
	neutron-openvswitch-agent: 网络服务，负责虚拟机的网络和安全组
	
**存储节点**：目前有ceph担任，运行的服务有：
	
	osd: ceph存储数据的服务
	mon: ceph监控数据一致性和同步的服务
	mds: ceph元数据管理，为cephfs做元数据管理
	samba: samba作为用户管理
	
###OpenStack使用
	1，虚拟机创建
		a, xman2中主机管理->虚拟机分配可以创建
		b, 各个集群dashboard能够创建
		注意：LG机器分为LG和LG6，网段需要制定对，LG6网段都带有LG6的标示
	     初始化自动默认为1，启动完成自动初始化
	     产品线正常的虚拟机自动会同步产品线到XBOX
	     虚拟机不可以无限分配，注意各个集群的负载和余量
	     
	2，虚拟机控制台
		a, 通过xman可以获取控制台
		b, 在控制节点上运行：
		    nova get-vnc-console hostname novnc 
		
	3，虚拟机查询
		xman搜索中可以查询虚拟机
		各集群控制节点中eova list或者nova-manage vm list可以查询
		
	4, 虚拟机迁移
		在dashboard上操作，虚拟机的磁盘必须是共享存储，因此只有c3使用共享存储的机器能够迁移
	
	5, 快照
		本地存储做快照时，虚拟机必须关闭
		ceph共享存储可以在不关机情况下做实时快照
		太大的磁盘(>100G)尽量避免做快照，因此快照是使用临时磁盘，会把系统跟分区挤满，同时会上传glance,磁盘太大速度慢
	
	6, 扩充容量
		只能变更类型
		磁盘只能增大，不能缩小
		扩充容量过程中，虚拟机需停机
		扩充容量实际是停机-创建-拷贝数据的过程，时间较长
		

###常见问题处理：
	1，XMAN虚拟机创建失败
		a, 指定账户是否在OpenStack中存在，如果存在，按照步骤b排查
		b, 登录对应的控制节点 
			nova list --name  hostname --all_tenants
		   查看状态，如果没有获取到网络
		    service qpidd restart 【lg,hh,zc】
		    service rabbitmq-server restart 【c3】
		    service neutron-server restart
		c, 再次启动还出错，需查看 /var/log/nova/scheduler.log
	
	2， 虚拟机无法联网
		a，ping网关不通，检查安全组是否开发icmp协议等
		b，安全组正确后仍然不能联网，在虚拟机中ping着网关，在虚拟机对应的计算节点上装包
			 tcpdump  -neti em3 host hostname
		   如果vlan id不对，说明没有获取到正确的vlanid号，是neutron-server挂掉了，操作如下：
		     step1. ovs-ofctl  dump-flows br-em3|br-em2
		     		查看对应的规则，如果没有正确转换规则，转step2.
			 step2. ssh control node  
			 		service qpidd restart 【lg,hh,zc】
		     		service rabbitmq-server restart 【c3】
		     step3. ssh compute node
		     		service openstack-openvswitch-agent restart 【会影响同节点所有虚拟机，尽量不要操作】
		   如果vlan号正确，说明数据包已经到了网卡，和网络组确认trunk是否开启
		   
	3， 删除虚拟机失败，出现一直等待
		a,  nova reset-state uuid --active
		d,  nova delete uuid
		
	4， 重启失败，一直等待
	 	a,  nova reset-state uuid --active
	 	b,  nova reboot --hard uuid
	 
	5， 获取所以虚拟机
		nova  list  --all-tenants
	
	6， 根据ip查主机
		nova list --ip 10.108.96.167 --all-tenants
		
	7， 根据主机名查主机
	 	nova list --name c3-pt-dev01.bj --all-tenants  
	
	8， 迁移失败，状态error
		虚拟机仍然存活，不要再进行第二次操作，重置状态即可
		 nova reset-state uuid --active
	
	9， 调整大小失败，状态error
		虚拟机可能不存活，但是虚拟机没有被删除，重置状态重启机器即可
		a,  nova reset-state uuid --active
	 	b,  nova reboot --hard uuid
	
	10, LG机房集群分配虚拟机不能上网
		LG机房分为两层，网络相互不能通用。分配在LG6的机器，必须使用LG6的网段
		 
	11. virsh常用命令（nova搞不定的时候就可以用virsh）
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
	
###预案：
	1，控制节点挂掉，无法启动。
		影响：短时间(1小时以内)停机都虚拟机的运行没有影响，但是不要重启所有计算节点上的neutron-openvswitch-agent，否则虚拟机上不了网。
		恢复操作：
			a. 尽快找机器补上,IP要和原来的control不同(如果Ip相同的话，安装过程中可以导致neutorn-openswith-agent读取空白数据)
			b. 安装keystone, nova, glance, neutron-server。
			c. 导入所有配置（备份在compute01:/home/work/backup和ceph）
			d. 导入数据库 （备份在compute01:/home/work/backup）
			e. 确认服务正确启动，修改IP和主机名和原理control一样
			f. 检查虚拟机运行情况
			
		
	2， 计算节点故障：
		影响： 影响本节点运行的虚拟机
			a， 磁盘故障：若磁盘坏掉，无法恢复，则所以机器无法恢复（需要在申请是告知使用方），因此需要密切监视磁盘raid状态，重要数据可以是使用ceph。
			b， 其他短时故障：机器修好恢复就行
			c， 其他长时间故障：可以其他将磁盘镜像拷贝到其他机器，但是由于磁盘较大，迁移时间较长。
	
	3， Ceph节点故障：
		影响：相应ceph读写性能
		操作：无需操作，观察ceph -s状况就行。
		
		
			
		
			 
		
	
			

