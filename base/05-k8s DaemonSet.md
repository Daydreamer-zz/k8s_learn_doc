# k8s DaemonSet

## 1.1 概念

DaemonSet：守护进程集，缩写为ds，在所有节点或者是匹配的节点上都部署一个Pod。

应用场景：

- 运行集群存储的daemon，比如：Ceph、glusterd

- 节点的CNI网络插件：calico

- 节点日志收集：fluentd、filebeat

- 节点的监控：Node exporter

- 服务暴露：部署一个ingress nginx



## 1.2 创建一个DaemonSet

### node节点打标签

```bash
kubectl label nodes k8s-node01 k8s-node02 ds=true
```

### 定义DaemonSet资源文件

nginx-ds.yaml

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        ds: "true"  # 节点按上一步打的标签进行选择，注意true是个字符串
      containers:
      - image: nginx:1.18.0
        imagePullPolicy: IfNotPresent
        name: nginx
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
```

## 1.3 DaemonSet更新和回滚

Statefulset和DaemonSet更新回滚和Deployment一致

字段和StatefulSet不同的是，DaemonSet更新策略字段是`updateStrategy`

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        ds: "true"
      containers:
      - image: nginx:1.18.0
        imagePullPolicy: IfNotPresent
        name: nginx
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
  updateStrategy: # 更新策略字段，推荐使用OnDelete，避免对整个集群造成较大影响
    type: OnDelete
#  updateStrategy:
#    type: RollingUpdate
#    rollingUpdate:
#      maxUnavailable: 1

```



