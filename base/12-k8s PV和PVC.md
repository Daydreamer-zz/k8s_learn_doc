# k8s PV和PVC

## 1.1 volume无法解决的问题

- 当某个数据卷不再被挂载使用时，里面的数据如何处理？
- 如果想要实现只读挂载如何处理？
- 如果想要只能一个Pod挂载如何处理？
- 如何只允许某个Pod使用10G的空间？

## 1.2 PV概念

PersistentVolume：简称PV，是由Kubernetes管理员设置的存储，可以配置Ceph、NFS、GlusterFS等常用存储配置，相对于Volume配置，提供了更多的功能，比如生命周期的管理、大小的限制。PV分为静态和动态。
PersistentVolumeClaim：简称PVC，是对存储PV的请求，表示需要什么类型的PV，需要存储的技术人员只需要配置PVC即可使用存储，或者Volume配置PVC的名称即可。

官方文档：https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/

## 1.3 PV的回收策略

- Retain：保留，该策略允许手动回收资源，当删除PVC时，PV仍然存在，PV被视为已释放，管理员可以手动回收卷。
- Recycle：回收，如果Volume插件支持，Recycle策略会对卷执行`rm -rf `清理该PV，并使其可用于下一个新的PVC，但是本策略将来会被弃用，目前只有NFS和HostPath支持该策略
- Delete：删除，如果Volume插件支持，删除PVC时会同时删除PV，动态卷默认为Delete，目前支持Delete的存储后端包括AWS EBS, GCE PD, Azure Disk, or OpenStack Cinder等

官方文档：https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/#reclaiming

## 1.4 PV的访问策略

PersistentVolume 卷可以用资源提供者所支持的任何方式挂载到宿主系统上。 如下表所示，提供者（驱动）的能力不同，每个 PV 卷的访问模式都会设置为 对应卷所支持的模式值。 例如，NFS 可以支持多个读写客户，但是某个特定的 NFS PV 卷可能在服务器 上以只读的方式导出。每个 PV 卷都会获得自身的访问模式集合，描述的是 特定 PV 卷的能力

- ReadWriteOnce：卷可以被一个节点以读写方式挂载，命令行接口中缩写为：RWO
- ReadOnlyMany：卷可以被多个节点以只读方式挂载，命令行接口中缩写为：ROX 
- ReadWriteMany：卷可以被多个节点以读写方式挂载，命令行接口中缩写为：RWX

官网：https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/#access-modes

## 1.5 存储分类

- 文件存储：一些数据可能需要被多个节点使用，比如用户的头像、用户上传的文件等，实现方式：NFS、NAS、FTP、CephFS等
- 块存储：一些数据只能被一个节点使用，或者是需要将一块裸盘整个挂载使用，比如数据库、Redis等，实现方式：Ceph、GlusterFS、公有云
- 对象存储：由程序代码直接实现的一种存储方式，云原生应用无状态化常用的实现方式，实现方式：一般是符合S3协议的云存储，比如AWS的S3存储、Minio、七牛云等

## 1.6 PV的状态

- Available：可用，没有被PVC绑定的空闲资源
- Bound：已绑定，已经被PVC绑定
- Released：已释放，PVC被删除，但是资源还未被重新使用
- Failed：失败，自动回收失败

## 1.7 PV配置示例

### 1.7.1 NFS/NAS

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem # 卷的模式，目前只支持Filesystem和Block
  accessModes:
    - ReadWriteOnce
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain # 数据回收策略
  storageClassName: pv-nfs # 存储类的名称，pvc绑定pv需要指定这个名称，而不是metadata中的name
  nfs:
    path: /data/k8s
    server: 192.168.2.7
```

### 1.7.2 HostPath

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  storageClassName: pv-hostpath
  persistentVolumeReclaimPolicy: Retain
  accessModes:
    - ReadWriteOnce
    - ReadOnlyMany
  hostPath:
    path: /mnt/data
```

## 1.8 PV的请求PVC

demo-pvc.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name:  demo-pvc
spec:
  storageClassName: pv-nfs
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 3Gi
```

deployment-pvc.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-pvc
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        ingress: "true"
      volumes:
        - name: my-volume-pvc
          persistentVolumeClaim:
            claimName: demo-pvc
      containers:
        - name: nginx
          imagePullPolicy: IfNotPresent
          image: nginx:1.18.0
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - mountPath: /usr/share/nginx/html
              name: my-volume-pvc
          env:
            - name: TZ
              value: Asia/Shanghai
            - name: LANG
              value: C.UTF-8
```

## 1.9 PVC创建和挂载失败的原因

PVC一直pending的状态

- PVC的空间申请大小大于PV的大小
- PVC的StorageClassName没有和PV的一致
- PVC的accessModes和PV的不一致

挂载PVC的Pod一直处于Pending

- PVC没有创建成功/PVC不存在
- PVC和Pod不在同一个Namespace