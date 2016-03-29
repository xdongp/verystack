export NODES="c3-pt-storage01.bj c3-pt-storage02.bj c3-pt-storage03.bj c3-pt-storage04.bj c3-pt-storage05.bj c3-pt-storage06.bj c3-pt-storage07.bj c3-pt-storage08.bj c3-pt-storage09.bj c3-pt-storage10.bj"
export MONS="c3-pt-storage01.bj c3-pt-storage05.bj c3-pt-storage10.bj"
export MDS="c3-pt-storage01.bj c3-pt-storage06.bj"
export DISKS="b c d e f g h i j k l m"

#安装源:
rpm -ivh http://10.21.100.40/ceph/el6/noarch/ceph-deploy-1.5.18-0.xiaomi.noarch.rpm 


#删除已有数据
ceph-deploy  purge $NODES
ceph-deploy  purgedata  $NODES
ceph-deploy forgetkeys

#创建一个集群
mkdir miceph
cd miceph
ceph-deploy new $MONS
echo "osd pool default size = 3"  >> ./ceph.conf
echo  "osd pool default min size = 1" >> ./ceph.conf
echo  "osd pool default pg num    = 120" >> ./ceph.conf
echo  "osd pool default pgp num   = 120" >> ./ceph.conf


#安装软件
ceph-deploy install $NODES

#安装mon节点
ceph-deploy mon create-initial
ceph-deploy mon create $MONS
ceph-deploy gatherkeys $MONS



#添加OSD
for  h in $NODES
do 
	for d in $DISKS
	do
		ceph-deploy osd prepare ${h}:/dev/sd${d}
	done 	
done

for  h in $NODES
do 
	for d in $DISKS
	do
		ceph-deploy osd activate ${h}:/dev/sd${d}1
	done 	
done

#分发配置
ceph-deploy  --overwrite-conf  admin $NODES
chmod +r /etc/ceph/ceph.client.admin.keyring
ceph health

#添加MetaServer
ceph-deploy mds create $MDS
ceph quorum_status --format json-pretty


#增加MonServer
ceph-deploy mon create  c3-pt-storage05 c3-pt-storage10


#创建pool
ceph osd pool create vms 128


#在计算节点编译支持rbd的qemu(可选)
yum install ceph-devel
yum install lib-fdt-devel
rpm -e qemu-kvm --nodeps
rpm -e qemu-img --nodeps
./configure --enable-rbd   --disable-gtk  
make -j8
make install

#ceph行测试命令(可选)
fio --direct=1 --rw=rw --bs=1m --size=5g  --name=test-rw --runtime=60
fio --direct=1 --rw=randrw --bs=16k --size=2g --numjobs=16 --group_reporting --name=test-rw  --runtime=60 -iodepth=64
fio -ioengine=libaio -bs=64k -direct=1 -thread -rw=randwrite -size=1000G --name="test-rw" --iodepth=64 --runtime=60
fio -ioengine=libaio -bs=64k -direct=1 -thread -rw=randwrite -size=4G --name="test-rw" --iodepth=64 --runtime=60
fio -ioengine=libaio -bs=4k -direct=1 -thread -rw=randwrite -size=1000G --name="test-rw" --iodepth=64 --runtime=60

