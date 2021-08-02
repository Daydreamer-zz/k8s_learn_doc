# k8s Affinity

## 1.1 仍然存在的问题

- 某些pod优先选择有ssd=true标签的节点，如果没有再考虑部署到其他节点
- 某些pod需要部署在ssd=true和type=physical的节点上，但是优先部署在ssd=true的节点上
- 同一个应用的Pod不同的副本或者同一个项目的应用尽量或者必须部署在同一个节点或者符合某个标签的一类节点上或者不同的区域
- 相互依赖的两个Pod尽量或者必须部署在同一个节点上

## 1.2 Affinity分类

### NodeAffinity

节点亲和力/反亲和力

### PodAffinity

Pod亲和力

### PodAntiAffinity

Pod反亲和力

## 1.3 节点亲和力配置详解

- requiredDuringSchedulingIgnoredDuringExecution(硬亲和力配置)

  - nodeSelectorTerms：节点选择器配置，可以配置多个matchExpressions(满足其一)，每个matchExpressions下可以配置多个key、value类型的选择器(都需要满足)，其中values可以配置多个(满足其一)
- preferredDuringSchedulingIgnoredDuringExecution(软亲和力配置)

  - weight：软亲和力的权重，权重越高优先级越大，范围1-100
  - preference：软亲和力配置项，和weight同级，可以配置多个，matchExpressions和硬亲和力一致
- operator：标签匹配的方式
  - In：相当于key=value的形式
  - NotIn：相当如key != value的形式
  - Exist：节点存在Label的key为指定的值即可，不能配置values字段
  - DoesNotExist：节点不存在label的key为指定的值即可，不能配置values字段
  - Gt：大于value指定的值
  - Lt：小于value指定的值

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions: # 如果有多个matchExpression，只需要满足一个
              - key: kubernetes.io/e2e-az-name # 如有多个key，需要全部满足
                operator: In
                values: 
                  - e2e-az1 # 如有多个value，只需要满足一个
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          preference:
            matchExpressions:
              - key: another-node-lable-key
                operator: In
                values:
                  - another-node-lable-value
  containers:
    - name: with-node-affinity
      image: nginx:1.18.0
      imagePullPolicy: IfNotPresent
```

## 1.4 Pod亲和力配置详解

- labelSelector：Pod选择器配置，可以配置多个
- matchExpressions：和节点亲和力配置一致
- operator：配置和节点亲和力一致，但是没有Gt和Lt
- togologykey：匹配的拓扑域的key，也就是节点上的Label的key，key和value相同的为同一个域，可以用于标注不同的机房和地区
- Namespaces：和哪个命名空间的Pod进行匹配，为空为当前的命名空间

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-pod-affinity
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: security
                    operator: In
                    values:
                      - S1
              namespaces:
                - default
              topologyKey: failure-domain.beta.kubernetes.io/zone
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - podAffinityTerm:
            labelSelector: # 只能写一个labelSelector段
              matchExpressions:
                - key: security
                  operator: In
                  values:
                    - S2
            namespaces:
              - default
            topologyKey: failure-domain.beta.kubernetes.io/zone
          weight: 100
  containers:
    - name: with-pod-affinity
      image: nginx:1.18.0
      imagePullPolicy: IfNotPresent
```

## 1.5 同一个应用部署在不同的宿主机

利用Pod的反亲和力，可以实现一个deploy的不用副本部署在不同的机器上

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: must-be-diff-nodes
  labels:
    app: must-be-diff-nodes
spec:
  selector:
    matchLabels:
      app: must-be-diff-nodes
  replicas: 3
  template:
    metadata:
      labels:
        app: must-be-diff-nodes
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - topologyKey: kubernetes.io/hostname
              labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - must-be-diff-nodes
      restartPolicy: Always
      terminationGracePeriodSeconds: 10
      containers:
        - name: nginx
          image: nginx:1.18.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
```

## 1.6 尽量调度到高配服务器

节点打标签

```bash
kubectl label nodes k8s-master01 ssd=true
```

```bash
kubectl label nodes k8s-master01 gpu=true
```

```bash
kubectl label nodes k8s-node01 ssd=true
```

```bash
kubectl label nodes k8s-node02 type=physical
```





```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prefer-ssd
  labels:
    app: prefer-ssd
spec:
  replicas: 1
  selector:
      matchLabels:
        app: prefer-ssd
  template:
    metadata:
      labels:
        app: prefer-ssd
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - preference:
                matchExpressions:  # 希望部署到ssd的节点，但是不会部署到同时有ssd和gpu的节点
                  - key: ssd
                    operator: In
                    values:
                      - "true"
                  - key: gpu
                    operator: NotIn
                    values:
                      - "true"
              weight: 100
            - preference:
                matchExpressions:
                  - key: type
                    operator: In
                    values:
                      - physical
              weight: 10
      containers:
        - name: prefer-ssd
          image: nginx:1.18.0
          imagePullPolicy: IfNotPresent
          env:
            - name: TZ
              value: Asia/Shanghai
            - name: LANG
              value: C.UTF-8
```

## 1.7 拓扑域Topologykey详解

topologyKey：拓扑域，主要针对宿主机，相当于对宿主机进行区域划分。用Label进行判断，不同的key和不同的value是属于不同的拓扑域，根据不同的域做区分，可以实现pod分配到不同的域上

## 1.8 同一个应用部署在不同区域

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: must-be-diff-zone
  labels:
    app: must-be-diff-zone
spec:
  replicas: 3
  selector:
    matchLabels:
      app: must-be-diff-zone
  template:
    metadata:
      labels:
        app: must-be-diff-zone
    spec:
        affinity:
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - topologyKey: region # 指定域
                  labelSelector:
                    matchExpressions:
                      - key: app
                        operator: In
                        values:
                          - must-be-diff-zone
      containers:
        - name: must-be-diff-zone
          imagePullPolicy: IfNotPresent
          image: nginx:1.18.0
```

