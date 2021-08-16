# Ceph分布式文件存储

## 1.Ceph存储简介

Ceph 独一无二地在一个统一的系统中同时提供了**对象、块、和文件存储功能**。

## 2.Ceph三种存储类型特性

### CEPH 对象存储

- REST 风格的接口
- 与 S3 和 Swift 兼容的 API
- S3 风格的子域
- 统一的 S3/Swift 命名空间
- 用户管理
- 利用率跟踪
- 条带化对象
- 云解决方案集成
- 多站点部署
- 灾难恢复

### CEPH 块设备

- 瘦接口支持
- 映像尺寸最大 16EB
- 条带化可定制
- 内存缓存
- 快照
- 写时复制克隆
- 支持内核级驱动
- 支持 KVM 和 libvirt
- 可作为云解决方案的后端
- 增量备份

### CEPH 文件系统

- 与 POSIX 兼容的语义
- 元数据独立于数据
- 动态重均衡
- 子目录快照
- 可配置的条带化
- 有内核驱动支持
- 有用户空间驱动支持
- 可作为 NFS/CIFS 部署
- 可用于 Hadoop （取代 HDFS ）

## 3.Ceph组件

不管你是想为[*云平台*](http://docs.ceph.org.cn/glossary/#term-48)提供[*Ceph 对象存储*](http://docs.ceph.org.cn/glossary/#term-30)和/或 [*Ceph 块设备*](http://docs.ceph.org.cn/glossary/#term-38)，还是想部署一个 [*Ceph 文件系统*](http://docs.ceph.org.cn/glossary/#term-45)或者把 Ceph 作为他用，所有 [*Ceph 存储集群*](http://docs.ceph.org.cn/glossary/#term-21)的部署都始于部署一个个 [*Ceph 节点*](http://docs.ceph.org.cn/glossary/#term-13)、网络和 Ceph 存储集群。 Ceph 存储集群至少需要一个 Ceph Monitor 和两个 OSD 守护进程。而运行 Ceph 文件系统客户端时，则必须要有元数据服务器（ Metadata Server ）。

- **Ceph OSDs**: [*Ceph OSD 守护进程*](http://docs.ceph.org.cn/glossary/#term-56)（ Ceph OSD ）的功能是存储数据，处理数据的复制、恢复、回填、再均衡，并通过检查其他OSD 守护进程的心跳来向 Ceph Monitors 提供一些监控信息。当 Ceph 存储集群设定为有2个副本时，至少需要2个 OSD 守护进程，集群才能达到 `active+clean` 状态（ Ceph 默认有3个副本，但你可以调整副本数）。
- **Monitors**: [*Ceph Monitor*](http://docs.ceph.org.cn/glossary/#term-ceph-monitor)维护着展示集群状态的各种图表，包括监视器图、 OSD 图、归置组（ PG ）图、和 CRUSH 图。 Ceph 保存着发生在Monitors 、 OSD 和 PG上的每一次状态变更的历史信息（称为 epoch ）。
- **MDSs**: [*Ceph 元数据服务器*](http://docs.ceph.org.cn/glossary/#term-63)（ MDS ）为 [*Ceph 文件系统*](http://docs.ceph.org.cn/glossary/#term-45)存储元数据（也就是说，Ceph 块设备和 Ceph 对象存储不使用MDS ）。元数据服务器使得 POSIX 文件系统的用户们，可以在不对 Ceph 存储集群造成负担的前提下，执行诸如 `ls`、`find` 等基本命令。

Ceph 把客户端数据保存为存储池内的对象。通过使用 CRUSH 算法， Ceph 可以计算出哪个归置组（PG）应该持有指定的对象(Object)，然后进一步计算出哪个 OSD 守护进程持有该归置组。 CRUSH 算法使得 Ceph 存储集群能够动态地伸缩、再均衡和修复。

## 4.Ceph文件写入流程

- 文件首选被切割成多个object，例如：100M文件会被切成25个object，每个4M(默认4M)，切割之后，每个object都会有一个oid(object id)，oid(object id)需要存储到pg中；
- pg可以理解为装载object的文件夹，oid(object id)进行 hash(哈希) 和 mask(掩码) 的运算，最终得到pg的id；
- pg上有多个object，之后经过crush算法，把pg进行运算，把它分配到集群中对应的osd节点上

![image.png](https://i.loli.net/2021/08/15/1qNmgwEpAve648L.png)

## 5.Ceph集群安装

### 5.1集群规划和磁盘

每个机器添加额外两块50G的磁盘，作为osd数据盘，IP和角色规划如下

| 主机名      | IP                                  | 角色          |
| ----------- | ----------------------------------- | ------------- |
| ceph-node01 | eth0:192.168.2.7   eth1:192.168.3.2 | mon、mgr、osd |
| ceph-node02 | eth0:192.168.2.8   eth1:192.168.3.3 | mon、osd      |
| ceph-node03 | eth0:192.168.2.9   eth1:192.168.3.4 | mon、osd      |

### 5.2 配置Ceph yum源

```
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-nautilus/el7/noarch
enabled=1
gpgcheck=0

[ceph-x86_64]
name=Ceph x86_64 packages
baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-nautilus/el7/x86_64
enabled=1
gpgcheck=0
```

### 5.3 Mon节点安装ceph-deploy

```bash
yum install -y ceph-deploy
```

### 5.4 所有节点安装ceph相关软件包

```bash
yum install -y ceph ceph-mon ceph-mgr ceph-radosgw ceph-mds
```

### 5.5 部署mon节点

**只在ceph-node01节点操作**

创建目录

```
mkdir ceph-deploy
cd ceph-deploy
```

生成配置文件

--public-network用于外部通信，--cluster-network用于内部数据交换

```bash
ceph-deploy new --public-network 192.168.2.0/24 --cluster-network 192.168.3.0/24 ceph-node01
```

修改ceph.conf，额外添加3行

```
mon_clock_drift_allowed = 2
mon_clock_drift_warn_backoff = 30
mon_allow_pool_delete = true
```

生成秘钥

```bash
ceph-deploy mon create-initial
```

推送至其他节点

```bash
ceph-deploy admin ceph-node01 ceph-node02 ceph-node03
```

创建mgr

```bash
ceph-deploy mgr create ceph-node01
```

### 5.6部署osd节点

**只在ceph-node01节点操作**

```bash
ceph-deploy osd create ceph-node01 --data /dev/sdb
ceph-deploy osd create ceph-node02 --data /dev/sdb
ceph-deploy osd create ceph-node03 --data /dev/sdb
```

### 5.7 查看集群状态

```bash
[root@ceph-node01 ~]# ceph -s
  cluster:
    id:     3b690447-512d-4700-a245-f729e1f2caed
    health: HEALTH_OK
 
  services:
    mon: 1 daemons, quorum ceph-node01 (age 63s)
    mgr: ceph-node01(active, since 48s)
    osd: 3 osds: 3 up (since 60s), 3 in (since 19m)
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 147 GiB / 150 GiB avail
    pgs:
```

### 5.8 扩容mon

**只在ceph-node01节点操作**

```bash
ceph-deploy mon add ceph-node02
ceph-deploy mon add ceph-node03
```

查看仲裁状态

```bash
ceph quorum_status --format json-pretty|jq
```

或者

```bash
[root@ceph-node01 ceph-deploy]# ceph mon stat
e3: 3 mons at {ceph-node01=[v2:192.168.2.7:3300/0,v1:192.168.2.7:6789/0],ceph-node02=[v2:192.168.2.8:3300/0,v1:192.168.2.8:6789/0],ceph-node03=[v2:192.168.2.9:3300/0,v1:192.168.2.9:6789/0]}, election epoch 18, leader 0 ceph-node01, quorum 0,1,2 ceph-node01,ceph-node02,ceph-node03
```

查看详细信息

```bash
[root@ceph-node01 ceph-deploy]# ceph mon dump
epoch 3
fsid 3b690447-512d-4700-a245-f729e1f2caed
last_changed 2021-08-15 22:03:15.760985
created 2021-08-16 05:33:52.631504
min_mon_release 14 (nautilus)
0: [v2:192.168.2.7:3300/0,v1:192.168.2.7:6789/0] mon.ceph-node01
1: [v2:192.168.2.8:3300/0,v1:192.168.2.8:6789/0] mon.ceph-node02
2: [v2:192.168.2.9:3300/0,v1:192.168.2.9:6789/0] mon.ceph-node03
dumped monmap epoch 3
```

### 5.9 扩容mgr

**只在ceph-node01节点操作**

```bash
ceph-deploy mgr create ceph-node02 ceph-node03
```

查看集群状态

```bash
[root@ceph-node01 ceph-deploy]# ceph -s
  cluster:
    id:     3b690447-512d-4700-a245-f729e1f2caed
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 5m)
    mgr: ceph-node01(active, since 10m), standbys: ceph-node03, ceph-node02
    osd: 3 osds: 3 up (since 10m), 3 in (since 38m)
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 147 GiB / 150 GiB avail
    pgs:     
 
```

## 6.RBD块存储

### 6.1 创建资源池pool

```bash
ceph osd pool create ceph-rbd-demo 64 64 # 64个PG，64个PGP，默认就会有3个副本
```

查看创建的资源池

```bash
[root@ceph-node01 ceph-deploy]# ceph osd lspools
1 ceph-rbd-demo
```

查看资源池信息

```bash
# 查看pg数量
[root@ceph-node01 ~]# ceph osd pool get ceph-rbd-demo pg_num
pg_num: 64


# 查看pgp数量
[root@ceph-node01 ~]# ceph osd pool get ceph-rbd-demo pgp_num
pgp_num: 64


# 查看副本数
[root@ceph-node01 ~]# ceph osd pool get ceph-rbd-demo size
size: 3
```

调整副本数

```bash
ceph osd pool set ceph-rbd-demo size 2
```

调整pg数

```bash
ceph osd pool set ceph-rbd-demo pg_num 128
```

调整pgp数

```bash
ceph osd pool set ceph-rbd-demo pgp_num 128
```

### 6.2 创建块设备和映射

创建块设备

```bash
rbd create -p ceph-rbd-demo --image rbd-demo.img --size 10G # -p指定存储池
```

或者

```bash
rbd create ceph-rbd-demo/rbd-demo.img --size 10G
```

查看刚刚创建的rbd块文件列表

```bash
[root@ceph-node01 ~]# rbd -p ceph-rbd-demo ls
rbd-demo.img
```

查看具体rbd块设备信息

```bash
[root@ceph-node01 ~]# rbd -p ceph-rbd-demo info rbd-demo.img
rbd image 'rbd-demo.img':
	size 10 GiB in 2560 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: fab04251724b
	block_name_prefix: rbd_data.fab04251724b
	format: 2
	features: layering, exclusive-lock, object-map, fast-diff, deep-flatten
	op_features: 
	flags: 
	create_timestamp: Sun Aug 15 15:02:45 2021
	access_timestamp: Sun Aug 15 15:02:45 2021
	modify_timestamp: Sun Aug 15 15:02:45 2021
```

### 6.3 本地挂载测试

由于CentOS7内核版本较低，默认的feature好多不支持，需要提前禁用掉

```bash
rbd feature disable ceph-rbd-demo/rbd-demo.img  deep-flatten
rbd feature disable ceph-rbd-demo/rbd-demo.img  fast-diff
rbd feature disable ceph-rbd-demo/rbd-demo.img  object-map
rbd feature disable ceph-rbd-demo/rbd-demo.img  exclusive-lock
```

映射rbd

```bash
[root@ceph-node01 ~]# rbd map ceph-rbd-demo/rbd-demo.img 
/dev/rbd0
```

查看块设备

```bash
[root@ceph-node01 ~]# rbd device list 
id pool          namespace image        snap device    
0  ceph-rbd-demo           rbd-demo.img -    /dev/rbd0
```

格式化并挂载

```bash
mkfs.xfs /dev/rbd0
mount /dev/rbd0 /mnt/
```

### 6.3 rbd数据写入流程

查看当前存储池的objects

```bash
rados -p ceph-rbd-demo ls|grep rbd_data.fab04251724b
```

查看单个object信息

```bash
[root@ceph-node01 ~]# rados -p ceph-rbd-demo stat rbd_data.fab04251724b.00000000000000fe
ceph-rbd-demo/rbd_data.fab04251724b.00000000000000fe mtime 2021-08-15 23:18:05.000000, size 4194304
```

查看某个object最终落在那个pg和osd上

```bash
[root@ceph-node01 ~]# ceph osd map ceph-rbd-demo rbd_data.fab04251724b.00000000000000fe
osdmap e45 pool 'ceph-rbd-demo' (2) object 'rbd_data.fab04251724b.00000000000000fe' -> pg 2.ec5371ff (2.3f) -> up ([1,0,2], p1) acting ([1,0,2], p1)
```

### 6.4 rbd块存储扩容

扩容rbd

```bash
rbd resize ceph-rbd-demo/rbd-demo.img --size 20G
```

查看信息

```bash
[root@ceph-node01 ~]# rbd info ceph-rbd-demo/rbd-demo.img
rbd image 'rbd-demo.img':
	size 20 GiB in 5120 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: fab04251724b
	block_name_prefix: rbd_data.fab04251724b
	format: 2
	features: layering
	op_features: 
	flags: 
	create_timestamp: Sun Aug 15 15:02:45 2021
	access_timestamp: Sun Aug 15 15:02:45 2021
	modify_timestamp: Sun Aug 15 15:02:45 2021
```

客户端扩容文件系统

**注意**：如果客户端格式化格式为ext4，需要用`resize2fs`，这里格式化的为xfs，所以用`xfs_growfs`

```bash
xfs_growfs /dev/rbd0
```

### 6.5 ceph告警排查

查看ceph集群信息，可以看到集群为HEALTH_WARN状态

```bash
[root@ceph-node01 ~]# ceph -s
  cluster:
    id:     3b690447-512d-4700-a245-f729e1f2caed
    health: HEALTH_WARN
            application not enabled on 1 pool(s)
            1 daemons have recently crashed
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 34m)
    mgr: ceph-node02(active, since 8h), standbys: ceph-node03, ceph-node01
    osd: 3 osds: 3 up (since 36m), 3 in (since 119m)
 
  data:
    pools:   1 pools, 64 pgs
    objects: 296 objects, 1.0 GiB
    usage:   6.1 GiB used, 144 GiB / 150 GiB avail
    pgs:     64 active+clean
```

查看健康状况详情，可以看到ceph-rbd-demo资源池未启用application，是因为在创建该资源池未进行init操作，安提示需要enable application操作

```bash
[root@ceph-node01 ~]# ceph health detail 
HEALTH_WARN application not enabled on 1 pool(s); 1 daemons have recently crashed
POOL_APP_NOT_ENABLED application not enabled on 1 pool(s)
    application not enabled on pool 'ceph-rbd-demo'
    use 'ceph osd pool application enable <pool-name> <app-name>', where <app-name> is 'cephfs', 'rbd', 'rgw', or freeform for custom applications.
RECENT_CRASH 1 daemons have recently crashed
    mon.ceph-node03 crashed on host ceph-node03 at 2021-08-15 07:01:16.120542Z
```

启用application（即将资源池分类）

```bash
ceph osd pool application enable ceph-rbd-demo rbd
```

查看crash列表

```bash
[root@ceph-node01 ~]# ceph crash ls
ID                                                               ENTITY          NEW 
2021-08-15_07:01:16.120542Z_4062980e-2ba8-4041-a894-9d246fc29763 mon.ceph-node03  * 
```

查看具体crash信息

```bash
ceph crash info 2021-08-15_07:01:16.120542Z_4062980e-2ba8-4041-a894-9d246fc29763
```

打包crash信息，对于误报情况

```bash
ceph crash archive 2021-08-15_07:01:16.120542Z_4062980e-2ba8-4041-a894-9d246fc29763
```

再次查看集群信息

```bash
[root@ceph-node01 ~]# ceph -s
  cluster:
    id:     3b690447-512d-4700-a245-f729e1f2caed
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 46m)
    mgr: ceph-node02(active, since 9h), standbys: ceph-node03, ceph-node01
    osd: 3 osds: 3 up (since 48m), 3 in (since 2h)
 
  data:
    pools:   1 pools, 64 pgs
    objects: 296 objects, 1.0 GiB
    usage:   6.1 GiB used, 144 GiB / 150 GiB avail
    pgs:     64 active+clean
```

## 7.RGW对象存储

### 7.1 Ceph对象存储网关架构

![image.png](https://i.loli.net/2021/08/16/6cPZlJRyTvai78m.png)

[*Ceph 对象网关*](http://docs.ceph.org.cn/glossary/#term-34)是一个构建在 `librados` 之上的对象存储接口，它为应用程序访问Ceph 存储集群提供了一个 RESTful 风格的网关 。 [*Ceph 对象存储*](http://docs.ceph.org.cn/glossary/#term-30)支持 2 种接口：

- **兼容S3:** 提供了对象存储接口，兼容 亚马逊S3 RESTful 接口的一个大子集。

- **兼容Swift:** 提供了对象存储接口，兼容 Openstack Swift 接口的一个大子集。

Ceph 对象存储使用 Ceph 对象网关守护进程（ `radosgw` ），它是个与 Ceph 存储集群交互的 FastCGI 模块。因为它提供了与 OpenStack Swift 和 Amazon S3 兼容的接口， RADOS 要有它自己的用户管理。 Ceph 对象网关可与 Ceph FS 客户端或 Ceph 块设备客户端共用一个存储集群。 S3 和 Swift 接口共用一个通用命名空间，所以你可以用一个接口写如数据、然后用另一个接口取出数据。

**注意**：Ceph 对象存储**不**使用 Ceph 元数据服务器。

### 7.2 部署RGW存储网关

新建网关实例

```bash
ceph-deploy rgw create ceph-node01
```

查看集群状态，可以看到当前ceph-node01部署为rgw

```bash
[root@ceph-node01 my-cluster]# ceph -s
  cluster:
    id:     02416a48-f84a-4aed-a0c3-71a479d8d387
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 13m)
    mgr: ceph-node01(active, since 13m), standbys: ceph-node03, ceph-node02
    osd: 3 osds: 3 up (since 13m), 3 in (since 13m)
    rgw: 1 daemon active (ceph-node01)
 
  task status:
 
  data:
    pools:   5 pools, 192 pgs
    objects: 484 objects, 1.2 GiB
    usage:   6.4 GiB used, 144 GiB / 150 GiB avail
    pgs:     192 active+clean
 
  io:
    client:   53 KiB/s rd, 0 B/s wr, 79 op/s rd, 53 op/s wr
```

### 7.3 修改RGW默认端口

在当前部署目录，修改配置文件`ceph.conf`，最底下添加

```conf
[client.rgw.ceph-node01]
rgw_frontends = "civetweb port=80"
```

推送配置文件至其它节点

```bash
ceph-deploy --overwrite-conf config push ceph-node01 ceph-node02 ceph-node03
```

重启Ceph 对象网关服务

```bash
systemctl restart ceph-radosgw@rgw.ceph-node01.service
```

### 7.4 RGW之S3接口使用

创建兼容S3风格的Ceph 对象网关用户

```bash
[root@ceph-node01 my-cluster]# radosgw-admin user create --uid="ceph-s3-user" --display-name="Ceph S3 User Demo"
{
    "user_id": "ceph-s3-user",
    "display_name": "Ceph S3 User Demo",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "ceph-s3-user",
            "access_key": "YZSZ6GLWGFFEM6K4HY3H",
            "secret_key": "8HRi4eH9vYqmT94vhXg0T7aEwB2w3OONA4eKYaR1"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
```

也可以通过如下命令查看该用户信息

```bash
radosgw-admin user info --uid ceph-s3-user
```

验证s3访问

```bash
yum install python-boto -y
```

添加如下脚本

```python
#!/bin/python
import boto
import boto.s3.connection

access_key = 'YZSZ6GLWGFFEM6K4HY3H'
secret_key = '8HRi4eH9vYqmT94vhXg0T7aEwB2w3OONA4eKYaR1'
conn = boto.connect_s3(
        aws_access_key_id = access_key,
        aws_secret_access_key = secret_key,
        host = '192.168.2.7', port = 80,
        is_secure=False, calling_format = boto.s3.connection.OrdinaryCallingFormat(),
        )

bucket = conn.create_bucket('ceph-s3-bucket')
for bucket in conn.get_all_buckets():
            print "{name}".format(
                    name = bucket.name,
                    created = bucket.creation_date,
 )
```

运行脚本创建bucket

```bash
[root@ceph-node01 ~]# python s3test.py 
ceph-s3-bucket
```

查看资源池

```bash
[root@ceph-node01 ~]# ceph osd lspools 
1 ceph-rbd-demo
2 .rgw.root
3 default.rgw.control
4 default.rgw.meta
5 default.rgw.log
6 default.rgw.buckets.index
```

### 7.5 使用s3cmd管理对象存储

安装s3cmd

```bash
yum install -y s3cmd
```

配置s3cmd，按提示输入即可

```bash
[root@ceph-node01 ~]# s3cmd --configure

Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key: YZSZ6GLWGFFEM6K4HY3H
Secret Key: 8HRi4eH9vYqmT94vhXg0T7aEwB2w3OONA4eKYaR1
Default Region [US]: 

Use "s3.amazonaws.com" for S3 Endpoint and not modify it to the target Amazon S3.
S3 Endpoint [s3.amazonaws.com]: 192.168.2.7:80

Use "%(bucket)s.s3.amazonaws.com" to the target Amazon S3. "%(bucket)s" and "%(location)s" vars can be used
if the target S3 system supports dns based buckets.
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.s3.amazonaws.com]: 192.168.2.7:80/%(bucket)s 

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password: 
Path to GPG program [/usr/bin/gpg]: 

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [Yes]: no

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name:   

New settings:
  Access Key: YZSZ6GLWGFFEM6K4HY3H
  Secret Key: 8HRi4eH9vYqmT94vhXg0T7aEwB2w3OONA4eKYaR1
  Default Region: US
  S3 Endpoint: 192.168.2.7:80
  DNS-style bucket+hostname:port template for accessing a bucket: 192.168.2.7:80/%(bucket)s
  Encryption password: 
  Path to GPG program: /usr/bin/gpg
  Use HTTPS protocol: False
  HTTP Proxy server name: 
  HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'
```

更改s3cmd验证版本，修过/root/.s3cfg

```ini
signature_v2 = True
```

查看bucket列表

```bash
[root@ceph-node01 ~]# s3cmd ls
2021-08-16 06:45  s3://ceph-s3-bucket
```

创建bucket

```bash
[root@ceph-node01 ~]# s3cmd mb s3://s3cmd-demo
Bucket 's3://s3cmd-demo/' created
```

上传文件测试

```bash
[root@ceph-node01 ~]# s3cmd put s3test.py s3://s3cmd-demo/
upload: 's3test.py' -> 's3://s3cmd-demo/s3test.py'  [1 of 1]
 605 of 605   100% in    1s   334.54 B/s  done
```

关于s3cmd上传`ERROR: S3 error: 416 (InvalidRange)`错误，进入ceph部署目录，ceph.conf添加如下内容，然后重新推送到mon节点，重启ceph-mon即可

```bash
mon_max_pg_per_osd = 800
```

推送至其他节点

```bash
ceph-deploy --overwrite-conf config push ceph-node01 ceph-node02 ceph-node03
```

### 7.6 swift风格API接口

新建一个 SWIFT 用户，需要在之前建立的s3风格接口的用户基础上创建

```bash
radosgw-admin subuser create --uid=ceph-s3-user --subuser=ceph-s3-user:swift --access=full
```

新建secret key

```bash
radosgw-admin key create --subuser=ceph-s3-user:swift --key-type=swift --gen-secret
```

测试访问，安装Python包

```bash
pip install python-swiftclient
```

访问测试

```bash
swift -A http://192.168.2.7/auth/1.0 -U ceph-s3-user:swift -K "DZJRYrczpBDwXj1fSMxe3I052vxJnIybsSgVi2V5" list
```

配置swift连接信息环境变量，以便直接使用

```bash
export ST_AUTH=http://192.168.2.7/auth
export ST_USER=ceph-s3-user:swift
export ST_KEY=DZJRYrczpBDwXj1fSMxe3I052vxJnIybsSgVi2V5
```

通过swift创建bucket

```bash
swift post swift-demo
```

通过swift上传文件

```bash
swift upload swift-demo s3test.py
```

## 8.CephFS文件存储

### 8.1 CephFS组件架构

![image.png](https://i.loli.net/2021/08/16/Wjd1q7bDvPoJOhZ.png)

[*Ceph 文件系统*](http://docs.ceph.org.cn/glossary/#term-45)（ Ceph FS ）是个 POSIX 兼容的文件系统，它使用 Ceph 存储集群来存储数据。 Ceph 文件系统与 Ceph 块设备、同时提供 S3 和 Swift API 的 Ceph 对象存储、或者原生库（ librados ）一样，都使用着相同的 Ceph 存储集群系统。

Ceph 文件系统要求 Ceph 存储集群内至少有一个 [*Ceph MDS*](http://docs.ceph.org.cn/glossary/#term-63)。

### 8.2 安装部署CephFS集群

添加元数据服务器mds，进入部署目录操作

```bash
ceph-deploy mds create ceph-node01 ceph-node02 ceph-node03
```

查看集群信息，看到三个mds都是standby状态

```bash
[root@ceph-node01 my-cluster]# ceph -s
  cluster:
    id:     02416a48-f84a-4aed-a0c3-71a479d8d387
    health: HEALTH_WARN
            too many PGs per OSD (288 > max 250)
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 105m)
    mgr: ceph-node01(active, since 3h), standbys: ceph-node03, ceph-node02
    mds:  3 up:standby
    osd: 3 osds: 3 up (since 100m), 3 in (since 3h)
    rgw: 1 daemon active (ceph-node01)
 
  task status:
 
  data:
    pools:   8 pools, 288 pgs
    objects: 791 objects, 2.2 GiB
    usage:   9.4 GiB used, 141 GiB / 150 GiB avail
    pgs:     288 active+clean
```

### 8.3 创建CephFS文件系统

创建CephFS元数据资源池

```bash
ceph osd pool create cephfs_metadata 16 16
```

创建CephFS数据资源池

```bash
ceph osd pool create cephfs_data 16 16
```

创建CephFS文件系统，关联上面创建的两个资源池

```bash
ceph fs new cephfs-demo cephfs_metadata cephfs_data
```

查看创建的文件系统列表

```bash
[root@ceph-node01 my-cluster]# ceph fs ls
name: cephfs-demo, metadata pool: cephfs_metadata, data pools: [cephfs_data ]
```

查看mds状态

```bash
[root@ceph-node01 my-cluster]# ceph mds stat
cephfs-demo:1 {0=ceph-node01=up:active} 2 up:standby
```

### 8.4 CephFS内核挂载

创建挂载测试目录

```bash
mkdir -p /mnt/cephfs_demo
```

挂载CephFS

```bash
mount -t ceph 192.168.2.7:6789:/ /mnt/cephfs_demo/ -o name=admin
```

查看挂载情况

```bash
[root@ceph-node01 ~]# df -hT
Filesystem         Type      Size  Used Avail Use% Mounted on
devtmpfs           devtmpfs  2.0G     0  2.0G   0% /dev
tmpfs              tmpfs     2.0G     0  2.0G   0% /dev/shm
tmpfs              tmpfs     2.0G  8.9M  2.0G   1% /run
tmpfs              tmpfs     2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2          xfs        50G  2.5G   48G   6% /
/dev/sda1          xfs       297M  144M  154M  49% /boot
tmpfs              tmpfs     2.0G   24K  2.0G   1% /var/lib/ceph/osd/ceph-0
tmpfs              tmpfs     393M     0  393M   0% /run/user/0
192.168.2.7:6789:/ ceph       45G     0   45G   0% /mnt/cephfs_demo
```

### 8.5 Ceph-fuse用户态挂载

安装ceph-fuse客户端

```
yum install -y ceph-fuse
```

创建挂载测试目录

```bash
mkdir -p /mnt/cephfs_fuse
```

挂载文件系统，mds服务器可以写多个，以逗号隔开

```bash
ceph-fuse -n client.admin -m 192.168.2.7:6789,192.168.2.8:6789,192.168.2.9:6789 /mnt/cephfs_fuse/
```

查看挂载情况

```bash
[root@ceph-node01 ~]# df -hT
Filesystem     Type            Size  Used Avail Use% Mounted on
devtmpfs       devtmpfs        2.0G     0  2.0G   0% /dev
tmpfs          tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs          tmpfs           2.0G  8.9M  2.0G   1% /run
tmpfs          tmpfs           2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2      xfs              50G  2.6G   48G   6% /
/dev/sda1      xfs             297M  144M  154M  49% /boot
tmpfs          tmpfs           2.0G   24K  2.0G   1% /var/lib/ceph/osd/ceph-0
tmpfs          tmpfs           393M     0  393M   0% /run/user/0
ceph-fuse      fuse.ceph-fuse   45G     0   45G   0% /mnt/cephfs_fuse
```

## 9.OSD的扩容和换盘

### 9.1 OSD纵向扩容

随着集群资源的不断增长，Ceph集群的空间可能会存在不够用的情况，因此需要对集群进行扩容，扩容通常包含两种：横向扩容和纵向扩容。横向扩容即增加台机器，纵向扩容即在单个节点上添加更多的OSD存储，以满足数据增长的需求。

**需要在部署目录中操作**

如果扩容的磁盘已经有分区，可以如下操作删除分区表

```bash
ceph-deploy disk zap ceph-node01 /dev/sdc
```
使用ceph-deploy纵向扩容，使用一开始准备的第二块盘

```bash
ceph-deploy osd create ceph-node01 --data /dev/sdc
ceph-deploy osd create ceph-node02 --data /dev/sdc
ceph-deploy osd create ceph-node03 --data /dev/sdc
```

### 9.2 数据的rebalancing重分布

添加OSD的时候由于集群的状态（cluster map）已发生了改变，因此会涉及到数据的重分布（rebalancing），即 pool 的PGs数量是固定的，需要将PGs数平均的分摊到多个OSD节点上，例如，我们将2个OSD扩容至3个OSD，扩容后，Ceph集群的OSD map发生改变，需要将PGs移动至其他的节点上。

如果在生产中添加节点则会涉及到大量的数据的迁移，可能会造成性能的影响，所以尽量是一个一个扩容osd。

![image.png](https://i.loli.net/2021/08/16/xZlto4VyPMgjHbE.png)

