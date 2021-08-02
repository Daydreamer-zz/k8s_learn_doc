# Ingress进阶

ingress主要通过注解的方式生成Nginx的配置文件

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

#### OpenSSL生成测试https证书

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=node1.com"
```

#### 导入证书文件Secret

```bash
kubectl create secret tls node1.com --key=tls.key --cert=tls.crt
```

