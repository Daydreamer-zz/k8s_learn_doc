# k8s StatefulSet

## 1.1有状态应用管理StatefullSet

StatefulSet（有状态集，缩写为sts）,常用于部署有状态的且需要有序启动的应用程序，比如在进行Spring Cloud项目容器化时，Eureka的部署是比较适合用StatefulSet部署方式的，可以给每个Eureka实例创建一个唯一且固定的标识符，并且每个Eureka实例无需配置多余的Service，其余Spring Boot应用可以直接通过Eureka的Headless Service即可进行注册。

例如：

Eureka的statefulset的资源名称是eureka，eureka-0 eureka-1 eureka-2

Service：headless service，没有ClusterIP	eureka-svc

Eureka-0.eureka-svc.NAMESPACE_NAME  eureka-1.eureka-svc …

### 1.1.1 StatefulSet的基本概念

StatefulSet主要用于管理有状态应用程序的工作负载API对象。比如在生产环境中，可以部署ElasticSearch集群、MongoDB集群或者需要持久化的RabbitMQ集群、Redis集群、Kafka集群和ZooKeeper集群等。

和Deployment类似，一个StatefulSet也同样管理着基于相同容器规范的Pod。不同的是，StatefulSet为每个Pod维护了一个粘性标识。这些Pod是根据相同的规范创建的，但是不可互换，每个Pod都有一个持久的标识符，在重新调度时也会保留，一般格式为StatefulSetName-Number。比如定义一个名字是Redis-Sentinel的StatefulSet，指定创建三个Pod，那么创建出来的Pod名字就为Redis-Sentinel-0、Redis-Sentinel-1、Redis-Sentinel-2。而StatefulSet创建的Pod一般使用Headless Service（无头服务）进行通信，和普通的Service的区别在于Headless Service没有ClusterIP，它使用的是Endpoint进行互相通信，Headless一般的格式为：

statefulSetName-{0..N-1}.serviceName.namespace.svc.cluster.local

说明：

- serviceName为Headless Service的名字，创建StatefulSet时，必须指定Headless Service名称
- 0..N-1为Pod所在的序号，从0开始到N-1
- statefulSetName为StatefulSet的名字
- namespace为服务所在的命名空间
- .cluster.local为Cluster Domain（集群域）

### 1.1.2 StatefulSet注意事项

一般StatefulSet用于有以下一个或者多个需求的应用程序：

- 需要稳定的独一无二的网络标识符
- 需要持久化数据
- 需要有序的、优雅的部署和扩展
- 需要有序的自动滚动更新

如果应用程序不需要任何稳定的标识符或者有序的部署、删除或者扩展，应该使用无状态的控制器部署应用程序，比如Deployment或者ReplicaSet。

Pod所用的存储必须由PersistentVolume Provisioner（持久化卷配置器）根据请求配置StorageClass，或者由管理员预先配置，当然也可以不配置存储。

为了确保数据安全，删除和缩放StatefulSet不会删除与StatefulSet关联的卷，可以手动选择性地删除PVC和PV。

StatefulSet目前使用Headless Service（无头服务）负责Pod的网络身份和通信，需要提前创建此服务。

删除一个StatefulSet时，不保证对Pod的终止，要在StatefulSet中实现Pod的有序和正常终止，可以在删除之前将StatefulSet的副本缩减为0。

## 1.2 定义一个StatefulSet资源

定义一个简单的StatefulSet实例

nginx-sts.yaml

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
      app: nginx
  serviceName: "nginx"
  replicas: 4
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
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
```

其中：

- kind: Service定义了一个名字为Nginx的Headless Service，创建的Service格式为nginx-0.nginx.default.svc.cluster.local，其他的类似，因为没有指定Namespace（命名空间），所以默认部署在default
- kind: StatefulSet定义了一个名字为web的StatefulSet，replicas表示部署Pod的副本数，本实例为2

## 1.3 StatefulSet常用操作

### 创建StatefulSet

```bash
kubectl create -f nginx-sts.yaml
```

### 更改副本数

```bash
kubectl scale --replicas=3 sts web
```

## 1.4 解析操作无头Service

定义一个pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
```

进入busybox容器ping无头服务

```bash
[root@k8s-master01 ~]# kubectl exec -it busybox -- sh
/ # ping web-0.nginx.default.svc.cluster.local
PING web-0.nginx.default.svc.cluster.local (172.17.125.17): 56 data bytes
64 bytes from 172.17.125.17: seq=0 ttl=62 time=0.529 ms
64 bytes from 172.17.125.17: seq=1 ttl=62 time=0.446 ms
```

## 1.5 StatefulSet更新策略

### StatefulSet.spec.updateStrategy.type

- OnDelete

  更新策略设置为OnDelete时，用户必须手动删除 Pod 以便让控制器创建新的 Pod

- RollingUpdate（默认策略）

  更新策略对 StatefulSet 中的 Pod 执行自动的滚动更新

### StatefulSet.spec.updateStrategy.rollingUpdate

- partition（默认为0）

分区更新：通过声明 `.spec.updateStrategy.rollingUpdate.partition` 的方式，`RollingUpdate` 更新策略可以实现分区。 如果声明了一个分区，当 StatefulSet 的 `.spec.template` 被更新时， 所有序号大于等于该分区序号的 Pod 都会被更新。 所有序号小于该分区序号的 Pod 都不会被更新，并且，即使他们被删除也会依据之前的版本进行重建。 如果 StatefulSet 的 `.spec.updateStrategy.rollingUpdate.partition` 大于它的 `.spec.replicas`，对它的 `.spec.template` 的更新将不会传递到它的 Pod。 在大多数情况下，你不需要使用分区，但如果你希望进行阶段更新、执行金丝雀或执行 分阶段上线，则这些分区会非常有用



### 资源文件示例

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: default
spec:
  replicas: 4
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  serviceName: nginx
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.15.2
        imagePullPolicy: IfNotPresent
        name: nginx
        ports:
        - containerPort: 80
          name: web
          protocol: TCP
      terminationGracePeriodSeconds: 30
  updateStrategy:
    type: RollingUpdate	
    rollingUpdate:
      partition: 0 # tatefulSet 的 .spec.template 被更新时， 所有序号大于等于该分区序号的 Pod 都会被更新，0是所有pod都会更新
    
```

## 1.6 级联删除和非级联删除

### 概念

- 级联删除(默认)

  删除StatefulSet时，同时删除pod

- 非级联删除

  删除StatefulSet时，不删除pod

### 实现非级联删除

删除StatefulSet后，Pod变成了孤儿Pod，此时删除Pod不会被重建

```bash
kubectl delete statefulsets.apps web --cascade=false
```



