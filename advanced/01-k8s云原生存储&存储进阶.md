# k8s云原生存储&存储进阶

## 1.1 动态存储

StorageClass：存储类，由kubernetes管理员创建，用于动态PV的管理，可以链接至不同的后端存储，比如Ceph、GlusterFS等。之后对于存储的请求可以指向StorageClass，然后StrageClass会自动的创建、删除PV。

实现方式：

- in-tree：内置于k8s核心代码，对于存储的管理，都需要响应的代码实现
- out-of-tree：由存储驱动厂商提供一个驱动(CSI或者Flex Volume)，安装到k8s集群，然后StrorageClass只需要配置该驱动即可，驱动器会代替StorageClass管理存储。

## 1.2 云原生存储Rook

Rook是一个自我管理的分布式存储编排系统，它本身并不是存储系统，在存储和k8s之前搭建了一个桥梁，使存储系统的搭建和维护变得特别简单，Rook将分布式存储系统变为自我管理、自我扩展、自我修复s的存储服务。他让一些存储的操作，比如部署、配置、扩容、升级、迁移、灾难恢复、监视和资源管理变得自动化，无需人工处理。并且Rook支持CSI，可以利用CSI做一些PVC的快照、扩容、克隆等操作。

## 1.3 Rook架构

![image.png](https://i.loli.net/2021/07/13/JT1OteAq5wruPcb.png)

## 1.4 Rook部署Ceph

### 1.4.1创建命名空间

```bash
kubectl create namespace rook-ceph
```

### 1.4.2 克隆代码

```bash
git clone --single-branch --branch v1.6.7 https://github.com/rook/rook.git
```

### 1.4.3 创建资源

```bash
cd rook/cluster/examples/kubernetes/ceph
```

```bash
kubectl create -f crds.yaml -f common.yaml
```

### 1.4.4 修改operator.yaml

#### 修改为国内镜像

修改Rook CSI镜像地址，原本的地址可能是gcr的镜像，但是gcr的镜像无法被国内访问，所以需要同步gcr的镜像到阿里云镜像仓库

```yaml
ROOK_CSI_CEPH_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/cephcsi:v3.3.1"
ROOK_CSI_REGISTRAR_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/csi-node-driver-registrar:v2.2.0"
ROOK_CSI_RESIZER_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/csi-resizer:v1.2.0"
ROOK_CSI_PROVISIONER_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/csi-provisioner:v2.2.2"
ROOK_CSI_SNAPSHOTTER_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/csi-snapshotter:v4.1.1"
ROOK_CSI_ATTACHER_IMAGE: "registry.cn-qingdao.aliyuncs.com/zz_google_containers/csi-attacher:v3.2.1"
```

371行左右

```yaml
image: registry.cn-qingdao.aliyuncs.com/zz_google_containers/ceph:v1.6.7
```

#### 自动发现容器

修改rook自动发现容器的部署，ROOK_ENABLE_DISCOVERY_DAEMON改成true即可

#### 创建operator

等待operator容器和discover容器启动

```bash
kubectl create -f operator.yaml
```

## 1.5 创建Ceph集群

### 1.5.1 配置修改

修改cluster.yaml

主要更改的是osd节点所在的位置

**注意**：新版必须采用裸盘，即未格式化的磁盘。其中k8s-node02 k8s-node03 k8s-node04有新加的一个磁盘，可以通过lsblk -f查看新添加的磁盘名称。**建议最少三个节点，否则后面的试验可能会出现问题**

大约在221行左右

```yaml
# Individual nodes and their config can be specified as well, but 'useAllNodes' above must be set to false. Then, only the named
# nodes below will be used as storage resources.  Each node's 'name' field should match their 'kubernetes.io/hostname' label.
    nodes:
    - name: "k8s-node02"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
    - name: "k8s-node03"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
    - name: "k8s-node04"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
```



dashboard禁用ssl，使用http访问

```yaml
  dashboard:
    enabled: true
    # serve the dashboard under a subpath (useful when you are accessing the dashboard via a reverse proxy)
    # urlPrefix: /ceph-dashboard
    # serve the dashboard at the given port.
    # port: 8443
    # serve the dashboard using SSL
    ssl: false
```

修改国内镜像，24行左右

```yaml
image: registry.cn-qingdao.aliyuncs.com/zz_google_containers/ceph:v15.2.13
```



### 1.5.2 创建集群

需要注意的是，osd-x的容器必须是存在的，且是正常的。如果上述Pod均正常，则认为集群安装成功。

```bash
kubectl create -f cluster.yaml
```

```bash
[root@k8s-master01 ~]# kubectl -n rook-ceph get pod 
NAME                                                     READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-8l79r                                   3/3     Running     15         3d22h
csi-cephfsplugin-d56pt                                   3/3     Running     15         3d22h
csi-cephfsplugin-kqd9p                                   3/3     Running     15         3d22h
csi-cephfsplugin-pjfp5                                   3/3     Running     15         3d22h
csi-cephfsplugin-provisioner-84d6c75cd8-9nrhm            6/6     Running     30         3d22h
csi-cephfsplugin-provisioner-84d6c75cd8-sjkbd            6/6     Running     30         3d22h
csi-cephfsplugin-r5hlc                                   3/3     Running     15         3d22h
csi-rbdplugin-d6mtk                                      3/3     Running     15         3d22h
csi-rbdplugin-mtccd                                      3/3     Running     15         3d22h
csi-rbdplugin-provisioner-57659bb697-pl59m               6/6     Running     30         3d22h
csi-rbdplugin-provisioner-57659bb697-s4hpj               6/6     Running     30         3d22h
csi-rbdplugin-r48bj                                      3/3     Running     15         3d22h
csi-rbdplugin-t2pc9                                      3/3     Running     15         3d22h
csi-rbdplugin-xmgnz                                      3/3     Running     15         3d22h
rook-ceph-crashcollector-k8s-master01-556bd44cb5-7ppf7   1/1     Running     2          2d22h
rook-ceph-crashcollector-k8s-node02-6cc8d6dc9b-xsgjc     1/1     Running     2          2d22h
rook-ceph-crashcollector-k8s-node03-745dfcbf5-hhrjz      1/1     Running     5          3d22h
rook-ceph-crashcollector-k8s-node04-7d947568d-s9n9j      1/1     Running     5          3d22h
rook-ceph-mds-myfs-a-9bb754885-bwqfs                     1/1     Running     6          2d22h
rook-ceph-mds-myfs-b-7f7964cf95-9f92c                    1/1     Running     6          2d22h
rook-ceph-mgr-a-6f646d6864-gdq49                         1/1     Running     10         3d22h
rook-ceph-mon-a-54cf78f8d4-cksqz                         1/1     Running     5          3d22h
rook-ceph-mon-b-7569cf6b5-mgph9                          1/1     Running     5          3d22h
rook-ceph-mon-c-5b64bcf5c4-lrj7r                         1/1     Running     5          3d22h
rook-ceph-operator-7678595675-76fxm                      1/1     Running     5          3d22h
rook-ceph-osd-0-7978f7f7d8-4smp4                         1/1     Running     10         3d22h
rook-ceph-osd-1-788dc4cb4c-xnkb2                         1/1     Running     10         3d22h
rook-ceph-osd-2-b5b75b579-kjcmx                          1/1     Running     10         3d22h
rook-ceph-osd-prepare-k8s-node02-d6zhk                   0/1     Completed   0          8m17s
rook-ceph-osd-prepare-k8s-node03-79hxp                   0/1     Completed   0          8m15s
rook-ceph-osd-prepare-k8s-node04-svltg                   0/1     Completed   0          8m13s
rook-ceph-tools-564d97fcf5-rt4fn                         1/1     Running     4          3d20h
rook-discover-7dk8d                                      1/1     Running     5          3d22h
rook-discover-7s6fc                                      1/1     Running     5          3d22h
rook-discover-p7vfq                                      1/1     Running     5          3d22h
rook-discover-tfxrh                                      1/1     Running     5          3d22h
rook-discover-z6nm8                                      1/1     Running     5          3d22h
```

## 1.6 安装Ceph Snapshot控制器

k8s 1.19版本以上需要单独安装snapshot控制器，才能完成pvc的快照功能，所以在此提前安装下，如果是1.19以下版本，不需要单独安装

snapshot控制器的部署在集群安装时的k8s-ha-install项目中，需要切换到1.20.x分支

```bash
cd /root/k8s-ha-install/
git checkout manual-installation-v1.20.x
```

```bash
kubectl create -f snapshotter/ -n kube-system
```

```bash
[root@k8s-master01 ~]# kubectl  get po -n kube-system -l app=snapshot-controller
NAME                    READY   STATUS    RESTARTS   AGE
snapshot-controller-0   1/1     Running   4          3d20h
```

## 1.7 安装Ceph客户端工具

```bash
cd rook/cluster/examples/kubernetes/ceph
```

```bash
kubectl  create -f toolbox.yaml -n rook-ceph
```



待容器Running后，即可执行相关命令

```bash
[root@k8s-master01 ~]# kubectl  get po -n rook-ceph -l app=rook-ceph-tools
NAME                               READY   STATUS    RESTARTS   AGE
rook-ceph-tools-564d97fcf5-rt4fn   1/1     Running   4          3d20h
```



进入容器命令行方式查看集群状态

```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash
```

```bash
[root@rook-ceph-tools-564d97fcf5-rt4fn /]# ceph status
  cluster:
    id:     b30c1cea-7974-4b40-a74a-cfa7f55b14ae
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum a,b,c (age 12m)
    mgr: a(active, since 12m)
    mds: myfs:1 {0=myfs-a=up:active} 1 up:standby-replay
    osd: 3 osds: 3 up (since 12m), 3 in (since 3d)
 
  data:
    pools:   4 pools, 97 pgs
    objects: 36 objects, 30 MiB
    usage:   3.1 GiB used, 147 GiB / 150 GiB avail
    pgs:     97 active+clean
 
  io:
    client:   1.2 KiB/s rd, 2 op/s rd, 0 op/s wr
 
[root@rook-ceph-tools-564d97fcf5-rt4fn /]# ceph osd status
ID  HOST         USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE      
 0  k8s-node03  1067M  48.9G      0        0       0        0   exists,up  
 1  k8s-node04  1067M  48.9G      0        0       0       89   exists,up  
 2  k8s-node02  1067M  48.9G      0        0       0       15   exists,up
```

## 1.8 配置Ceph Dashboard

配置一个ingress资源，并hosts解析ceph.node1.com域名到已经部署ingress的节点ip上

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ceph-dash-board-ingress
  namespace: rook-ceph
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: ceph.node1.com
      http:
        paths:
          - backend:
              service:
                name: rook-ceph-mgr-dashboard
                port:
                  number: 7000
            path: /
            pathType: Prefix
```

查看ceph dashboard密码，默认用户名为admin

```bash
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 -d
```

## 1.9 Ceph块存储使用

块存储一般用于一个Pod挂载一块存储使用，相当于一个服务器新挂了一个盘，只给一个应用使用。

### 1.9.1 创建StorageClass和Ceph存储池

```
cd rook/cluster/examples/kubernetes/ceph/csi/rbd/
```

```bash
kubectl create -f storageclass.yaml
```

试验环境，所以将副本数设置成了2（不能设置为1），生产环境最少为3，且要小于等于osd的数量

![image.png](https://i.loli.net/2021/07/17/VP9asn2kExBMhKb.png)



查看创建的cephblockpool和storageClass（StorageClass没有namespace隔离性）

```bash
[root@k8s-master01 ~]# kubectl  get cephblockpool -n rook-ceph
NAME          AGE
replicapool   3d20h
[root@k8s-master01 ~]# kubectl  get storageclasses.storage.k8s.io 
NAME              PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   3d20h
```

此时可以在ceph dashboard查看到改Pool，如果没有显示说明没有创建成功

![image.png](https://i.loli.net/2021/07/17/wSg6FfMK8ARTr5Y.png)

### 1.9.2 挂载测试

#### 创建测试资源

使用rook官方的mysql实例

```bash
cd rook/cluster/examples/kubernetes
```

```bash
kubectl create -f mysql.yaml -n default
```

#### 示例pvc

其中pvc段的配置：

pvc会连接刚才创建的名为rook-ceph-block的storageClass，然后动态创建pv，然后连接到ceph创建对应的存储，之后创建pvc只需要指定storageClassName为刚才创建的StorageClass名称即可连接到rook的ceph。如果是statefulset，只需要将volumeTemplateClaim里面的Claim名称改为StorageClass名称即可动态创建Pod。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
  labels:
    app: wordpress
spec:
  storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

其中MySQL deployment的volumes配置挂载了该pvc：

claimName为pvc的名称，因为MySQL的数据不能多个MySQL实例连接同一个存储，所以一般只能用块存储。相当于新加了一块盘给MySQL使用。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
    tier: mysql
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: mysql
    spec:
      containers:
        - image: mysql:5.6
          name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: changeme
          ports:
            - containerPort: 3306
              name: mysql
          volumeMounts:
            - name: mysql-persistent-storage
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-persistent-storage
          persistentVolumeClaim:
            claimName: mysql-pv-claim
```



#### 进入容器查看挂载情况

可以看到设备名为`/dev/rbd0`的设备挂载到了`/var/lib/mysql`路径下

```bash
[root@k8s-master01 ~]# kubectl exec -it wordpress-mysql-6965fc8cc8-xnntw -- bash
root@wordpress-mysql-6965fc8cc8-xnntw:/# df -hT
Filesystem     Type     Size  Used Avail Use% Mounted on
overlay        overlay   50G  9.6G   41G  20% /
tmpfs          tmpfs     64M     0   64M   0% /dev
tmpfs          tmpfs    3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/sda2      xfs       50G  9.6G   41G  20% /etc/hosts
shm            tmpfs     64M     0   64M   0% /dev/shm
/dev/rbd0      ext4      20G  160M   20G   1% /var/lib/mysql
tmpfs          tmpfs    3.9G   12K  3.9G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs          tmpfs    3.9G     0  3.9G   0% /proc/acpi
tmpfs          tmpfs    3.9G     0  3.9G   0% /proc/scsi
tmpfs          tmpfs    3.9G     0  3.9G   0% /sys/firmware
```

#### Dashboard查看创建的rbd

![image.png](https://i.loli.net/2021/07/17/lk8vGduNK6Pzw1T.png)

#### StatefulSet资源使用sc

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: nginx:1.18.0
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "rook-ceph-block"
      resources:
        requests:
          storage: 1Gi
```

## 1.10 共享型文件系统的使用

共享文件系统一般用于多个Pod共享一个存储

官方文档：https://rook.io/docs/rook/v1.6/ceph-filesystem.html

### 1.10.1 创建共享类型的文件系统

```bsh
cd rook/cluster/examples/kubernetes/ceph
```

```bash
kubectl  create -f filesystem.yaml
```

创建完成后会启动mds容器，需要等待启动后才可进行创建pv

```bash
[root@k8s-master01 ceph]# kubectl -n rook-ceph get pod -l app=rook-ceph-mds
NAME                                    READY   STATUS    RESTARTS   AGE
rook-ceph-mds-myfs-a-9bb754885-bwqfs    1/1     Running   6          2d22h
rook-ceph-mds-myfs-b-7f7964cf95-9f92c   1/1     Running   6          2d22h
```

在Dashboard查看创建状态

![image.png](https://i.loli.net/2021/07/17/rcXTkQNJiE6FHCy.png)

### 1.10.2 创建共享类型文件系统的StorageClass

```bash
cd rook/cluster/examples/kubernetes/ceph/csi/cephfs
```

```bash
kubectl create -f storageclass.yaml
```

之后将pvc的storageClassName设置成rook-cephfs即可创建共享文件类型的存储，类似于NFS，可以给多个Pod共享数据。

查看刚刚创建的StorageClass

```
[root@k8s-master01 ceph]# kubectl get storageclasses.storage.k8s.io 
NAME              PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   3d20h
rook-cephfs       rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   2d22h
```

### 1.10.3 挂载测试

配置一个nginx的deployment资源

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nginx-share-pvc
spec:
  storageClassName: rook-cephfs  # 上一步创建的共享文件系统的StorageClass
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment 
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.18.0 
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
      volumes:
        - name: www
          persistentVolumeClaim:
            claimName: nginx-share-pvc
```

查看pod

```bash
[root@k8s-master01 kubernetes]# kubectl get pod 
NAME                   READY   STATUS    RESTARTS   AGE
web-86767949db-86qwf   1/1     Running   0          67s
web-86767949db-jggck   1/1     Running   0          67s
web-86767949db-m54zz   1/1     Running   0          67s
```

进入pod查看挂载情况

```bash
[root@k8s-master01 kubernetes]# kubectl exec -it web-86767949db-86qwf -- bash
root@web-86767949db-86qwf:/# df -hT
Filesystem                                                                                                                                             Type     Size  Used Avail Use% Mounted on
overlay                                                                                                                                                overlay   50G  9.6G   41G  20% /
tmpfs                                                                                                                                                  tmpfs     64M     0   64M   0% /dev
tmpfs                                                                                                                                                  tmpfs    3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/sda2                                                                                                                                              xfs       50G  9.6G   41G  20% /etc/hosts
shm                                                                                                                                                    tmpfs     64M     0   64M   0% /dev/shm
10.99.238.186:6789,10.110.4.86:6789,10.107.135.194:6789:/volumes/csi/csi-vol-85ceb84b-e705-11eb-8fc1-92506c83a87e/dbd09ecd-825b-482f-9795-016187f126b8 ceph     1.0G     0  1.0G   0% /usr/share/nginx/html
tmpfs                                                                                                                                                  tmpfs    3.9G   12K  3.9G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                                                                                                                  tmpfs    3.9G     0  3.9G   0% /proc/acpi
tmpfs                                                                                                                                                  tmpfs    3.9G     0  3.9G   0% /proc/scsi
tmpfs                                                                                                                                                  tmpfs    3.9G     0  3.9G   0% /sys/firmware
```

## 1.11 PVC扩容

### 1.11.1 扩容要求

- 文件共享类型的PVC扩容需要k8s 1.15+

- 块存储类型的PVC扩容需要k8s 1.16+

- PVC扩容需要开启ExpandCSIVolumes

  新版本的k8s已经默认打开了这个功能，可以查看自己的k8s版本是否已经默认打开了该功能

  ```bash
  [root@k8s-master01 ~]# kube-apiserver -h |grep ExpandCSIVolumes
                                                       ExpandCSIVolumes=true|false (BETA - default=true)
  ```

### 1.11.2 扩容文件共享型PVC

```bash
kubectl edit storageclasses.storage.k8s.io rook-cephfs
```

allowVolumeExpansion设为true，如已经是true则不需要修改



找到之前创建的pvc，直接edit修改大小即可

```bash
[root@k8s-master01 ~]# kubectl get pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nginx-share-pvc   Bound    pvc-aef15a1e-b5c6-4625-b051-4677562c2a0a   1Gi        RWX            rook-cephfs    7m24s
[root@k8s-master01 ~]# kubectl edit persistentvolumeclaims nginx-share-pvc
```

```yaml
....
status:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 2Gi # 由原来1G扩容为2G
  phase: Bound
```

### 1.11.3 扩容块存储类型

扩容方法和文件系统类型一样，不再详细描述

## 1.12 PVC快照

### 1.12.1 创建SnapshotClass

#### 块存储类型SnapshotClass

```bash
cd rook/cluster/examples/kubernetes/ceph/csi/rbd
```

```bash
kubectl create -f snapshotclass.yaml
```

#### 文件系统类型SnapshotClass

```bash
cd rook/cluster/examples/kubernetes/ceph/csi/cephfs
```

```
kubectl create -f snapshotclass.yaml
```

#### 查看SnapshotClass

```bash
[root@k8s-master01 cephfs]# kubectl get volumesnapshotclasses.snapshot.storage.k8s.io 
NAME                         DRIVER                          DELETIONPOLICY   AGE
csi-cephfsplugin-snapclass   rook-ceph.cephfs.csi.ceph.com   Delete           10h
csi-rbdplugin-snapclass      rook-ceph.rbd.csi.ceph.com      Delete           2m15s
```

### 1.12.2 创建快照

#### 块存储类型快照

首先在之前创建的MySQL容器里创建一个文件夹，并创建一个文件

```bash
[root@k8s-master01 cephfs]# kubectl exec -it wordpress-mysql-6965fc8cc8-rmkvg -- bash
root@wordpress-mysql-6965fc8cc8-rmkvg:/# cd /var/lib/mysql
root@wordpress-mysql-6965fc8cc8-rmkvg:/var/lib/mysql# ls
auto.cnf  ib_logfile0  ib_logfile1  ibdata1  lost+found  mysql	performance_schema
root@wordpress-mysql-6965fc8cc8-rmkvg:/var/lib/mysql# echo "hahahaha" > 1.txt
```
进入示例目录

```bash
cd rook/cluster/examples/kubernetes/ceph/csi/rbd
```
修改snapshot.yaml文件的source pvc为创建的MySQL pvc：

```bash
[root@k8s-master01 rbd]# kubectl get pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mysql-pv-claim    Bound    pvc-891b64a3-cb62-411b-b33e-fdec86264fa8   20Gi       RWO            rook-ceph-block   9m5s
```

```yaml
---
# 1.17 <= K8s <= v1.19
# apiVersion: snapshot.storage.k8s.io/v1beta1
# K8s >= v1.20
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: rbd-pvc-snapshot
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass
  source:
    persistentVolumeClaimName: mysql-pv-claim # 修改为之前创建的mysql pvc的名字
```

创建快照

```bash
[root@k8s-master01 rbd]# kubectl create -f snapshot.yaml 
volumesnapshot.snapshot.storage.k8s.io/rbd-pvc-snapshot created
```

查看创建的快照

```bash
[root@k8s-master01 rbd]# kubectl get volumesnapshot
NAME               READYTOUSE   SOURCEPVC        SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS             SNAPSHOTCONTENT                                    CREATIONTIME   AGE
rbd-pvc-snapshot   true         mysql-pv-claim                           20Gi          csi-rbdplugin-snapclass   snapcontent-ea8defd7-1052-4dbe-9137-334a177ed988   59s            59s
```

查看当前snapshot的VolumeSnapshotContent

```bash
[root@k8s-master01 ~]# kubectl get volumesnapshot rbd-pvc-snapshot -o yaml
....
status:
  boundVolumeSnapshotContentName: snapcontent-ea8defd7-1052-4dbe-9137-334a177ed988
  creationTime: "2021-07-17T14:28:27Z"
  readyToUse: true
  restoreSize: 20Gi
```

```bash
[root@k8s-master01 rbd]# kubectl get volumesnapshotcontents.snapshot.storage.k8s.io snapcontent-ea8defd7-1052-4dbe-9137-334a177ed988 -o yaml
....
status:
  creationTime: 1626532107952843598
  readyToUse: true
  restoreSize: 21474836480
  snapshotHandle: 0001-0009-rook-ceph-0000000000000002-4049c8bd-e70b-11eb-9f7b-b6bac0f37cc5 # 这个和dashboard中的snapshot name对应
```

Dashboard查看刚刚创建的rbd类型的snapshot

![image.png](https://i.loli.net/2021/07/17/aDH5BPeZVXvunSY.png)

#### 文件系统类型快照

在之前创建的nginx deployment资源中，随便一个Pod创建文件

```bash
[root@k8s-master01 rbd]# kubectl exec -it web-86767949db-ghb5m -- bash
root@web-86767949db-ghb5m:/# cd /usr/share/nginx/html/
root@web-86767949db-ghb5m:/usr/share/nginx/html# echo "test" > index.html
root@web-86767949db-ghb5m:/usr/share/nginx/html# ls
index.html
root@web-86767949db-ghb5m:/usr/share/nginx/html# cat index.html 
test
```

进入示例目录

```bash
rook/cluster/examples/kubernetes/ceph/csi/cephfs
```

修改snapshot.yaml文件的source pvc为创建的nginx deployment

```bash
[root@k8s-master01 cephfs]# kubectl get persistentvolumeclaims 
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
nginx-share-pvc   Bound    pvc-9e68f87c-980e-4672-8cd7-bd43a5790b24   1Gi        RWX            rook-cephfs       7m4s
```

```yaml
---
# 1.17 <= K8s <= v1.19
# apiVersion: snapshot.storage.k8s.io/v1beta1
# K8s >= v1.20
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: cephfs-pvc-snapshot
spec:
  volumeSnapshotClassName: csi-cephfsplugin-snapclass
  source:
    persistentVolumeClaimName: nginx-share-pvc
```

创建快照

```bash
[root@k8s-master01 cephfs]# kubectl create -f snapshot.yaml 
volumesnapshot.snapshot.storage.k8s.io/cephfs-pvc-snapshot created
```

查看创建的快照

```bash
[root@k8s-master01 cephfs]# kubectl get volumesnapshot
NAME                  READYTOUSE   SOURCEPVC         SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS                SNAPSHOTCONTENT                                    CREATIONTIME   AGE
cephfs-pvc-snapshot   true         nginx-share-pvc                           1Gi           csi-cephfsplugin-snapclass   snapcontent-daa78b53-9f21-4f18-92c9-e98713eb26b3   6s             6s
```

Dashboard查看快照

![image.png](https://i.loli.net/2021/07/17/38T659QugXWJZqY.png)

## 1.13 指定快照创建PVC

如果想要创建一个具有某个数据的PVC，可以从某个快照恢复，然后获取到误删除的文件，拷回原来路径，相当于回滚。

以块存储类型快照创建PVC为例，从文件系统类型快照创建基本相同，没有演示。

### 1.13.1 从快照创建PVC

如果想要创建一个具有某个数据的PVC，可以从某个快照恢复

```bash
vim pvc-restore.yaml
```

**注意：dataSource为快照名称，storageClassName为新建pvc的storageClass，storage的大小不能低于原pvc的大小**

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbd-pvc-restore
spec:
  storageClassName: rook-ceph-block
  dataSource:
    name: rbd-pvc-snapshot # 指定快照名称
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi # 不能低于原来PVC的大小
```

创建PVC

```bash
kubectl create -f pvc-restore.yaml
```

查看从快照创建的PVC

```bash
[root@k8s-master01 rbd]# kubectl get pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mysql-pv-claim    Bound    pvc-891b64a3-cb62-411b-b33e-fdec86264fa8   20Gi       RWO            rook-ceph-block   61m
nginx-share-pvc   Bound    pvc-9e68f87c-980e-4672-8cd7-bd43a5790b24   1Gi        RWX            rook-cephfs       17m
rbd-pvc-restore   Bound    pvc-f03d1b0e-97fe-4c24-8b85-47c97fccf42d   20Gi       RWO            rook-ceph-block   2s
```

### 1.13.2 数据校检

创建一个容器，挂载该PVC，查看是否含有之前的文件

```bash
vim restore-check-snapshot-rbd.yaml 
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: check-snapshot-restore
spec:
  selector:
    matchLabels:
      app: check 
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: check 
    spec:
      containers:
      - image: busybox
        name: check
        command:
        - sh
        - -c
        - sleep 36000
        volumeMounts:
        - name: check-mysql-persistent-storage
          mountPath: /mnt
      volumes:
      - name: check-mysql-persistent-storage
        persistentVolumeClaim:
          claimName: rbd-pvc-restore
```

进入容器查看文件是否存在

```bash
[root@k8s-master01 rbd]# kubectl exec -it check-snapshot-restore-6d44c74bc6-mbh2p -- sh
/ # ls /mnt/
1.txt               ib_logfile0         ibdata1             mysql
auto.cnf            ib_logfile1         lost+found          performance_schema
```

## 1.14 PVC克隆

进入示例目录

```bash
cd rook/cluster/examples/kubernetes/ceph/csi/rbd
```

编辑克隆资源文件

```bash
vim pvc-clone.yaml
```

需要注意的是pvc-clone.yaml的dataSource的name是被克隆的pvc名称，在此是mysql-pv-claim，storageClassName为新建pvc的storageClass名称，storage不能小于之前pvc的大小。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim-clone # 克隆的新的PVC的名称，不能和之前重复
spec:
  storageClassName: rook-ceph-block # 新建PVC的storageClass
  dataSource:
    name: mysql-pv-claim # 源PVC的名称
    kind: PersistentVolumeClaim
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi #不能小于被克隆的PVC大小
```

```bash
[root@k8s-master01 rbd]# kubectl create -f pvc-clone.yaml 
persistentvolumeclaim/mysql-pv-claim-clone created
[root@k8s-master01 rbd]# kubectl get pvc
NAME                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mysql-pv-claim         Bound    pvc-891b64a3-cb62-411b-b33e-fdec86264fa8   20Gi       RWO            rook-ceph-block   81m
mysql-pv-claim-clone   Bound    pvc-974db5d3-08bb-4595-a1e5-da7ebb1cbba0   20Gi       RWO            rook-ceph-block   3s
```

