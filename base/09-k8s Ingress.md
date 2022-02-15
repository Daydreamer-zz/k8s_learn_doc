# k8s Ingress

## 1.1 Ingress概念

通俗来讲，ingress和之前提到的Service、Deployment，也是一个k8s的资源类型，ingress用于实现用域名的方式访问k8s内部应用。

## 1.2 Ingress安装

推荐使用helm管理工具进行安装

### 1.2.1 下载helm

参考https://helm.sh/docs/intro/install/文档

### 1.2.2 添加ingress的helm仓库

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### 1.2.3 下载ingress的helm包至本地

```bash
helm pull ingress-nginx/ingress-nginx
```

### 1.2.4 更改对应配置

```bash
tar xf ingress-nginx-3.34.0.tgz
cd ingress-nginx
vim values.yaml
```

- Controller和admissionWebhook的镜像地址，需要将公网镜像同步至公司内网镜像仓库
- hostNetwork设置为true
- dnsPolicy设置为 ClusterFirstWithHostNet
- nodeSelector添加ingress: "true"部署至指定节点
- 类型更改为kind: DaemonSet
- metrics，enabled设为true

### 1.2.5 给需要部署Ingress的节点打标签

```bash
kubectl create namespace ingress-nginx
```

```bash
kubectl label nodes k8s-node01 k8s-node02  ingress=true
```

### 1.2.6 安装Ingress
通过修改value.yaml
```bash
helm install ingress-nginx -n ingress-nginx .
```
或者直接通过`helm install --set`
```bash
helm -n ingress-nginx  install ingress-nginx ingress-nginx/ingress-nginx   --set controller.hostNetwork=true --set controller.dnsPolicy=ClusterFirstWithHostNet --set-string  controller.nodeSelector.ingress=true --set controller.kind=DaemonSet --set controller.metrics.enabled=true --set controller.ingressClassResource.default=true --set controller.service.type=ClusterIP
```
## 1.3 Ingress入门使用

定义一个Ingress资源，需要搭配Service使用

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
    - host: node1.com
      http:
        paths:
          - backend:
              service:
                name: nginx-svc
                port:
                  number: 80
            path: /
            pathType: Prefix
---
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



