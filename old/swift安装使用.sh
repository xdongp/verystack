#安装软件
yum  -y install openstack-swift-proxy memcached openssh-clients
yum  -y install openstack-swift-account openstack-swift-container openstack-swift-object xfsprogs xinetd rsync openssh-clients
#unset http_proxy

mkdir -p srv/disk
cd /srv/disk && rm * -rf
cd /srv/disk && for i in {b..m}; do  mkdir sd$i ; done && ls
#增加回环设备
echo  "MAKEDEV -v /dev/loop" >> /etc/rc.local 

for index in {b..m}
do 
mkfs.xfs -f -i size=1024 /dev/sd${index}
echo "/dev/sd${index} /srv/disk/sd${index} xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
#mount /srv/disk/sd${index}
done
mount -a

chown -R swift:swift /srv

MYIP=`ifconfig em1|grep 'addr:'|awk  '{print $2}'|awk -F: '{print $2}'` 
export MYIP


cat >/etc/swift/swift.conf <<EOF
[swift-hash]
swift_hash_path_suffix = `od -t x8 -N 8 -A n </dev/random`
EOF
#拷贝/etc/swift/swift.conf 到其他所有机器
# sed -i "/swift_hash_path_suffix/d" /etc/swift/swift.conf  &&  echo "swift_hash_path_suffix =  abafb67bbcff9d45" >> /etc/swift/swift.conf 

#配置rsync
cat > /etc/rsyncd.conf << EOF
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $MYIP

[account]
max connections = 2
path = /srv/disk/
read only = false
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/disk/
read only = false
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/disk/
read only = false
lock file = /var/lock/object.lock
EOF

chkconfig rsync on
chkconfig xinetd on  
service xinetd restart


#配置account服务
cat > /etc/swift/account-server.conf << EOF
[DEFAULT]
devices = /srv/disk/
mount_check = false
bind_ip = 0.0.0.0
bind_port = 6012
workers = 2
log_facility = LOG_LOCAL3

[pipeline:main]
pipeline = recon account-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[app:account-server]
use = egg:swift#account

[account-replicator]

[account-auditor]

[account-reaper]
EOF

#配置container服务
cat > /etc/swift/container-server.conf << EOF
[DEFAULT]
devices = /srv/disk/
mount_check = false
bind_ip = 0.0.0.0
bind_port = 6011
workers = 2
log_facility = LOG_LOCAL2

[pipeline:main]
pipeline = recon container-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[app:container-server]
use = egg:swift#container

[container-replicator]

[container-updater]

[container-auditor]

[container-sync]
EOF

#配置object服务
cat > /etc/swift/object-server.conf << EOF
[DEFAULT]
devices = /srv/disk/
mount_check = false
bind_ip = 0.0.0.0
bind_port = 6010
workers = 2
log_facility = LOG_LOCAL1

[pipeline:main]
pipeline = recon object-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[app:object-server]
use = egg:swift#object

[object-replicator]

[object-updater]

[object-auditor]

[object-expirer]
EOF

#配置日志服务
cat > /etc/rsyslog.d/10-swift.conf << EOF
local1,local2,local3.*,local4.*   /var/log/swift/all.log

local1.*   /var/log/swift/object.log
local2.*   /var/log/swift/container.log
local3.*   /var/log/swift/account.log
local4.*   /var/log/swift/proxy.log
EOF
mkdir -p /var/log/swift
service rsyslog restart


=======================================================================
#安装proxy-server
service memcached restart

#proxy配置
cat > /etc/swift/proxy-server.conf << EOF
[DEFAULT]
bind_port = 8080
bind_ip = $MYIP
user = swift
log_level = DEBUG
log_facility = LOG_LOCAL4

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
memcache_servers = 127.0.0.1:11211
EOF

cd /etc/swift
swift-ring-builder account.builder create 18 3 1
swift-ring-builder container.builder create 18 3 1
swift-ring-builder object.builder create 18 3 1

cd /etc/swift
for i in `seq 1 4`
do
for index in {b..m}
do
swift-ring-builder account.builder add r${i}z${i}-119.188.116.7${i}:6012/sd${index} 100
swift-ring-builder container.builder add r${i}z${i}-119.188.116.7${i}:6011/sd${index} 100
swift-ring-builder object.builder add r${i}z${i}-119.188.116.7${i}:6010/sd${index} 100
done
done

