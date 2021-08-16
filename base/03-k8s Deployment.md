# k8s Deployment

## 1.1 Deployment概念
用于部署无状态服务，这个是最常用的控制器。一般用于管理维护企业内部无状态的微服务，比如：configserver、zuul、springboot。他可以管理多个副本的pod，实现无缝迁移、自动扩容缩容、自动灾难恢复、一键回滚等功能。
## 1.2 创建一个Deployment
### 1.2.1 手动创建一个Deployment

```bash
kubectl create deployment nginx --image=nginx:1.15.2
```

### 1.2.2 从yaml文件创建

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels: # 已经创建的deployment资源不允许修改lables
    app: nginx
spec:
  replicas: 3 # 副本数
  revisionHistoryLimit: 10 # 历史记录保留个数
  selector:  # 选择的标签
    matchLabels:
      app: nginx
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.15.2
        imagePullPolicy: IfNotPresent
        name: nginx
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      terminationGracePeriodSeconds: 30
```

### 1.2.3 状态解析

```bash
[root@k8s-master01 ~]# kubectl get deployments.apps -o wide
NAME    READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES         SELECTOR
nginx   3/3     3            3           100s   nginx        nginx:1.15.2   app=nginx
```

- NAME: Deployment的名称
- READY: Pod的状态，已经Ready的个数
- UP-TO-DATE: 已经达到期望状态的被更新的副本数
- AVAILABLE: 已经可以使用的副本数
- AGE: 显示应用程序运行的时间
- CONTAINERS: 容器的名称
- IMAGES: 容器的镜像
- SELECTOR: 管理的Pod的标签

## 1.3 Deploymen更新和回滚

### 1.3.1 Deployment更新

可以直接通过kubectl直接set该deployment的镜像版本，也可以通过修改yaml文件之后kubectl replace 

```bash
kubectl set image deployment nginx nginx=nginx:1.15.3 --record
```

### 1.3.2 Deployment回滚

#### 回滚到上一个版本

```bash
kubectl rollout undo deployment nginx
```

#### 回滚到指定版本

查看版本历史信息

```bash
[root@k8s-master01 ~]# kubectl rollout history deployment nginx 
deployment.apps/nginx 
REVISION  CHANGE-CAUSE
1         <none>
3         kubectl set image deployment nginx nginx=nginx:1.19.0 --record=true
5         kubectl set image deployment nginx nginx=nginx:1.15.3 --record=true
6         kubectl set image deployment nginx nginx=nginx:1.15.3 --record=true
```

查看某个版本具体镜像版本，例如3

```bash
[root@k8s-master01 ~]# kubectl rollout history deployment nginx --revision=3
deployment.apps/nginx with revision #3
Pod Template:
  Labels:	app=nginx
	pod-template-hash=85b45874d9
  Annotations:	kubernetes.io/change-cause: kubectl set image deployment nginx nginx=nginx:1.19.0 --record=true
  Containers:
   nginx:
    Image:	nginx:1.19.0 # 关键信息
    Port:	<none>
    Host Port:	<none>
    Environment:	<none>
    Mounts:	<none>
  Volumes:	<none>
```

回滚到指定版本

```bash
kubectl rollout undo deployment nginx --to-revision=3
```

## 1.4 Deployment扩容缩容

直接通过kubectl扩容

```bash
kubectl scale deployment nginx --replicas=6
```

## 1.5 Deployment暂停和恢复
在执行set的时候，每次set都会执行修改，如果需多次修改，可以先暂停更新此Deployment资源，修改完成后恢复Deployment更新

#### 暂停某Deployment的更新

```bash
kubectl rollout pause deployment nginx
```

#### 开始第一次配置变更(修改镜像版本)

```bash
kubectl set image deploy nginx nginx=nginx:1.18.0
```

#### 开始第二次配置变更(添加内存、cpu配置)
- requests：容器启动所需最小到的内存和cpu使用量
- limits：容器所需最大到的内存和cpu使用量

```bash
kubectl set resources deployment nginx -c nginx --limits=cpu=200m,memory=128Mi --requests=cpu=10m,memory=16Mi
```

#### 恢复该Deployment的更新

```bash
kubectl rollout resume deployment nginx
```

## 1.6 Deployment资源yaml关键字段补充

### .spec.revisionHistoryLimit

设置保留replicasets旧的reversion的个数，设置为0的话，不保留历史数据

### .spec.minReadySeconds

可选参数，指定新创建的Pod在没有任何容器崩溃的情况下视为Ready的最小秒数，默认为0，即：一旦创建就视为可用

### .spec.strategy

滚动更新策略

#### .spec.strategy.type

更新Deployment的方式，可以指定为rollingUpdate或者Recreate，默认是rollingUpdate

#### .spec.strategy.rollingUpdate

滚动更新，可以指定maxSurge和maxUnavailable

- .spec.strategy.rollingUpdate.maxUnavailable：指定在回滚和更新时最低不可用的Pod数量，可选字段，默认为25%，可以设置为数字或百分比，如果改值为0，那么masSurge就不能0
- .spec.strategy.rollingUpdate.maxSurge：可以超过期望值的最低Pod数，如果改值为0，那么maxUnavailable不能为0

#### .spec.strategy.Recreate

重建，先删除旧的Pod，再创建新的Pod
