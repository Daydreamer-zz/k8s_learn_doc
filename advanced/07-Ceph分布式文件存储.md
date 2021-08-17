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
| ceph-node02 | eth0:192.168.2.8   eth1:192.168.3.3 | mon、mgr、osd |
| ceph-node03 | eth0:192.168.2.9   eth1:192.168.3.4 | mon、mgr、osd |

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

查看健康状况详情，可以看到ceph-rbd-demo资源池未启用application，是因为在创建该资源池未进行init操作，按提示需要enable application操作

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

### 9.3 临时暂停rebalance

暂停数据rebalance，如果此时业务流量较大，可以先将数据rebalance临时关闭，保障业务流量正常

```bash
ceph osd set norebalance
```

```bash
ceph osd set nobackfill
```

恢复数据rebalance

```bash
ceph osd unset nobackfill
```

```bash
ceph osd unset norebalance
```

### 9.4 OSD坏盘更换(删除OSD)

查看osd延迟，可以通过osd延迟判定对应的盘是否出现故障

```
ceph osd perf
```

模拟osd故障

```bash
systemctl stop ceph-osd@5.service
```

查看集群状态

```bash
[root@ceph-node01 ~]# ceph -s
  cluster:
    id:     9f1caa0b-78df-4788-b279-ca45e12686d9
    health: HEALTH_WARN
            1 osds down
            Degraded data redundancy: 128/834 objects degraded (15.348%), 55 pgs degraded, 133 pgs undersized
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 35m)
    mgr: ceph-node01(active, since 36m), standbys: ceph-node02, ceph-node03
    mds: cephfs-demo:1 {0=ceph-node02=up:active} 2 up:standby
    osd: 6 osds: 5 up (since 75s), 6 in (since 35m)
    rgw: 1 daemon active (ceph-node01)
 
  task status:
 
  data:
    pools:   8 pools, 256 pgs
    objects: 278 objects, 158 MiB
    usage:   6.4 GiB used, 294 GiB / 300 GiB avail
    pgs:     128/834 objects degraded (15.348%)
             123 active+clean
             78  active+undersized
             55  active+undersized+degraded
```

查看osd列表，看到osd.5是down的状态

```bash
[root@ceph-node01 ~]# ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF 
-1       0.29279 root default                                 
-3       0.09760     host ceph-node01                         
 0   hdd 0.04880         osd.0            up  1.00000 1.00000 
 3   hdd 0.04880         osd.3            up  1.00000 1.00000 
-5       0.09760     host ceph-node02                         
 1   hdd 0.04880         osd.1            up  1.00000 1.00000 
 4   hdd 0.04880         osd.4            up  1.00000 1.00000 
-7       0.09760     host ceph-node03                         
 2   hdd 0.04880         osd.2            up  1.00000 1.00000 
 5   hdd 0.04880         osd.5          down  1.00000 1.00000
```

将故障的osd进行out操作，out操作后等待数据重新rebalance完成后再进行以后操作

```bash
ceph osd out osd.5
```

删除对应的crush map

```bash
ceph osd crush rm osd.5
```

删除osd

```bash
ceph osd rm osd.5
```

删除osd认证key

```bash
ceph auth rm osd.5
```

再次查看osd列表，发现osd.5已经不在osd列表中了

```bash
[root@ceph-node01 ~]# ceph osd tree
ID CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF 
-1       0.24399 root default                                 
-3       0.09760     host ceph-node01                         
 0   hdd 0.04880         osd.0            up  1.00000 1.00000 
 3   hdd 0.04880         osd.3            up  1.00000 1.00000 
-5       0.09760     host ceph-node02                         
 1   hdd 0.04880         osd.1            up  1.00000 1.00000 
 4   hdd 0.04880         osd.4            up  1.00000 1.00000 
-7       0.04880     host ceph-node03                         
 2   hdd 0.04880         osd.2            up  1.00000 1.00000
```

### 9.5 数据一致性检查

数据一致性检查集群会在固定时间自动进行，如果要手动执行可以按如下操作。

列出pg

