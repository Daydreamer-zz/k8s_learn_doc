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

`nginx.ingress.kubernetes.io/permanent-redirect`

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

`nginx.ingress.kubernetes.io/rewrite-target`

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

`nginx.ingress.kubernetes.io/ssl-redirect`

#### 3.1 OpenSSL生成测试https证书

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=node1.com"
```

#### 3.2 导入证书文件Secret

```bash
kubectl create secret tls node1.com --key=tls.key --cert=tls.crt
```

#### 3.3 Ingress中使用

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

#### 3.4 Dashboard配置自定义证书

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

#### 3.5 为dashboard添加ingress资源

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

### 4.1 Annotations配置白名单

一个Annotations方式配置ip白名单示例：

`nginx.ingress.kubernetes.io/whitelist-source-range` 注释指定允许的客户端 IP 源范围。该值是逗号分隔的 CIDR 列表，例如10.0.0.0/24,172.10.0.1。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/whitelist-source-range: 192.168.2.3
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

### 4.2 Configmap配置黑名单

一个Configmap方式配置IP黑名单，对k8s集群所有ingress资源都生效，直接修改ingress-nginx命名空间下的ingress-nginx-controller的ConfigMap

```bash
kubectl -n ingress-nginx edit configmaps ingress-nginx-controller
```

加入如下内容

```yaml
data:
  block-cidrs: 192.168.2.3 #对整个k8s集群生效，以逗号分隔，可以配置多个IP或者网段
```

完整的ConfigMap资源配置

```yaml
apiVersion: v1
data:
  block-cidrs: 192.168.2.3 #对整个k8s集群生效，以逗号分隔，可以配置多个IP或者网段
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: ingress-nginx
    meta.helm.sh/release-namespace: ingress-nginx
  creationTimestamp: "2021-08-02T06:59:02Z"
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/version: 0.47.0
    helm.sh/chart: ingress-nginx-3.34.0
  name: ingress-nginx-controller
  namespace: ingress-nginx
  resourceVersion: "44659"
  uid: 2f55fb06-b072-49d4-8bc8-3c62850f494b
```

## 5.添加自定义配置

使用注解 `nginx.ingress.kubernetes.io/server-snippet` 可以在服务器配置块中添加自定义配置。

可以实现单个ingress资源更细粒度的配置，例如：单个ingress配置IP黑名单

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/server-snippet: | #直接添加nginx原生配置即可，
        deny 192.168.2.3;
        allow all;
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

## 6.匹配请求头

使用`nginx.ingress.kubernetes.io/server-snippet` 自定义配置实现

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/server-snippet: | #直接添加nginx原生配置即可，
        set $agentflag 0;

        if ($http_user_agent ~* "(Mobile)" ){
          set $agentflag 1;
        }

        if ( $agentflag = 1 ) {
          return 301 https://m.example.com;
        }
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

## 7.速率限制

这些注释定义了连接和传输速率的限制。这些可用于缓解[DDoS 攻击](https://www.nginx.com/blog/mitigating-ddos-attacks-with-nginx-and-nginx-plus)。

- `nginx.ingress.kubernetes.io/limit-connections`：单个 IP 地址允许的并发连接数。超过此限制时将返回 503 错误。
- `nginx.ingress.kubernetes.io/limit-rps`：每秒从给定 IP 接受的请求数。突发限制设置为此限制乘以突发倍数，默认倍数为5。当客户端超过此限制时，返回[limit-req-status-code ](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#limit-req-status-code)**default:** 503。
- `nginx.ingress.kubernetes.io/limit-rpm`：每分钟从给定 IP 接受 的请求数。突发限制设置为此限制乘以突发倍数，默认倍数为5。当客户端超过此限制时，返回[limit-req-status-code ](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#limit-req-status-code)**default:** 503。
- `nginx.ingress.kubernetes.io/limit-burst-multiplier`：突发大小限制速率的乘数。默认突发乘数为 5，此注释覆盖默认乘数。当客户端超过此限制时，[将](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#limit-req-status-code) 返回[limit-req-status-code ](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#limit-req-status-code)**default:** 503。
- `nginx.ingress.kubernetes.io/limit-rate-after`: 初始千字节数，之后对给定连接的响应的进一步传输将受到速率限制。此功能必须在启用[代理缓冲的情况](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#proxy-buffering)下使用。
- `nginx.ingress.kubernetes.io/limit-rate`：每秒允许发送到给定连接的千字节数。零值禁用速率限制。此功能必须与启用[代理缓冲](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#proxy-buffering)一起使用。
- `nginx.ingress.kubernetes.io/limit-whitelist`：要从速率限制中排除的客户端 IP 源范围。该值是逗号分隔的 CIDR 列表。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/limit-rps: "1"
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

## 8.灰度/金丝雀发布

在某些情况下，您可能希望通过向与生产服务不同的服务发送少量请求来“金丝雀”一组新的更改。金丝雀注解使 Ingress 规范能够根据应用的规则充当路由请求的替代服务。`nginx.ingress.kubernetes.io/canary: "true"`设置后可以启用以下用于配置金丝雀的注释：

- `nginx.ingress.kubernetes.io/canary-by-header`：用于通知 Ingress 将请求路由到 Canary Ingress 中指定的服务的标头。当请求标头设置为 时`always`，它将被路由到金丝雀。当标头设置为 时`never`，它永远不会被路由到金丝雀。对于任何其他值，标头将被忽略，并按优先级将请求与其他金丝雀规则进行比较。
- `nginx.ingress.kubernetes.io/canary-by-header-value`：要匹配的标头值，用于通知 Ingress 将请求路由到 Canary Ingress 中指定的服务。当请求头设置为这个值时，它将被路由到金丝雀。对于任何其他标头值，标头将被忽略，并按优先级将请求与其他金丝雀规则进行比较。此注释必须与 一起使用。注释是 的扩展，`nginx.ingress.kubernetes.io/canary-by-header`允许自定义标头值而不是使用硬编码值。如果`nginx.ingress.kubernetes.io/canary-by-header`未定义注释，则没有任何影响。
- `nginx.ingress.kubernetes.io/canary-by-header-pattern`：这与`canary-by-header-value`PCRE 正则表达式匹配的方式相同。请注意，`canary-by-header-value`设置此注释时将被忽略。当给定的 Regex 在请求处理过程中导致错误时，该请求将被视为不匹配。
- `nginx.ingress.kubernetes.io/canary-by-cookie`：用于通知 Ingress 将请求路由到 Canary Ingress 中指定的服务的 cookie。当 cookie 值设置为 时`always`，它将被路由到金丝雀。当 cookie 设置为 时`never`，它永远不会被路由到金丝雀。对于任何其他值，cookie 将被忽略，并按优先级将请求与其他金丝雀规则进行比较。
- `nginx.ingress.kubernetes.io/canary-weight`：应路由到 Canary Ingress 中指定的服务的基于整数 (0 - 100) 的随机请求百分比。权重为 0 意味着此金丝雀规则不会向 Canary 入口中的服务发送任何请求。权重为 100 意味着所有请求都将发送到 Ingress 中指定的替代服务。

Canary 规则按优先顺序进行评估。优先级如下： `canary-by-header -> canary-by-cookie -> canary-weight`

**请注意**，当你标记的侵入，金丝雀，那么所有其他非金丝雀注释将被忽略（从相应的主入口继承）除`nginx.ingress.kubernetes.io/load-balance`，`nginx.ingress.kubernetes.io/upstream-hash-by`以及[相关的会话亲和力的注解](https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md#session-affinity)。如果要在忽略会话亲缘关系时恢复Canary的原始行为，请在非 Canary 入口定义上`nginx.ingress.kubernetes.io/affinity-canary-behavior`使用 value设置注释`legacy`。

**已知限制**

目前，每个 Ingress 规则最多可以应用一个 Canary Ingress。



### 8.1 根据权重路由到新版本

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-canary
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/canary: "true" #此项必须设置为true才可以支持同一个域名金丝雀发布
    nginx.ingress.kubernetes.io/canary-weight: "50"  #流量请求到新版本的权重
spec:
  rules:
    - host: node1.com #和之前的旧版本允许同一个域名
      http:
        paths:
          - backend:
              service:
                name: nginx-svc-v2
                port:
                  number: 80
            path: /
            pathType: Prefix
```

