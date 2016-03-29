### 服务端安装：

```
yum -y install glusterfs glusterfs-server
chkconfig glusterd on
service glusterd start
```

### 服务端配置：
将4个存储节点组成一集群，只需要在任意节点执行就OK。

```
[root@db1 ~]# gluster peer probe 172.28.26.102
Probe successful
[root@db1 ~]# gluster peer probe 172.28.26.188
Probe successful
[root@db1 ~]# gluster peer probe 172.28.26.189
Probe successful
```

### 查看集群的节点信息：
```
[root@db1 ~]# gluster peer status
Number of Peers: 3
Hostname: 172.28.26.102
Uuid: b9437089-b2a1-4848-af2a-395f702adce8
State: Peer in Cluster (Connected)
Hostname: 172.28.26.188
Uuid: ce51e66f-7509-4995-9531-4c1a7dbc2893
State: Peer in Cluster (Connected)
Hostname: 172.28.26.189
Uuid: 66d7fd67-e667-4f9b-a456-4f37bcecab29
State: Peer in Cluster (Connected)
```
### 创建卷
以/data/gluster为共享目录，创建名为img的卷,副本数为2：

```
mkdir /data/gluster
[root@db1 ~]#  gluster volume create img replica 2 172.28.26.101:/data/gluster 172.28.26.102:/data/gluster 172.28.26.188:/data/gluster 172.28.26.189:/data/gluster
Creation of volume img has been successful. Please start the volume to access data.
```
### 启动卷：
```
[root@db1 ~]# gluster volume start img
Starting volume img has been successful
```

### 查看卷状态:
```
[root@db1 ~]# gluster volume info
Volume Name: img
Type: Distributed-Replicate
Status: Started
Number of Bricks: 2 x 2 = 4
Transport-type: tcp
Bricks:
Brick1: 172.28.26.101:/data/gluster
Brick2: 172.28.26.102:/data/gluster
Brick3: 172.28.26.188:/data/gluster
Brick4: 172.28.26.189:/data/gluster
```
### 客户端安装配置：
安装：

```
yum -y installglusterfs glusterfs-fuse
```
挂载：

```
mount -t glusterfs 172.28.26.102:/img /mnt/ （挂载任意一个节点即可）
mount -t nfs -o mountproto=tcp,vers=3 172.28.26.102:/img /log/mnt/ （使用NFS挂载，注意远端的rpcbind服务必须开启）
echo "172.28.26.102:/img /mnt/ glusterfs defaults,_netdev 0 0" >> /etc/fstab (开机自动挂载)
```