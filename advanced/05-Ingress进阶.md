# Ingress进阶

ingress主要通过注解的方式生成Nginx的配置文件，以如下为deployment资源为例测试

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
```



## 1.Redirect

nginx.ingress.kubernetes.io/permanent-redirect

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/permanent-redirect: https://www.baidu.com #调整到指定url
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
```

## 2.Rewrite

nginx.ingress.kubernetes.io/rewrite-target

在这个入口定义中，由 (.*) 捕获的任何字符都将分配给占位符 $2，然后将其用作 rewrite-target 注释中的参数

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2 # $2为something后的内容
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
            path: /something(/|$)(.*) #正则匹配
            pathType: Prefix
```

例如，上面的入口定义将导致以下重写：

- `node1.com/something` rewrites to `node1.com/`
- `node1.com/something/` rewrites to `node1.com/`
- `node1.com/something/new` rewrites to `node1.com/new`

## 3.SSL

nginx.ingress.kubernetes.io/ssl-redirect

#### OpenSSL生成测试https证书

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=node1.com"
```

#### 导入证书文件Secret

```bash
kubectl create secret tls node1.com --key=tls.key --cert=tls.crt
```

#### Ingress中使用

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false" #设为false不强制https，默认为true
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
  tls:
    - hosts:
        - node1.com #域名，证书需要和域名匹配
      secretName: node1.com  #指定tls类型的secret
```

#### Dashboard配置自定义证书

将正规机构颁发的证书创建为tls类型的secret然后修改dashboard的deployment资源

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
        - name: kubernetes-dashboard
          image: kubernetesui/dashboard:v2.3.1
          imagePullPolicy: Always
          ports:
            - containerPort: 8443
              protocol: TCP
          args:
            - --auto-generate-certificates=false
            - --tls-key-file=tls.key #secret证书对应的私钥文件名
            - --tls-cert-file=tls.crt #secret证书对应的公钥文件名
            - --namespace=kubernetes-dashboard
            # Uncomment the following line to manually specify Kubernetes API server Host
            # If not specified, Dashboard will attempt to auto discover the API server and connect
            # to it. Uncomment only if the default does not work.
            # - --apiserver-host=http://my-address:port
          volumeMounts:
            - name: kubernetes-dashboard-certs
              mountPath: /certs
              # Create on-disk volume to store exec logs
            - mountPath: /tmp
              name: tmp-volume
          livenessProbe:
            httpGet:
              scheme: HTTPS
              path: /
              port: 8443
            initialDelaySeconds: 30
            timeoutSeconds: 30
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsUser: 1001
            runAsGroup: 2001
      volumes:
        - name: kubernetes-dashboard-certs
          secret:
            secretName: kubernetes-dashboard-certs #直接将dashboard域名的证书创建为名为kubernetes-dashboard-certs的secret
        - name: tmp-volume
          emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      nodeSelector:
        "kubernetes.io/os": linux
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
```

#### 为dashboard添加ingress资源

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true" #ingress-nginx不去进行证书校检
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" #后端服务请求采用https
spec:
  rules:
    - host: dash.node1.com
      http:
        paths:
          - backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 443
            path: /
            pathType: Prefix
  tls:
    - hosts:
        - dash.node1.com #域名，证书需要和域名匹配
      secretName: kubernetes-dashboard-certs  #指定tls类型的secret
```

## 4.黑白名单

可以通过两种方式配置

- Annotations：只对指定的ingress生效(两种都配置了，Annotations优先级较高)
- ConfigMap：全局生效

黑名单可以使用ConfigMap去配置，白名单建议使用Annotations去配置。



一个Annotations方式配置ip白名单示例：

nginx.ingress.kubernetes.io/whitelist-source-range 注释指定允许的客户端 IP 源范围。该值是逗号分隔的 CIDR 列表，例如10.0.0.0/24,172.10.0.1。

