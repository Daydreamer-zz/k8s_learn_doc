# k8s Service

## 1.1 Service概念

Service可以简单的理解为逻辑上的一组pod。一种可以访问pd的策略，而且其他pod可以通过这个service访问到这个service代理的pod。相对于pod而言，他会有一个固定的名称，一旦创建就会固定不变。

统一namespace下直接访问service名称即可访问，不同namespace下，访问格式为`sevicename.namespace`

## 1.2 创建一个Service

nginx-deployment-service.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
  labels:
    app: nginx
spec:
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.18.0
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  namespace: default
  name: nginx-svc
  labels:
    app: nginx-svc
spec:
  selector:
    app: nginx
  type: ClusterIP
  ports:
    - name: http # Service端口名称
      port: 80 # Service暴露的端口号
      protocol: TCP # TCP UDP SCMP 默认是TCP
      targetPort: 80 # 后端应用的端口
    - name: https
      port: 443
      protocol: TCP
      targetPort: 443
```

## 1.3 使用Service代理k8s集群外部应用

### 1.3.1 使用场景：

- 希望在生产环境中使用某个固定的名称而非IP地址进行访问外部的中间件服务

- 希望Service指向另一个Namespace中或其他集群中的服务
- 某个项目正在迁移至k8s集群，但是一部分服务仍然在集群外部，此时可以使用service代理至k8s集群外部的服务

### 1.3.2 定义一个集群外部Service资源

nginx-svc-external.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc-external
  namespace: default
  labels:
    app: nginx-svc-external
spec:
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: nginx-svc-external
  namespace: default
  labels:
    app: nginx-svc-external  # 和上面的Service label需保持一致，否则无法建立关联关系
subsets:
  - addresses:
      - ip: 39.105.62.80
    ports:
      - name: http
        port: 80
        protocol: TCP
```

## 1.4 Service反代域名

nginx-externalName.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: baidu
  labels:
    app: baidu
spec:
  type: ExternalName
  externalName: www.baidu.com
```

## 1.5 Service常见类型

- ClusterIP：在集群内部使用，也是默认值
- ExternalName：返回自定义的CNAME别名
- NodePort：在所有安装了kube-proxy的节点上打开一个端口，此端口可以代理至后端Pod，然后集群外部可以使用节点的IP地址和NodePort的端口号访问到集群Pod的服务。NodePort端口范围默认是30000-32767
- LoadBalancer：使用公有云厂商提供的负载均衡器对外公开服务，如：阿里云SLB、腾讯云ELB