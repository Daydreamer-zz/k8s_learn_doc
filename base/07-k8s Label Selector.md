# k8s Label Selector

## 1.1 Label和Selector

当Kubernetes对系统的任何API对象如Pod和节点进行“分组”时，会对其添加Label（key=value形式的“键-值对”）用以精准地选择对应的API对象。而Selector（标签选择器）则是针对匹配对象的查询方法。注：键-值对就是key-value pair。

例如，常用的标签tier可用于区分容器的属性，如frontend、backend；或者一个release_track用于区分容器的环境，如canary、production等。

## 1.2 定义Label

### 1.2.1 node节点加标签

```bash
kubectl lable node k8s-node01 region=subnet7
```

### 1.2.2 按标签筛选node节点

```bash
kubectl get nodes -l region=subnet7
```

### 1.2.3 在Deployment资源文件中应用

```yaml
containers:
  ......
dnsPolicy: ClusterFirst
nodeSelector:  # node选择器
  region: subnet7
restartPolicy: Always
......
```

## 1.3 Selector条件匹配

Selector主要用于资源的匹配，只有符合条件的资源才会被调用或使用，可以使用该方式对集群中的各类资源进行分配。

假如对Selector进行条件匹配，目前已有的Label如下：

```bash
[root@k8s-master01 ~]# kubectl get svc --show-labels
NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE     LABELS
details       ClusterIP   10.99.9.178      <none>        9080/TCP   45h     app=details
kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    3d19h   component=apiserver,provider=kubernetes
nginx         ClusterIP   10.106.194.137   <none>        80/TCP     2d21h   app=productpage,version=v1
nginx-v2      ClusterIP   10.108.176.132   <none>        80/TCP     2d20h   <none>
productpage   ClusterIP   10.105.229.52    <none>        9080/TCP   45h     app=productpage,tier=frontend
ratings       ClusterIP   10.96.104.95     <none>        9080/TCP   45h     app=ratings
reviews       ClusterIP   10.102.188.143   <none>        9080/TCP   45h     app=reviews

```

选择app为reviews或者productpage的svc：

```bash
[root@k8s-master01 ~]# kubectl get svc -l  'app in (details, productpage)' --show-labels
NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE     LABELS
details       ClusterIP   10.99.9.178      <none>        9080/TCP   45h     app=details
nginx         ClusterIP   10.106.194.137   <none>        80/TCP     2d21h   app=productpage,version=v1
productpage   ClusterIP   10.105.229.52    <none>        9080/TCP   45h     app=productpage,tier=frontend

```

选择app为productpage或reviews但不包括version=v1的svc：

```bash
[root@k8s-master01 ~]# kubectl get svc -l  version!=v1,'app in (details, productpage)' --show-labels
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   LABELS
details       ClusterIP   10.99.9.178     <none>        9080/TCP   45h   app=details
productpage   ClusterIP   10.105.229.52   <none>        9080/TCP   45h   app=productpage,tier=frontend

```

## 1.4 修改标签(Label)

### 删除标签

只需在标签后加`-`即可

```bash
kubectl label pod busybox app=busybox
```

```
kubectl label pod busybox app-
```

### 修改标签

添加`--overwrite`参数

```bash
kubectl label pod busybox app=busybox
```

```bash
kubectl label pod busybox app=tool --overwrite
```





