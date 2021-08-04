# k8s ConfigMap & Secret

## 1.1 ConfigMap概念

ConfigMap 是一种 API 对象，用来将非机密性的数据保存到键值对中。使用时， [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 可以将其用作环境变量、命令行参数或者存储卷中的配置文件。

ConfigMap 将您的环境配置信息和 [容器镜像](https://kubernetes.io/zh/docs/reference/glossary/?all=true#term-image) 解耦，便于应用配置的修改

## 1.2 创建ConfigMap的方式

```bash
kubectl create configmap -h
kubectl create cm cmfromdir --from-file=conf/
kubectl create cm cmfromfile --from-file=conf/redis.conf 
kubectl create cm cmspecialname --from-file=game-conf=game.conf
kubectl create cm cmspecialname2 --from-file=game-conf=game.conf  --from-file=redis-conf=redis.conf
kubectl create cm gameenvcm --from-env-file=game.conf
kubectl  create cm envfromliteral --from-literal=level=INFO --from-literal=PASSWORD=redis123
kubectl  create -f cm.yaml
```

## 1.3 在Pod中使用ConfigMap

### 1.3.1 env中使用valueFrom

demopod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demopod
spec:
  containers:
    - name: busybox
      imagePullPolicy: IfNotPresent
      image: busybox
      command:
        - sh
        - -c
        - "sleep 3600"
      env:
        - name: TEST_ENV
          value: testenv
        - name: LIVES
          valueFrom:
            configMapKeyRef:  # 从configmap中获取环境变量
              name: gameenvcm
              key: lives
        - name: test_env
          valueFrom:
           configMapKeyRef:
              name: gameenvcm
              key: test_env
```

### 1.3.2  使用envFrom

demo-envfrom.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demopod
spec:
  containers:
    - name: busybox
      imagePullPolicy: IfNotPresent
      image: busybox
      command:
        - sh
        - -c
        - "sleep 3600"
      envFrom:
        - configMapRef:
            name: gameenvcm
          prefix: fromcm_  # 指定前缀，和普通环境变量区分，一般不用
```

### 1.3.3 以文件形式挂载ConfigMap

userconfigmap-volume.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demopod
spec:
  volumes:  # 需定义单独的volumes段
    - name: redisconf
      configMap:
        name: redis-conf
    - name: cmfromfile
      configMap:
        name: cmfromfile
        
        # 自定义挂载权限和名称
        items:
          - key: redis.conf
            path: redis.conf.bak
          - key: redis.conf
            path: redis.conf.bak
            mode: 0644  # 单独定义权限比下面的defaultMode优先级高
        defaultMode: 0755
  containers:
    - name: busybox
      imagePullPolicy: IfNotPresent
      image: busybox
      command:
        - sh
        - -c
        - "sleep 3600"
      volumeMounts:
        - name: redisconf # 指定上面定义的volumes name
          mountPath: /etc/config  #指定挂载路径
        - name: cmfromfile
          mountPath: /etc/config2
```
## 1.4 使用SubPath解决挂载覆盖

subpath-demo.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  volumes:
    - name: nginxconf
      configMap:
        name: nginx.conf
  containers:
    - name: nginx
      image: nginx:1.18.0
      imagePullPolicy: IfNotPresent
      volumeMounts:
        - name: nginxconf
          mountPath: /etc/nginx/nginx.conf # 与subpath一起使用，指定完整配置文件路径，只挂载单独的文件，不会覆盖掉整个目录
          subPath: nginx.conf
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx.conf
data:
  nginx.conf: |2

    user  nginx;
    worker_processes  auto;

    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;


    events {
        worker_connections  512;
    }


    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;

        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';

        access_log  /var/log/nginx/access.log  main;

        sendfile        on;
        #tcp_nopush     on;

        keepalive_timeout  65;

        #gzip  on;

        include /etc/nginx/conf.d/*.conf;
    }

```



## 2.1 Secret概念

`Secret` 对象类型用来保存敏感信息，例如密码、OAuth 令牌和 SSH 密钥。 将这些信息放在 `secret` 中比放在 [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 的定义或者 [容器镜像](https://kubernetes.io/zh/docs/reference/glossary/?all=true#term-image) 中来说更加安全和灵活。

Secret 是一种包含少量敏感信息例如密码、令牌或密钥的对象。 这样的信息可能会被放在 Pod 规约中或者镜像中。 用户可以创建 Secret，同时系统也创建了一些 Secret。

要使用 Secret，Pod 需要引用 Secret。 Pod 可以用三种方式之一来使用 Secret：

- 作为挂载到一个或多个容器上的 [卷](https://kubernetes.io/zh/docs/concepts/storage/volumes/) 中的[文件](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod)。
- 作为[容器的环境变量](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-secrets-as-environment-variables)
- 由 [kubelet 在为 Pod 拉取镜像时使用](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-imagepullsecrets)

## 2.2 Secret常用类型

- Opaque：通用型Secret，默认类型；
- kubernetes.io/service-account-token：作用于ServiceAccount，包含一个令牌，用于标识API服务账户；
- kubernetes.io/dockerconfigjson：下载私有仓库镜像使用的Secret，和宿主机的/root/.docker/config.json一致，宿主机登录后即可产生该文件；
- kubernetes.io/basic-auth：用于使用基本认证（账号密码）的Secret，可以使用Opaque取代；
- kubernetes.io/ssh-auth：用于存储ssh密钥的Secret；
- kubernetes.io/tls：用于存储HTTPS域名证书文件的Secret，可以被Ingress使用；
- bootstrap.kubernetes.io/token：一种简单的 bearer token，用于创建新集群或将新节点添加到现有集群，在集群安装时可用于自动颁发集群的证书

## 2.3 使用Secret拉取私有镜像仓库镜像

### 2.3.1 创建Secret

```bash
kubectl create secret docker-registry my-docker-secret  --docker-server=registry.cn-qingdao.aliyuncs.com --docker-username=shz1997@hotmail.com --docker-password=xxxxxxxxx --docker-email=shz1997@hotmail.com
```

### 2.3.2 资源文件中引用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: renrenshop
spec:
  imagePullSecrets: # 镜像拉取Secret
    - name: aliyun  # 会和containers中的image地址匹配
  containers:
    - name: renrenshop
      image: registry.cn-qingdao.aliyuncs.com/elinkint/renrenshop_nginx_php:v2
      imagePullPolicy: IfNotPresent
      env:
        - name: SERVERNAME
          value: node1.com
```

## 2.4 使用Secret管理https证书

### 2.4.1 openssl生成测试https证书

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=node1.com"
```

### 2.4.2 导入证书文件Secret

```bash
kubectl create secret tls node1.com --key=tls.key --cert=tls.crt
```

### 2.4.3 Ingress资源使用该Secret

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-https-secret
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
  tls: # 和rules是同级字段
    - hosts:
        - node1.com  # 指定域名
      secretName: node1.com # 指定tls类型的Secret name
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

## 3.1 ConfigMap & Secret热更新

```bash
kubectl create configmap nginx.conf --from-file=nginx.conf --dry-run=client -o yaml|kubectl replace -f -
```



## 3.2 ConfigMap & Secret使用限制

- 提前创建ConfigMap和Secret
- 引用Key必须存在
- envFrom、valueFrom无法热更新环境变量
- envFrom配置环境变量，如果key是无效的，它会忽略掉无效的key
- ConfigMap和Secret必须要和Pod或者是引用它资源在同一个命名空间
- subPath也是无法热更新的
- ConfigMap和Secret最好不要太大

## 3.3 不可变的ConfigMap和Secret

### 3.3.1不可变ConfiMap和Secret概念

Kubernetes 特性 *不可变更的 Secret 和 ConfigMap* 提供了一种将各个 Secret 和 ConfigMap 设置为不可变更的选项。对于大量使用 ConfigMap 的 集群（至少有数万个各不相同的 ConfigMap 给 Pod 挂载）而言，禁止更改 ConfigMap 的数据有以下好处：

- 保护应用，使之免受意外（不想要的）更新所带来的负面影响。
- 通过大幅降低对 kube-apiserver 的压力提升集群性能，这是因为系统会关闭 对已标记为不可变更的 ConfigMap 的监视操作。

### 3.3.2 创建不可变ConfigMap或Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  ...
data:
  ...
immutable: true  # 单独添加此字段即为不可变
```