```bash
ceph pg ls
```

数据轻量级一致性检查

```bash
ceph pg scrub 1.0
```

深度数据一致性检查

```bash
ceph pg deep-scrub 1.0
```

## 10.Ceph集群运维

### 10.1 操作集群服务

主要通过systemd管理ceph集群服务

- 启动所有守护进程

  ```bash
  systemctl start ceph.target
  ```

- 要停止 Ceph 节点上的所有守护进程（不考虑类型），请执行以下命令

  ```bash
  systemctl stop ceph\*.service ceph\*.target
  ```

- 要在 Ceph 节点上启动特定类型的所有守护进程，请执行以下操作之一

  ```bash
  systemctl start ceph-osd.target
  systemctl start ceph-mon.target
  systemctl start ceph-mds.target
  ```

- 要停止 Ceph 节点上特定类型的所有守护进程，请执行以下操作之一

  ```bash
  systemctl stop ceph-mon\*.service ceph-mon.target
  systemctl stop ceph-osd\*.service ceph-osd.target
  systemctl stop ceph-mds\*.service ceph-mds.target
  ```

- 要在 Ceph 节点上启动特定的守护程序实例，请执行以下操作之一

  ```bash
  systemctl start ceph-osd@{id}
  systemctl start ceph-mon@{hostname}
  systemctl start ceph-mds@{hostname}
  ```

  例如：

  ```bash
  systemctl start ceph-osd@1
  systemctl start ceph-mon@ceph-server
  systemctl start ceph-mds@ceph-server
  ```


### 10.2 Ceph日志分析

ceph的日志位置在`/var/log/ceph`

### 10.3 Ceph集群监控

#### 集群状态

通过实时交互终端查看集群状况

```bash
[root@ceph-node01 ~]# ceph
ceph> status
  cluster:
    id:     9f1caa0b-78df-4788-b279-ca45e12686d9
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03 (age 18m)
    mgr: ceph-node02(active, since 18m), standbys: ceph-node03, ceph-node01
    mds: cephfs-demo:1 {0=ceph-node03=up:active} 2 up:standby
    osd: 6 osds: 6 up (since 18m), 6 in (since 2h)
    rgw: 1 daemon active (ceph-node01)
 
  task status:
 
  data:
    pools:   8 pools, 256 pgs
    objects: 535 objects, 1.2 GiB
    usage:   9.5 GiB used, 291 GiB / 300 GiB avail
    pgs:     256 active+clean
```

通过参数的方式查看集群状况

```bash
ceph status #或者ceph -s
```

动态查看集群状态，集群的信息状态会实时刷新

```
ceph -w
```

查看集群当前占用

```bash
ceph df #或者用rados df
```

集群仲裁情况

```bash
ceph quorum_status 
```

#### osd监控

```bash
[root@ceph-node01 ~]# ceph osd status 
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
| id |     host    |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | ceph-node01 | 1552M | 48.4G |    0   |     0   |    0   |     0   | exists,up |
| 1  | ceph-node02 | 1699M | 48.3G |    0   |     0   |    0   |     0   | exists,up |
| 2  | ceph-node03 | 1531M | 48.5G |    0   |     0   |    0   |     0   | exists,up |
| 3  | ceph-node01 | 1675M | 48.3G |    0   |     0   |    0   |     0   | exists,up |
| 4  | ceph-node02 | 1527M | 48.5G |    0   |     0   |    0   |     0   | exists,up |
| 5  | ceph-node03 | 1695M | 48.3G |    0   |     0   |    0   |     0   | exists,up |
+----+-------------+-------+-------+--------+---------+--------+---------+-----------+
```

```bash
[root@ceph-node01 ~]# ceph osd stat #或者用 ceph osd dump
6 osds: 6 up (since 25m), 6 in (since 2h); epoch: e81
```

