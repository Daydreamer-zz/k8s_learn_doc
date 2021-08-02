# k8s Kubelet TLS Bootstrapping CSR申请和颁发

## 流程

- Kubelet启动

- Kubelet查看本地kubelet.kubeconfig文件，假设没有这个文件

- kubelet会查看本地的bootstrap.kubeconfig

- kubelet读取bootstrap.kubeconfig文件，检索apiserver的url和一个token

- kubelet链接到apiserver，使用这个token进行认证

  a)  apiserver会识别tokenid，apiserver会查看该tokenid对于bootstrap的一个secret

  b)  找到这个secret中的一个字段，apiserver把这 个token识别成一个username，名称是system:bootstrap:{tokenid}，属于system:bootstrappers这个组，这个组具有申请csr的权限，改组的权限绑定在一个叫system:node-bootstrapper的clusterrole

  i:    clusterrole k8s集群级别的权限控制，作用于整个k8s集群

  ii:   clusterrolebinding，集群权限的绑定，它可以把某个clusterrole绑定到一个用户、组或者serviceaccount

  CSR: 相当于一个申请表，可以拿着这个申请表去apiserver申请证书

- 经过上面的认证，kubelet就有了一个创建和检索csr的权限

- kubelet为自己创建一个CSR，名称为kubernetes.io/kube-apiserver-client-kubelet

- CSR被允许有两种方式

  a)   k8s管理员使用kubelet手动颁发证书

  b)   如果配置了相关权限，kube-controller-manager就会自动同意

  ​    i:   controller-manager有一个CSRApprovingController，他会校验kubelet发过来的CSR的username和group是否有创建CSR的权限，而且还有验证签发者是是否是kubernetes.io/kube-apiserver-client-kubelet

  ​    ii:  controller-manager同意CSR请求

- CSR被同意后，controller-manager创建kubelet的证书文件

- controller-manager将证书更新至CSR的status字段

- kubelet从apiserver获取证书

- kubelet从获取到的key和证书文件创建kubelet.kubeconfig

- kubelet启动完成并正常工作

- 可选：如果配置了自动续期，kubelet会在证书文件过期的时候利用之前的kubeconfig文件去申请一个新的证书，相当于续约。

- 新的证书被同意或者签发，取决于我们的配置，如果配置了自动签发

  a)  kubelet创建CSR是属于一个O：system:nodes ，CN：system:nodes:主机名

