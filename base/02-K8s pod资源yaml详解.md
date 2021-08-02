## 什么是Pod
Pod是Kubernetes中最小的单元，它由一组、一个或多个容器组成，每个Pod还包含了一个Pause容器，Pause容器是Pod的父容器，主要负责僵尸进程的回收管理，通过Pause容器可以使同一个Pod里面的多个容器共享存储、网络、PID、IPC等

## 定义一个Pod
```yaml
apiVersion: v1 # 必选，API的版本号
kind: Pod      # 必选，类型Pod
metadata:       # 必选，元数据
  name: nginx   # 必选，符合RFC 1035规范的Pod名称
  namespace: default # 可选，Pod所在的命名空间，不指定默认为default，可以使用-n 指定namespace 
  labels:       # 可选，标签选择器，一般用于过滤和区分Pod
    app: nginx
    role: frontend # 可以写多个
  annotations:  # 可选，注释列表，可以写多个
    app: nginx
spec:   # 必选，用于定义容器的详细信息
  initContainers: # 初始化容器，在容器启动之前执行的一些初始化操作
  - command:
    - sh
    - -c
    - echo "I am InitContainer for init some configuration"
    image: busybox
    imagePullPolicy: IfNotPresent
    name: init-container
  containers:   # 必选，容器列表
  - name: nginx # 必选，符合RFC 1035规范的容器名称
    image: nginx:latest    # 必选，容器所用的镜像的地址
    imagePullPolicy: Always     # 可选，镜像拉取策略
    command: # 可选，容器启动执行的命令
    - nginx 
    - -g
    - "daemon off;"
    workingDir: /usr/share/nginx/html       # 可选，容器的工作目录
    volumeMounts:   # 可选，存储卷配置，可以配置多个
    - name: webroot # 存储卷名称
      mountPath: /usr/share/nginx/html # 挂载目录
      readOnly: true        # 只读
    ports:  # 可选，容器需要暴露的端口号列表
    - name: http    # 端口名称
      containerPort: 80     # 端口号
      protocol: TCP # 端口协议，默认TCP
    env:    # 可选，环境变量配置列表
    - name: TZ      # 变量名
      value: Asia/Shanghai # 变量的值
    - name: LANG
      value: en_US.utf8
    resources:      # 可选，资源限制和资源请求限制
      limits:       # 最大限制设置
        cpu: 1000m  # 1000mcpu = 1cpu
        memory: 1024Mi
      requests:     # 启动所需的资源
        cpu: 100m
        memory: 512Mi
    startupProbe: # 可选，检测容器内进程是否完成启动。注意三种检查方式同时只能使用一种。
      httpGet:      # httpGet检测方式，生产环境建议使用httpGet实现接口级健康检查，健康检查由应用程序提供。
            path: /api/successStart # 检查路径
            port: 80
    readinessProbe: # 可选，健康检查。注意三种检查方式同时只能使用一种。
      httpGet:      # httpGet检测方式，生产环境建议使用httpGet实现接口级健康检查，健康检查由应用程序提供。
            path: / # 检查路径
            port: 80        # 监控端口
    livenessProbe:  # 可选，健康检查
      #exec:        # 执行容器命令检测方式
            #command: 
            #- cat
            #- /health
    #httpGet:       # httpGet检测方式
    #   path: /_health # 检查路径
    #   port: 8080
    #   httpHeaders: # 检查的请求头
    #   - name: end-user
    #     value: Jason 
      tcpSocket:    # 端口检测方式
            port: 80
      initialDelaySeconds: 60       # 初始化时间
      timeoutSeconds: 2     # 超时时间
      periodSeconds: 5      # 检测间隔
      successThreshold: 1 # 检查成功为2次表示就绪
      failureThreshold: 2 # 检测失败1次表示未就绪
    lifecycle:
      postStart: # 容器创建完成后执行的指令, 可以是exec httpGet TCPSocket
        exec:
          command:
          - sh
          - -c
          - 'mkdir /data/ '
      preStop:
        httpGet:      
              path: /
              port: 80
      #  exec:
      #    command:
      #    - sh
      #    - -c
      #    - sleep 9
  restartPolicy: Always   # 可选，默认为Always
  #nodeSelector: # 可选，指定Node节点
  #      region: subnet7
  imagePullSecrets:     # 可选，拉取镜像使用的secret，可以配置多个
  - name: default-dockercfg-86258
  hostNetwork: false    # 可选，是否为主机模式，如是，会占用主机端口
  volumes:      # 共享存储卷列表
  - name: webroot # 名称，与上述对应
    emptyDir: {}    # 挂载目录
        #hostPath:              # 挂载本机目录
        #  path: /etc/hosts

```


## Pod探针
- startupProbe

  k8s于1.16版本新加的检测方式，用于判断容器内的应用程序是否已经启动成功，如果配置了StartupProbe，就会禁止其他探测，知道它成功为止，成功后则不再进行探测。

- livenessProbe

  用于探测容器是否运行，如果探测失败，kubelet会根据配置的重启策略进行相应的处理，如果没有配置该探针，默认就是success

- readinessProbe

  一般用于探测容器内的应用是否健康，它的返回值如果为success，那么就代表这个容器已经完成启动，并且程序已经是可以接受流量的状态

## Pod探针的检测方式

- ExecAction

  在容器内执行一个命令，如果返回码为0，则容器时健康的。

- TCPSocketAction

  通过tcp连接检查容器内的端口是否是通的，如果通，则认为改容器健康。

- HTTPGetAction（最可靠方式）

  通过应用暴露的API地址来检查程序是否正常的，如果状态码在200-400之间，则认为改容器健康。
  
## Pod退出流程lifecycle
用户执行删除操作
- 如果配置了PreStop指令，会先执行PreStop
- Endpoint删除该Pod的ip地址
- Pod状态变成Terminating

## PreStop配置示例
例Springcloud
- 先去请求eureka接口，把自己的ip和端口号，进行下线，eureka从注册表删除改Pod对应应用的IP地址
- 容器进行sleep 90，然后执行kill操作，注意这个动作时间如果超过pod的terminaltionGracePeriodSecond时，k8s不会等你的PreStop执行完毕，最多宽容+2s，所有必须保证这个值大于Pod的sleep的时间