### 8.2 根据请求头路由到新版本

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-canary
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/canary: "true" #此项必须设置为true才可以支持同一个域名金丝雀发布
    nginx.ingress.kubernetes.io/canary-weight: "50"  #流量请求到新版本的权重
    nginx.ingress.kubernetes.io/canary-by-header: "user"
    nginx.ingress.kubernetes.io/canary-by-header-value: "canary"
spec:
  rules:
    - host: node1.com #和之前的旧版本允许同一个域名
      http:
        paths:
          - backend:
              service:
                name: nginx-svc-v2
                port:
                  number: 80
            path: /
            pathType: Prefix
```

## 9.自定义错误页面

### 9.1 单独的error_page

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/server-snippet: | #直接添加nginx原生配置即可，
        error_page   500 502 503 504  /50x.html; #nginx原生error_page配置
        location = /50x.html {
          root   /usr/share/nginx/html;
        }

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

### 9.2 ingress的custom-error

自定义错误文档：https://github.com/kubernetes/ingress-nginx/tree/nginx-0.20.0/docs/examples/customization/custom-errors

官方自定义错误配置资源：https://github.com/kubernetes/ingress-nginx/blob/nginx-0.20.0/docs/examples/customization/custom-errors/custom-default-backend.yaml

修改ingress-corollor资源，args添加`--default-backend-service`参数

```bash
kubectl -n ingress-nginx edit daemonsets.apps ingress-nginx-controller
```

```yaml
--default-backend-service=namespace/servicename #格式命名空间/service名，这个service应该只返回一个错误页面
```

创建自定义错误资源

```bash
kubectl -n ingress-nginx create -f custom-default-backend.yaml
```

修改名为`ingress-nginx-controller`的ConfigMap添加`custom-http-errors`

```yaml
data:
  custom-http-errors: 404,403 #配置哪些错误状态码需要跳转到指定页面
```

## 10 Basic Authentication

安装htpasswd工具

```bash
apt-get install apache2-utils
```

生成密码文件

```bash
htpasswd -c auth admin
```

生成secret

```bash
kubectl create secret generic basic-auth --from-file=auth
```

Ingress资源中使用

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-type: basic #指定认证类型
    nginx.ingress.kubernetes.io/auth-secret: basic-auth #认证文件的secret
    nginx.ingress.kubernetes.io/auth-realm: "Pls input password" #提示信息
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



