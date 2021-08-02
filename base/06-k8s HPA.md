# k8s HPA

## HPA接口类型

- HPA v1为稳定版自动水平伸缩，只支持CPU指标
- V2为beta版本，分为v2beta1(支持CPU、内存和自定义指标)
- v2beta2(支持CPU、内存、自定义指标Custom和额外指标ExternalMetrics)

## HPA实践

### 注意事项

- 必须安装metrics-server或其他自定义metrics-server
- 必须配置requests参数
- 不能扩容无法缩放的对象，比如DaemonSet

### 创建一个Deployment

创建pod导出yaml文件

- --dry-run=client

  不通过apiserver创建资源，而是导出为yaml，保存后修改

```bash
kubectl create deployment nginx-server-hpa --image=registry.cn-beijing.aliyuncs.com/dotbalo/nginx --dry-run=client -o yaml
```

hpa-nginx.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-server-hpa
  name: nginx-server-hpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-server-hpa
  template:
    metadata:
      labels:
        app: nginx-server-hpa
    spec:
      containers:
      - image: registry.cn-beijing.aliyuncs.com/dotbalo/nginx
        name: nginx
        resources:
          requests:
            cpu: 10m
```

### 暴露为Service

```bash
kubectl expose deployment nginx-server-hpa --port=80
```

### 配置自动伸缩参数

```bash
kubectl autoscale deployment nginx-server-hpa --cpu-percent=10 --max=10 --min=1
```

### 整合为一个资源文件

nginx-server-hpa.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-server-hpa
  name: nginx-server-hpa
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-server-hpa
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-server-hpa
  name: nginx-server-hpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-server-hpa
  template:
    metadata:
      labels:
        app: nginx-server-hpa
    spec:
      containers:
      - image: registry.cn-beijing.aliyuncs.com/dotbalo/nginx
        name: nginx
        ports:
          - containerPort: 80
        resources:
          requests:
            cpu: 10m
---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-server-hpa
spec:
  targetCPUUtilizationPercentage: 10
  maxReplicas: 10
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-server-hpa
```

