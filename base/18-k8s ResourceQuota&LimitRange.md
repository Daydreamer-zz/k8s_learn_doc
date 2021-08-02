# k8s ResourceQuota & LimitRange

## 1.1 ResourceQuota资源配额

资源配额，通过 `ResourceQuota` 对象来定义，对每个命名空间的资源消耗总量提供限制。 它可以限制命名空间中某种类型的对象的总数目上限，也可以限制命令空间中的 Pod 可以使用的计算资源的总上限。

## 1.2 ResourceQuota配置示例

- pods：限制最多启动Pod的个数
- requests.cpu：限制最高cpu的请求数
- requests.memory：限制最高内存的请求数
- limits.cpu：限制最高cpu的limit上限
- limits.memory：限制最高内存的limit上限

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-test
  labels:
    app: resourcequota
spec:
  hard:
    pods: 50
    requests.cpu: 0.5
    requests.memory: 512Mi
    limits.cpu: 5
    limits.memory: 16Gi
    configmaps: 20
    requests.storage: 40Gi
    persistentvolumeclaims: 20
    replicationcontrollers: 20
    secrets: 20
    services: 50
    services.loadbalancers: "2"
    services.nodeports: "10"
```

## 2.1 LimitRange

LimitRange可以为某个命名空间下的Pod默认的resources资源限制，允许的最高资源限制，允许的最低资源限制

## 2.2 LimitRange配置示例

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: demo-limit-range
  namespace: default
spec:
  limits:
    - type: Container
      default: # 默认limits配置
        cpu: "0.8"
        memory: "512Mi"
      defaultRequest: # 默认requests配置
        cpu: "0.5"
        memory: "256Mi"
      max:   # 内存cpu的最大配置
        cpu: "800m"
        memory: 1Gi
      min:   # 内存cpu的最小配置
        cpu: "0.2"
        memory: 256Mi
    - type: PersistentVolumeClaim # pvc的限制
      max:
        storage: 2Gi
      min:
        storage: 1Gi
```