平衡环
cd /etc/swift
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

scp /etc/swift/*.gz allnode:/etc/swift/


# 代理节点
swift-init proxy start

# 存储节点
swift-init all start

测试
swift -A http://$MYIP:8080/auth/v1.0 -U admin:admin -K admin stat

#监控
监控磁盘（传统方法）
cat > /etc/swift/dispersion.conf << EOF
[dispersion]
auth_url = http://$MYIP:8080/auth/v1.0
auth_user = test:tester
auth_key = testing
endpoint_type = internalURL
EOF
运行
swift-dispersion-populate（一台执行就可以）
查看（读写情况）
swift-dispersion-report
swift-dispersion-report --container-only
swift-dispersion-report --object-only
swift-dispersion-report -j

资源监控：
curl -i http://localhost:6030/recon/async
swift-recon --all


=======================================================================
#卸载
yum remove  openstack-swift*
rm -rf /etc/swift
rm -rf /var/log/swift/*
rm -rf /var/lib/swift/*
for index in {b..m}
do 
umount /srv/disk/sd${index}
done
rm  -rf /srv/disk/* 


=======================================================================
##客户端安装：
```java
cd /etc/yum.repos.d/
wget http://10.21.100.40/script/repo/rdo-release.repo
yum install -y http://rdo.fedorapeople.org/rdo-release.rpm
yum install -y python-swiftclient
```
 修改/usr/bin/swift 1024行下3行内容如下(2.0.2版本)[修改后能传空文件]
 
 (2.0.2版本)[python-swiftclient-2.0.2-1.el6.noarch]
```java
1025                     if getsize(path) == 0:
1026                         conn.put_object(container, obj, '',content_length=0,
1027                                         headers=put_headers)
1028                     else:
1029                         conn.put_object(
1030                             container, obj, open(path, 'rb'),
1031                             content_length=getsize(path), headers=put_headers)
```
 (1.8.0版本)[python-swiftclient-1.8.0-1.el6.noarch]
```java
1097                     if getsize(path) == 0:
1098                         conn.put_object(container, obj, '',content_length=0,
1099                                         headers=put_headers)
1100                     else:
1101                         conn.put_object(
1102                                        container, obj, open(path, 'rb'),
1103                                        content_length=getsize(path), headers=put_headers)
```

##使用方式:

 列出所有容器
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin list
```
 *注： -U  user:pass  -K 角色  -A url(授权URL)*
 列出容器下文件
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin list box001
```
 列出文件（指定前缀）
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin list box001 --prefix tmp
```
 新建容器:
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin post box002
```
 上传文件:
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin upload box002  myfile
```
 上传目录:
```java 
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin upload box002  mydir/
```
 上传目录中更新过的文件：
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin upload box002  mydir/ --changed
```
 下载文件:
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin download box002  myfile 
```
 下载目录
```java
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin download box002  --prefix mydir 
```
 删除文件:
```java 
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin delete box002  myfile
```
 删除容器:
```java 
swift -A http://119.188.116.70:8080/auth/v1.0 -U admin:admin -K admin delete box002
```
 设置acl
```java
1, 设置delay_auth_decision：vim /etc/swift/proxy-server.conf      
delay_auth_decision = true
2，设置keystone验证 [vim /etc/swift/proxy-server.conf]
[pipeline:main]
pipeline = healthcheck proxy-logging cache authtoken keystone proxy-logging account-quotas container-quotas proxy-server
3，设置acl
[root@ssdevop-con1 tmp(keystone_admin)]$ swift stat test            
         Account: AUTH_f26d9b66a67549788f5376c10725d49b
       Container: test
         Objects: 2
           Bytes: 13305531
        Read ACL: .r:*
       Write ACL:
         Sync To:
        Sync Key:
   Accept-Ranges: bytes
      X-Trans-Id: tx618d36d966f2467d9c2e8-0057909874
X-Storage-Policy: Policy-0
      Connection: keep-alive
     X-Timestamp: 1469081151.03361
    Content-Type: text/plain; charset=utf-8
4， 下载：
wget http://10.125.225.16:8080/v1/AUTH_f26d9b66a67549788f5376c10725d49b/test/ins.tgz
```

