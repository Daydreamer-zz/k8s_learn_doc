# Helm

## 1.1 概念

Helm 是 Kubernetes 的包管理器，Helm 可以使用 Charts 启动 Kubernetes 集群，提供可用的工作流：

- 一个 Redis 集群
- 一个 Postgres 数据库
- 一个 HAProxy 边界负载均衡

特性：

- 查找并使用流行的软件，将其打包为 Helm Charts，以便在 Kubernetes 中运行
- 以 Helm Charts 的形式共享您自己的应用程序
- 为您的 Kubernetes 应用程序创建可复制的构建
- 智能地管理您的 Kubernetes 清单文件
- 管理 Helm 包的发行版

## 1.2 先决条件

想成功和正确地使用Helm，需要以下前置条件。

- 一个 Kubernetes 集群
- 确定你安装版本的安全配置
- 安装和配置Helm。

## 1.3 安装helm

直接下载helm二级制包即可

```bash
wget https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
```

```bash
tar xf helm-v3.6.3-linux-amd64.tar && mv linux-amd64/helm /usr/local/bin
```

配置命令自动补全

```bash
helm completion bash > /etc/bash_completion.d/helm
```

添加一个Repo，或者从 [Artifact Hub](https://artifacthub.io/packages/search?kind=0)中查找有效的Helm chart仓库。

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami #bitnami仓库
helm repo add stable https://charts.helm.sh/stable #官方helm仓库
```

## 1.4 使用helm

### 1.4.1 下载后安装(zookeeper)

- 拉取helm包

  ```bash
  helm pull bitnami/zookeeper
  ```

- 修改values.yaml相应配置：副本数、auth、持久化

- 安装至k8s集群

  ```bash
  helm install -n public-service zookeeper  .
  ```

### 1.4.2 直接安装(kafka)

```bash
helm install kafka bitnami/kafka --set zookeeper.enabled=false --set replicaCount=3 --set externalZookeeper.servers=zookeeper --set persistence.enabled=false -n public-service
```

## 1.5 helm基础命令

- 下载一个包：helm pull
- 创建一个包：helm create
- 安装一个包：helm install
- 查看：helm list
- 查看安装参数：helm get values
- 更新：helm upgrade
- 删除：helm delete

## 1.6 helm目录结构

```bash
helm create helm-test
```

```bash
cd helm-test && tree

├── charts # 依赖文件
├── Chart.yaml # 当前chart的基本信息
	apiVersion：Chart的apiVersion，目前默认都是v2
	name：Chart的名称
	type：图表的类型[可选]
	version：Chart自己的版本号
	appVersion：Chart内应用的版本号[可选]
	description：Chart描述信息[可选]
├── templates # 模板位置
│   ├── deployment.yaml
│   ├── _helpers.tpl # 自定义的模板或者函数
│   ├── ingress.yaml
│   ├── NOTES.txt #Chart安装完毕后的提醒信息
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests # 测试文件
│       └── test-connection.yaml
└── values.yaml #配置全局变量或者一些参数
```

## 1.7 Helm内置变量

- Release.Name: 实例的名称，helm install指定的名字
- Release.Namespace: 应用实例的命名空间
- Release.IsUpgrade: 如果当前对实例的操作是更新或者回滚，这个变量的值就会被置为true
- Release.IsInstall: 如果当前对实例的操作是安装，则这边变量被置为true
- Release.Revision: 此次修订的版本号，从1开始，每次升级回滚都会增加1
- Chart: Chart.yaml文件中的内容，可以使用Chart.Version表示应用版本，Chart.Name表示Chart的名称

## 1.8 Helm常用函数

参考[官方文档](http://masterminds.github.io/sprig/strings.html)

### trim

去除去除字符两边的空格

``` go
trim "   hello    "  // 返回hello
```

### trimAll

从字符串的前面或后面删除给定的字符

```go
trimAll "$" "$5.00" //返回5.00
```

### trimSuffix

去除字符串的指定后缀

```go
trimSuffix "-" "hello-" //返回 hello
```

### title

转换为标题大小写 

```go
title "hello world" //返回 Hello World
```

### repeat

重复指定字符

### substr

字符切片，需指定start end string

```go
substr 0 5 "hello world" // 返回hello
```

### nospace

从字符串中删除所有空格

```go
nospace "hello w o r l d" //返回helloworld
```

### contains

是否包含指定的字符，返回布尔值

```go
contains "cat" "catch" //返回true
```

### default

如果在value中取不到指定变量，则使用default指定的值

### quote/squote

字符加双引号/单引号

### cat

将多个字符串连接成一个，用空格隔开

```go
cat "hello" "beautiful" "world" //返回hello beautiful world
```

### indent

将给定字符串中的每一行缩进到指定的缩进宽度。这在对齐多行字符串时很有用

### nindent

与 indent 函数相同，但在字符串的开头添加一个新行

## 1.9 Helm流程控制

控制结构(在模板语言中称为"actions")提供给你和模板作者控制模板迭代流的能力。 Helm的模板语言提供了以下控制结构：

- `if`/`else`， 用来创建条件语句
- `with`， 用来指定范围
- `range`， 提供"for each"类型的循环

除了这些之外，还提供了一些声明和使用命名模板的关键字：

- `define` 在模板中声明一个新的命名模板
- `template` 导入一个命名模板
- `block` 声明一种特殊的可填充的模板块

### If/Else

第一个控制结构是在按照条件在一个模板中包含一个块文本。即`if`/`else`块。

基本的条件结构看起来像这样：

```go
{{ if PIPELINE }}
  # Do something
{{ else if OTHER PIPELINE }}
  # Do something else
{{ else }}
  # Default case
{{ end }}
```

如果是以下值时，管道会被设置为 *false*：

- 布尔false
- 数字0
- 空字符串
- `nil` (空或null)
- 空集合(`map`, `slice`, `tuple`, `dict`, `array`)

在所有其他条件下，条件都为true。

### 控制空格

模板声明的大括号语法可以通过特殊的字符修改，并通知模板引擎取消空白。`{{- `(包括添加的横杠和空格)表示向左删除空白， 而` -}}`表示右边的空格应该被去掉。 *一定注意空格就是换行*

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{- if eq .Values.favorite.drink "coffee" }} #使用{{-取消渲染后的空行
  {{ indent 2 "mug:true" }}
  {{- end }}
```

### 修改使用`with`的范围

如果需要一个部分多次取值，但这部分值都在value的同一个作用域下，可以使用`with`切换到当前作用域，直接取值即可，而无需指定作用域

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
```

### 使用`range`操作循环

先在`values.yaml`文件添加一个披萨的配料列表

```yaml
favorite:
  drink: coffee
  food: pizza
pizzaToppings:
  - mushrooms
  - cheese
  - peppers
  - onions
```

修改模板把这个列表打印到配置映射中

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
  toppings: |-
    {{- range .Values.pizzaToppings }} #使用range循环
    - {{ . | title | quote }}
    {{- end }}    
```

渲染的模板为

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edgy-dragonfly-configmap
data:
  myvalue: "Hello World"
  drink: "coffee"
  food: "PIZZA"
  toppings: |-
    - "Mushrooms"
    - "Cheese"
    - "Peppers"
    - "Onions"    
```

## 1.10 Helm演示项目

[rabbitmq-cluster](https://github.com/Daydreamer-zz/helm_demo.git)