```bash
[root@ceph-node01 ~]# ceph osd df
ID CLASS WEIGHT  REWEIGHT SIZE    RAW USE DATA    OMAP    META     AVAIL   %USE VAR  PGS STATUS 
 0   hdd 0.04880  1.00000  50 GiB 1.5 GiB 528 MiB  20 KiB 1024 MiB  48 GiB 3.03 0.96 113     up 
 3   hdd 0.04880  1.00000  50 GiB 1.6 GiB 651 MiB  27 KiB 1024 MiB  48 GiB 3.27 1.04 143     up 
 1   hdd 0.04880  1.00000  50 GiB 1.7 GiB 676 MiB  20 KiB 1024 MiB  48 GiB 3.32 1.05 121     up 
 4   hdd 0.04880  1.00000  50 GiB 1.5 GiB 504 MiB  23 KiB 1024 MiB  49 GiB 2.98 0.95 135     up 
 2   hdd 0.04880  1.00000  50 GiB 1.5 GiB 508 MiB  23 KiB 1024 MiB  49 GiB 2.99 0.95 123     up 
 5   hdd 0.04880  1.00000  50 GiB 1.7 GiB 672 MiB  20 KiB 1024 MiB  48 GiB 3.31 1.05 133     up 
                    TOTAL 300 GiB 9.5 GiB 3.5 GiB 136 KiB  6.0 GiB 291 GiB 3.15                 
MIN/MAX VAR: 0.95/1.05  STDDEV: 0.15
```

#### mon监控

```bash
[root@ceph-node01 ~]# ceph mon stat 
e3: 3 mons at {ceph-node01=[v2:192.168.2.7:3300/0,v1:192.168.2.7:6789/0],ceph-node02=[v2:192.168.2.8:3300/0,v1:192.168.2.8:6789/0],ceph-node03=[v2:192.168.2.9:3300/0,v1:192.168.2.9:6789/0]}, election epoch 20, leader 0 ceph-node01, quorum 0,1,2 ceph-node01,ceph-node02,ceph-node03
```

#### mds监控

```bash
[root@ceph-node01 ~]# ceph mds stat
cephfs-demo:1 {0=ceph-node03=up:active} 2 up:standby
```

或者

```bash
ceph fs dump
```

#### ceph admin socket应用

直接通过和ceph服务进程的socket文件通信，进行操作

例如：查看mon的config

```bash
ceph --admin-daemon  /var/run/ceph/ceph-mon.ceph-node01.asok config show
```

### 10.4 pools(资源池)管理

#### 列出集群的pool列表

```bash
ceph osd lspools
```

#### 查看某个pool的配置信息

例如查看某个pool的pg_num

```bash
ceph osd pool get cephfs_data pg_num
```

#### pool关联特定应用

针对不同应用的pool进行分类，如：rbd类型的pool配置成rbd类型，cephfs类型配置为cephfs，rgw类型配置为rgw

创建实例pool

```bash
ceph osd pool create pool_demo 32 32
```

关联为rbd类型

```bash
ceph osd pool application enable pool_demo rbd
```

#### pool设定配额

配置pool可以使用多少objects

```bash
ceph osd pool set-quota pool_demo max_objects 10000
```

### 10.5 Ceph PG数据分布

#### 什么是PG

PG和pool(资源池)是互相关联的，最终存储的是object，PG又经过crush map的算法，最终落到不同的osd上。pg数量越多，经过crush map算法，他会映射到更多的osd上。

#### PG的作用

- 数据分布情况

  PG数量越多，数据在osd上就越分散，丢数据概率越小，反之亦然。

- 提高计算效率

  由于object的数量非常大，直接由ceph运算负荷会非常大，所以有了PG后，PG中会有多个object，crush map算法计算时只计算PG落在哪个osd上即可。

#### PG数量计算方法

