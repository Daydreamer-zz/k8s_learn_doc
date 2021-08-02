# k8s RBAC

## 1.1 RBAC鉴权

基于角色（Role）的访问控制（RBAC）是一种基于组织中用户的角色来调节控制对 计算机或网络资源的访问的方法。

RBAC 鉴权机制使用 `rbac.authorization.k8s.io` [API 组](https://kubernetes.io/zh/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning) 来驱动鉴权决定，允许你通过 Kubernetes API 动态配置策略。

要启用 RBAC，在启动 [API 服务器](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-apiserver/) 时将 `--authorization-mode` 参数设置为一个逗号分隔的列表并确保其中包含 `RBAC`。

## 1.2 API对象

RBAC API包含四种kubernetes对象：*Role*、*ClusterRole*、*RoleBinding* 和 *ClusterRoleBinding*
![image.png](https://i.loli.net/2021/07/12/ehnXEMvz1QOH53Y.png)

## 1.3 Role和ClusterRole

RBAC 的 *Role* 或 *ClusterRole* 中包含一组代表相关权限的规则。权限字段是累计的(故没有拒绝某个操作的规则)

Role对象作用于某个命名空间下，在创建Role时，必须指定命名空间

ClusterRole是作用于一个集群的资源，权限能够作用在整个kubernetes集群

## 1.4 RoleBinding和ClusterRoleBinding

角色绑定(Role Binding)是将角色定义的权限赋予一个或者一组用户，可以绑定在User、Goup、ServiceAccount等资源上。

RoleBinding 在指定的名字空间中执行授权，而 ClusterRoleBinding 在集群范围执行授权。

RoleBinding可以绑定 同一命名空间下的Role，也可以绑定ClusterRole到某个命名空间下，如果要绑定某个ClusterRole到整个集群，则需要只用ClusterRoleBinding

## 1.5 默认Roles和RoleBindings

API 服务器创建一组默认的 ClusterRole 和 ClusterRoleBinding 对象。 这其中许多是以 `system:` 为前缀的，用以标识对应资源是直接由集群控制面管理的。 所有的默认 ClusterRole 和 ClusterRoleBinding 都有 `kubernetes.io/bootstrapping=rbac-defaults` 标签

- system:unauthenticated，未通过认证测试的用户所属的组
- system:authenticated，认证成功的用户自动加入的组，用于快捷引用所有正常通过认证的用户帐号
- system:serviceaccounts，当前系统上所有Service Account对象
- system:serviceaccounts:<namespace>，特定名称空间内所有Service Account对象


## 1.6 Role或ClusterRole配置示例

- kind：定义资源类型是Role或ClusterRole

- metadta：元数据定义

  - nemespace：Role是作用于单个命名空间下的，具有命名空间隔离性，ClusterRole作用于整个集群则不需要指定
  - name: Role的名称

- rules：定义具体的权限，切片类型，可以定义多个

  - apiGroups：包含该资源的apiGroups名称，比如extensions、apps
  - resources：定义对那行资源进行授权，切片类型，可以定义多个，如：pods、services等
  - verbs：定义可以执行的操作，切片类型，可以定义多个，如：create、delete、list、watch等

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
  - apiGroups:
      - apps
      - extensions
    resources:
      - pods
    verbs:
      - get
      - watch
      - list
```

## 1.7 RoleBinding和ClusterRoleBinding示例

### 1.7.1 通过资源文件创建

- subjects：配置被绑定的对象，可以配置多个
  - kind：绑定对象的类别，当前为User，还可以是Group、ServiceAccount
  - name：绑定的对象名称
- roleRef：绑定的类别，可以是Role或ClusterRole
  - kind：指定权限来源，可以是Role或ClusterRole
  - name：Role或ClusterRole的名字
  - apiGroup：API组名

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
  - kind: User
    name: jane
    apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

### 1.7.2 通过命令行创建

```bash
kubectl create rolebinding read-pods --role=pod-reader --user=jane --namespace=default
```

## 1.8 聚合ClusterRole

r1.yaml

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.example.com/aggregate-to-monitoring: "true" # 之后创建的ClusterRole和这个标签匹配上就会同步其他ClusterRole的权限
rules:
  []
```

r1.yaml

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-endpoints
  labels: # labels和上面的匹配
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
  - apiGroups: [""]
    resources:
      - services
      - endpoints
      - pods
    verbs:
      - get
      - list
      - watch
```

## 1.9 权限管理RBAC最佳实践

### 1.9.1 如何进行授权

**通用权限使用ClusterRole管理**

针对不同用户的不同权限需求，可以提取出其都需要的通用权限，创建包含通用权限的ClusterRole，然后将将其绑定给指定的用户和指定的命名空间下。

![image.png](https://i.loli.net/2021/07/12/cIoFjuHNTRhEK8S.png)

### 1.9.2 如何进行用户管理

**参考数据库用户权限的设计理念**

项目下的命名空间不创建用户或者ServiceAccount，而是将所有用户放在单独的命名空间(如：kube-users)，然后把指定权限的ClusterRole都绑定到改命名空间下某个用户RoleBinding

![image.png](https://i.loli.net/2021/07/12/21Wq5yJVEK8PCQb.png)

## 1.10 RBAC企业实例

需求：

- 用户dotbalo可以查看default、kube-system下Pod的日志
- 用户dukuan可以在default下的Pod中执行命令，并且可以删除Pod

### 1.10.1 编写yaml资源文件

my-clusterroles.yaml

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-readonly
rules:
  - apiGroups: [""]
    resources:
      - namespaces
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - metrics.k8s.io
    resources:
      - pods
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-delete
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
      - list
      - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-exec
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
      - list
  - apiGroups:
      - ""
    resources:
      - pods/exec
    verbs:
      - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-log
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/log
    verbs:
      - get
      - list
      - watch
```

### 1.10.2 创建用户管理命名空间

```bash
kubectl create namespace kube-users
```

### 1.10.3 绑定kube-users命名空间下所有用户的命名空间查看权限

新版本不支持使用命令行方式绑定全部命名空间下的用户

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: namespace-readonly
subjects:
  - kind: Group
    name: system:serviceaccounts:kube-users  # K8s内建用户组，特定名称空间内所有Service Account对象
    apiGroup: rbac.authorization.k8s.io
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-readonly
```

### 1.10.4 用户绑定权限

dotbalo用户

```bash
kubectl create rolebinding dotbalo-pod-log --clusterrole=pod-log --serviceaccount=kube-users:dotbalo --namespace=kube-system
```

```bash
kubectl create rolebinding dotbalo-pod-log --clusterrole=pod-log --serviceaccount=kube-users:dotbalo --namespace=default
```

dukuan用户

```bash
kubectl create rolebinding dukuan-pod-exec --clusterrole=pod-exec --serviceaccount=kube-users:dukuan --namespace=default
```

```bash
kubectl create rolebinding dukuan-pod-delete --clusterrole=pod-delete --serviceaccount=kube-users:dukuan --namespace=default
```