![image.png](https://i.loli.net/2021/08/17/RjXQSp8wyZ1eLPn.png)

**注意**：最终pg_num的计算结果取接近计算值的2次幂，以提高CRUSH算法效率。例如：计算值为200时，取256作为结果。pgp_num的值应设置为与pg_num一致。

参数解释：

- **Target PGs per OSD**：预估每个OSD的PG数，一般取100计算。当预估以后集群OSD数不会增加时，取100计算；当预估以后集群OSD数会增加一倍时，取200计算。
- **OSD #**：集群OSD数量。
- **%Data**：预估该pool占该OSD集群总容量的近似百分比。
- **Size**：该pool的副本数。

经过计算后，可以适当调整资源池pg的数量，可以通过如下命令

```bash
ceph osd pool set {pool-name} pg_num {pg-num}
```

相对于的pgp数量也需要调整，一般和pg数量相同

```bash
ceph osd pool set {pool-name} pgp_num {pgp-num}
```

### 10.6 删除pool(资源池)

删除资源池pool的命令格式有特殊要求，资源池名必须重复两次，最后加入`--yes-i-really-really-mean-it`

```bash
ceph osd delete {pool-name} {pool-name} --yes-i-really-really-mean-it
```

而且ceph.conf配置文件必须加入`mon_allow_pool_delete = true`，修改后重新推送至集群节点

## 11.定制Crush Map规则

### 11.1 CrushMap功能简介

所述CRUSH算法确定如何存储和通过计算存储位置检索数据。CRUSH 使 Ceph 客户端能够直接与 OSD 通信，而不是通过中央服务器或代理。通过算法确定的数据存储和检索方法，Ceph 避免了单点故障、性能瓶颈和可扩展性的物理限制。

crushmap能够决定你的数据如何在ceph集群分配，通过crushmap规则可以实现数据的容灾。



桶是层次结构中内部节点的 CRUSH 术语：主机、机架、行等。 CRUSH 映射定义了一系列用于描述这些节点的*类型*。

![image.png](https://i.loli.net/2021/08/17/XGMgncFWY4pA8Um.png)

默认类型包括：

- `osd`（或`device`）
- `host`
- `chassis`
- `rack`
- `row`
- `pdu`
- `pod`
- `room`
- `datacenter`
- `zone`
- `region`
- `root`

### 11.2 CrushMap规则剖析

查看集群CrushMap规则

```bash
ceph osd crush tree # 或者ceph osd crush dump
```

查看某个pool的crush_rule

```
ceph osd pool get {pool-name} crush_rule
```

### 11.3 定制Crush拓扑架构

本次实例集群架构为左边，通过调整实现右边架构（模拟每个机器两种不同磁盘，HDD和SSD）

![image.png](https://i.loli.net/2021/08/17/7o3kKqjS8hw9cWy.png)

### 11.4 手动编辑CrushMap

导出二进制格式crushmap

```bash
ceph osd getcrushmap -o crushmap.bin
```

反编译

```bash
crushtool -d crushmap.bin -o crushmap.txt
```

```
# begin crush map
tunable choose_local_tries 0
tunable choose_local_fallback_tries 0
tunable choose_total_tries 50
tunable chooseleaf_descend_once 1
tunable chooseleaf_vary_r 1
tunable chooseleaf_stable 1
tunable straw_calc_version 1
tunable allowed_bucket_algs 54

# devices
device 0 osd.0 class hdd
device 1 osd.1 class hdd
device 2 osd.2 class hdd
device 3 osd.3 class ssd
device 4 osd.4 class ssd
device 5 osd.5 class ssd

# types
type 0 osd
type 1 host
type 2 chassis
type 3 rack
type 4 row
type 5 pdu
type 6 pod
type 7 room
type 8 datacenter
type 9 zone
type 10 region
type 11 root

# buckets
host ceph-node01 {
	id -3		# do not change unnecessarily
	id -4 class hdd		# do not change unnecessarily
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.0 weight 0.049
}
host ceph-node02 {
	id -5		# do not change unnecessarily
	id -6 class hdd		# do not change unnecessarily
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.1 weight 0.049
}
host ceph-node03 {
	id -7		# do not change unnecessarily
	id -8 class hdd		# do not change unnecessarily
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.2 weight 0.049
}
host ceph-node01-ssd {
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.3 weight 0.049
}
host ceph-node02-ssd {
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.4 weight 0.049
}
host ceph-node03-ssd {
	# weight 0.098
	alg straw2
	hash 0	# rjenkins1
	item osd.5 weight 0.049
}
root default {
	id -1		# do not change unnecessarily
	id -2 class hdd		# do not change unnecessarily
	# weight 0.293
	alg straw2
	hash 0	# rjenkins1
	item ceph-node01 weight 0.049
	item ceph-node02 weight 0.049
	item ceph-node03 weight 0.049
}
root ssd {
	# weight 0.293
	alg straw2
	hash 0	# rjenkins1
	item ceph-node01-ssd weight 0.049
	item ceph-node02-ssd weight 0.049
	item ceph-node03-ssd weight 0.049
}

# rules
rule replicated_rule {
	id 0
	type replicated
	min_size 1
	max_size 10
	step take default
	step chooseleaf firstn 0 type host
	step emit
}

rule demo_rule {
    id 1
	type replicated
	min_size 1
	max_size 10
	step take ssd
	step chooseleaf firstn 0 type host
	step emit
}
# end crush map
```

重新编译为二进制文件

```bash
crushtool -c crushmap.txt -o crushmap-new.bin
```

应用新规则

```bash
ceph osd setcrushmap -i crushmap-new.bin
```

查看新规则

```bash
[root@ceph-node01 ~]# ceph osd tree
ID  CLASS WEIGHT  TYPE NAME                STATUS REWEIGHT PRI-AFF 
-12       0.14699 root ssd                                         
 -9       0.04900     host ceph-node01-ssd                         
  3   ssd 0.04900         osd.3                up  1.00000 1.00000 
-10       0.04900     host ceph-node02-ssd                         
  4   ssd 0.04900         osd.4                up  1.00000 1.00000 
-11       0.04900     host ceph-node03-ssd                         
  5   ssd 0.04900         osd.5                up  1.00000 1.00000 
 -1       0.14699 root default                                     
 -3       0.04900     host ceph-node01                             
  0   hdd 0.04900         osd.0                up  1.00000 1.00000 
 -5       0.04900     host ceph-node02                             
  1   hdd 0.04900         osd.1                up  1.00000 1.00000 
 -7       0.04900     host ceph-node03                             
  2   hdd 0.04900         osd.2                up  1.00000 1.00000
```

获取演示资源池crush规则

```bash
[root@ceph-node01 ~]# ceph osd pool get demo-pool crush_rule
crush_rule: replicated_rule
```

修改为刚刚创建的名为`demo_rule`的crushrule

```bash
[root@ceph-node01 ~]# ceph osd pool set demo-pool crush_rule demo_rule
set pool 12 crush_rule to demo_rule
```

创建rbd并查看osd分布

```bash
[root@ceph-node01 ~]# rbd -p demo-pool create test-crush.img --size 10G
[root@ceph-node01 ~]# rbd -p demo-pool ls
test-crush.img
[root@ceph-node01 ~]# ceph osd map demo-pool test-crush.img
osdmap e189 pool 'demo-pool' (12) object 'test-crush.img' -> pg 12.2e7135e6 (12.6) -> up ([4,3,5], p4) acting ([4,3,5], p4)
```

### 11.5 命令行调整CrushMap

添加bucket，注意这里的bucket和对象存储的bucket不是一个概念

```bash
ceph osd crush add-bucket ssd root
```

```bash
ceph osd crush add-bucket ceph-node01-ssd host
ceph osd crush add-bucket ceph-node02-ssd host
ceph osd crush add-bucket ceph-node03-ssd host
```

移动目标osd至新建的bucket

```bash
ceph osd crush move osd.3 host=ceph-node01-ssd root=ssd
ceph osd crush move osd.4 host=ceph-node02-ssd root=ssd
ceph osd crush move osd.5 host=ceph-node03-ssd root=ssd
```

查看当前osd crushmap

```bash
[root@ceph-node01 ~]# ceph osd tree
ID  CLASS WEIGHT  TYPE NAME            STATUS REWEIGHT PRI-AFF 
-12       0.04880 host ceph-node03-ssd                         
  5   hdd 0.04880     osd.5                up  1.00000 1.00000 
-11       0.04880 host ceph-node02-ssd                         
  4   hdd 0.04880     osd.4                up  1.00000 1.00000 
-10       0.04880 host ceph-node01-ssd                         
  3   hdd 0.04880     osd.3                up  1.00000 1.00000 
 -9             0 root ssd                                     
 -1       0.14639 root default                                 
 -3       0.04880     host ceph-node01                         
  0   hdd 0.04880         osd.0            up  1.00000 1.00000 
 -5       0.04880     host ceph-node02                         
  1   hdd 0.04880         osd.1            up  1.00000 1.00000 
 -7       0.04880     host ceph-node03                         
  2   hdd 0.04880         osd.2            up  1.00000 1.00000
```

创建rule

```bassh
ceph osd crush rule create-replicated ssd-demo ssd host hdd
```

### 11.6 编辑CrushMap注意事项

- 在进行任何操作crushmap之前，提前导出crushmap二进制文件备份

- 自定义crush location需要配置`osd crush update on start = false`

  如果没有配置这个参数，重启osd后，该节点的osd会回到原来的默认位置，在配置了这个参数之后，扩容osd需要手动将新的osd move到指定的bucket下

  进入部署目录修改ceph.conf，加入

  ```
  [osd]
  osd crush update on start = false
  ```

  推送至其他节点

  ```
  ceph-deploy --overwrite-conf  config push ceph-node01 ceph-node02 ceph-node03
  ```

  重启所有节点osd

  ```bash
  systemctl restart ceph-osd.target
  ```

## 12.RBD的高级功能

### 12.1 RBD回收站机制

创建演示rbd

```bash
ceph osd pool create demo-pool 32 32
ceph osd pool application enable demo-pool rbd
rbd create demo-pool/demo-rbd.img --size 10G
for i in deep-flatten fast-diff object-map exclusive-lock;do rbd feature disable demo-pool/demo-rbd.img $i  ;done
```

移动rbd到回收站

```bash
rbd trash move demo-pool/demo-rbd.img --expires-at 20210820 #需要指定过期日期
```

查看rbd回收站

```bash
[root@ceph-node01 ~]# rbd trash  -p demo-pool ls
ae4e93029347 demo-rbd.img
```

从回收站恢复

```bash
rbd trash restore -p  demo-pool ae4e93029347
```

### 12.2 RBD镜像制作快照

创建指定类型的rbd image

```bash
rbd create demo-pool/demo-rbd.img --image-feature layering --size 10G
```

映射此镜像到块设备并挂载

```bash
rbd map demo-pool/demo-rbd.img #映射块设备
mkfs.ext4 /dev/rbd0 #格式化
mount /dev/rbd0 /mnt/ceph_rbd/ #挂载

#写入测试数据
cd /mnt/ceph_rbd/
echo "hahahahaah" > 1.txt
```

创建快照

```bash
rbd snap create demo-pool/demo-rbd.img@snap_20210817 # @后跟快照的名称
```

查看快照列表

```bash
[root@ceph-node01 ~]# rbd snap ls demo-pool/demo-rbd.img
SNAPID NAME          SIZE   PROTECTED TIMESTAMP                
     4 snap_20210817 10 GiB           Tue Aug 17 19:58:42 2021
```

### 12.3 RBD数据快照恢复

模拟误删除数据

```bash
[root@ceph-node01 ceph_rbd]# cd /mnt/ceph_rbd/ && rm -rf * && ll
total 0
```

卸载块设备

```bash
umount /dev/rbd0
```

恢复快照

```bash
rbd snap rollback demo-pool/demo-rbd.img@snap_20210817
```

重新挂载rbd块设备

```bash
mount /dev/rbd0 /mnt/ceph_rbd/
```

查看目录文件

```bash
[root@ceph-node01 ~]# cd /mnt/ceph_rbd/ && ll && cat 1.txt
total 20
-rw-r--r-- 1 root root    11 Aug 17 20:16 1.txt
drwx------ 2 root root 16384 Aug 17 20:16 lost+found
hahahahaah
```

### 12.4 RBD镜像克隆机制

参考公有云公共系统镜像，直接使用公共系统镜像可以快速创建实例。

ceph通过copy-on-write(COW)功能实现了类似的功能，通过提前对rbd img拍摄的模板快照，可以直接从此快照快速克隆出一个rbd img。

克隆分为两种，一种是完整克隆，但速度较慢；另一种是快速克隆，新镜像是类似链接到父镜像，读取从父镜像读取，写的话写入子镜像，既节省空间又加快了克隆速度，但是必须保证父镜像一直存在，所以必须对父镜像加入protect的标志位防止误删除。



创建模板镜像

```bash
rbd snap create demo-pool/demo-rbd.img@template
```

保护此镜像

```bash
rbd snap protect demo-pool/demo-rbd.img@template
```

克隆镜像

```bash
rbd clone demo-pool/demo-rbd.img@template demo-pool/vm1-clone.img
```

查看克隆出的镜像信息

```bash
[root@ceph-node01 ~]# rbd info demo-pool/vm1-clone.img
rbd image 'vm1-clone.img':
	size 10 GiB in 2560 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: d46d218cf54
	block_name_prefix: rbd_data.d46d218cf54
	format: 2
	features: layering
	op_features: 
	flags: 
	create_timestamp: Tue Aug 17 22:02:33 2021
	access_timestamp: Tue Aug 17 22:02:33 2021
	modify_timestamp: Tue Aug 17 22:02:33 2021
	parent: demo-pool/demo-rbd.img@template
	overlap: 10 GiB
```

### 12.5 RBD解除依赖关系

由于以上克隆镜像的操作，父镜像如果损坏或丢失，所有的子镜像全部都会故障，所有可以通过接触依赖关系将父子镜像关系抽离出来。由于是一个独立的镜像，相应的占用空间也会增大，

查看某个父镜像包含的子镜像

```bash
[root@ceph-node01 ~]# rbd children demo-pool/demo-rbd.img@template
demo-pool/vm1-clone.img
demo-pool/vm2-clone.img
demo-pool/vm3-clone.img
```

解除某个镜像的父子关系(flatten)

```bash
rbd flatten demo-pool/vm1-clone.img
```

### 12.6 RBD的备份和恢复

前面的快照是建立在ceph集群内部的，如果ceph集群不可用了，则快照也没有办法进行恢复，所以可使用RBD的备份功能，备份到集群外部。或者需要将某些数据迁移到另外一个ceph集群，也可以通过备份恢复来实现。

创建rbd镜像快照

```
rbd snap create demo-pool/demo-rbd.img@snap-demo
```

导出rbd镜像快照

```bash
rbd export demo-pool/demo-rbd.img@snap-demo /root/snap-demo.img
```

演示误删除数据，该演示rbd块设备挂载在/mnt/ceph_rbd下

```bash
cd /mnt/ceph_rbd/ && rm -rf *
```

导入备份的rbd镜像快照，导入另一个新的rbd，不存在会自动创建

```bash
rbd import snap-demo.img demo-pool/demo-rbd-import.img
```

映射新的rbd并挂载到原来位置

```bash
#禁用不兼容的feature
[root@ceph-node01 ~]# rbd feature disable demo-pool/demo-rbd-import.img object-map fast-diff deep-flatten

#映射rbd为块设备
[root@ceph-node01 ~]# rbd map demo-pool/demo-rbd-import.img
/dev/rbd1

#卸载原块设备
[root@ceph-node01 ~]# umount /dev/rbd0

#挂载恢复的新的rbd为块设备
[root@ceph-node01 ~]# mount /dev/rbd1 /mnt/ceph_rbd/

#进入目录查看数据
[root@ceph-node01 ~]# cd /mnt/ceph_rbd/
[root@ceph-node01 ceph_rbd]# ll
total 20
-rw-r--r-- 1 root root    11 Aug 17 20:16 1.txt
drwx------ 2 root root 16384 Aug 17 20:16 lost+found
```







