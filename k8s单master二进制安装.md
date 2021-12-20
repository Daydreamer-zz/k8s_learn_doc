# 单master k8s

这里的master节点ip为`192.168.2.4`，pod网段为`172.16.0.0/12`，service网段为`10.96.0.0/12`，kube-dns地址为`10.96.0.10`，您可以直接批量替这些ip以适应您的网络环境。

## 一、基础环境配置

所有master和node节点的优化配置模板。

### 1.配置yum源

关闭fastmirror

```bash
sed -i "s#enabled=1#enabled=0#g" /etc/yum/pluginconf.d/fastestmirror.conf
sed -i "s#plugins=1#plugins=0#g" /etc/yum.conf
```

CentOS-Base.repo

```bash
cat << EOF > /etc/yum.repos.d/CentOS-Base.repo
[base]
name=CentOS-\$releasever - Base
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[updates]
name=CentOS-\$releasever - Updates
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
```

epel.repo

```bash
cat << EOF > /etc/yum.repos.d/epel.repo
[epel]
name=Extra Packages for Enterprise Linux 7 - \$basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/epel/7/\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF
```

docker-ce.repo

```bash
cat << EOF > /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/gpg
EOF
```

### 2.安装基础包

```bash
yum install wget jq psmisc vim net-tools telnet yum-utils device-mapper-persistent-data lvm2 git ipvsadm ipset sysstat conntrack libseccomp chrony bash-completion lrzsz htop socat -y
```

### 3.环境优化

#### 2.1 禁用服务和优化

```bash
sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
systemctl disable firewalld --now
systemctl disable NetworkManager --now
chmod +x /etc/rc.d/rc.local
systemctl list-unit-files|egrep "^ab|^aud|^kdump|vm|^md|^mic|^post|lvm"  |awk '{print $1}'|sed -r 's#(.*)#systemctl disable &#g'|bash
echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "' >> /etc/profile
source /etc/profile
sed -i "s/^#UseDNS yes/UseDNS no/g" /etc/ssh/sshd_config
sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/g" /etc/ssh/sshd_config
systemctl restart sshd
```

#### 2.2 limits优化

```bash
cat << EOF >> /etc/security/limits.conf
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF
```

#### 2.3 配置开机加载内核模块

```bash
cat << EOF > /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_lc
ip_vs_wlc
ip_vs_rr
ip_vs_wrr
ip_vs_lblc
ip_vs_lblcr
ip_vs_dh
ip_vs_sh
ip_vs_fo
ip_vs_nq
ip_vs_sed
ip_vs_ftp
ip_vs_sh
nf_conntrack
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
br_netfilter
EOF
```

```bash
systemctl enable --now systemd-modules-load.service
```

#### 2.4 内核参数优化

```bash
cat << EOF > /etc/sysctl.d/k8s.conf

# 开启IP转发.
net.ipv4.ip_forward = 1

# 表示bridge 设备在二层转发时也去调用 iptables 配置的三层规则 (包含 conntrack)
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# 在CentOS7.4引入了一个新的参数来控制内核的行为。 
# /proc/sys/fs/may_detach_mounts 默认设置为0
# 当系统有容器运行的时候，需要将该值设置为1
fs.may_detach_mounts = 1

# Default: 30
# 0 - 任何情况下都不使用swap。
# 1 - 除非内存不足（OOM），否则不使用swap。
vm.swappiness = 0

# 内存分配策略
# 0 - 表示内核将检查是否有足够的可用内存供应用进程使用；如果有足够的可用内存，内存申请允许；否则，内存申请失败，并把错误返回给应用进程。
# 1 - 表示内核允许分配所有的物理内存，而不管当前的内存状态如何。
# 2 - 表示内核允许分配超过所有物理内存和交换空间总和的内存
vm.overcommit_memory=1

# OOM时处理
# 1关闭，等于0时，表示当内存耗尽时，内核会触发OOM killer杀掉最耗内存的进程。
vm.panic_on_oom=0

# 调用inotify_init时分配给inotify instance中可排队的event的数目的最大值
fs.inotify.max_user_watches = 89100

# 最大文件句柄数
fs.file-max=52706963

# 最大文件打开数
fs.nr_open=52706963

# 设置 conntrack 的上限
net.netfilter.nf_conntrack_max=2310720

# TCP连接keepalive的持续时间，默认7200
net.ipv4.tcp_keepalive_time = 600

# TCP keepalive探测包重试次数
net.ipv4.tcp_keepalive_probes = 3

# TCP keepalive探测包发送间隔
net.ipv4.tcp_keepalive_intvl =15

# 内核中管理 TIME_WAIT 状态的数量
net.ipv4.tcp_max_tw_buckets = 36000

# 表示开启重用。允许将TIME-WAIT sockets重新用于新的TCP连接，默认为0，表示关闭()
net.ipv4.tcp_tw_reuse = 1

# 不属于任何进程的tcp socket最大数量. 超过这个数量的socket会被reset, 并告警
net.ipv4.tcp_max_orphans = 327680

# TCP FIN报文重试次数
net.ipv4.tcp_orphan_retries = 3

# 表示开启SYN Cookies。当出现SYN等待队列溢出时，启用cookies来处理，可防范少量SYN攻击，默认为0，表示关闭
net.ipv4.tcp_syncookies = 1

# 表示SYN队列的长度，默认为1024
net.ipv4.tcp_max_syn_backlog = 16384

# iptables防火墙使用了ip_conntrack内核模块实现连接跟踪功能
# 调整conntrack表最大数量
net.ipv4.ip_conntrack_max = 65536

# 调整系统中处于 SYN_RECV 状态的 TCP 连接数量
net.ipv4.tcp_max_syn_backlog = 16384

# 禁用tcp时间戳
# 默认为1,设为0关闭
net.ipv4.tcp_timestamps = 0

# 定义了系统中每一个端口最大的监听队列的长度,这是个全局的参数,默认值为128.限制了每个端口接收新tcp连接侦听队列的大小
net.core.somaxconn = 16384
EOF
sysctl --system
```

#### 2.5 配置chronyd配置文件

```bash
cat << EOF > /etc/chrony.conf
server ntp.aliyun.com iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
logchange 0.5
logdir /var/log/chrony
EOF
```

### 3.内核升级

#### 3.1 下载内核rpm包

```bash
wget http://193.49.22.109/elrepo/kernel/el7/x86_64/RPMS/kernel-ml-devel-4.19.12-1.el7.elrepo.x86_64.rpm
wget http://193.49.22.109/elrepo/kernel/el7/x86_64/RPMS/kernel-ml-4.19.12-1.el7.elrepo.x86_64.rpm
```

#### 3.2 安装内核rpm包

```bash
yum localinstall -y kernel-ml*
```

#### 3.3 配置默认内核

```bash
grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
```

#### 4.4 重启主机

```bash
reboot
```

### 4.安装docker和优化

#### 4.1安装docker-ce

```bash
yum install docker-ce-19.03.* -y
```

#### 4.2 docker配置文件优化

```bash
mkdir -p /etc/docker
```

```bash
cat << EOF > /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://kc95fq7u.mirror.aliyuncs.com"
  ],
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-opts": {
    "max-size": "300m",
    "max-file": "2"
  },
  "live-restore": true
}
EOF
```

#### 4.3 重启docker

```bash
systemctl enable docker
```

```bash
systemctl daemon-reload && systemctl restart docker
```

## 二、证书生成

### 1.下载证书生成工具

```bash
wget "https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64" -O /usr/local/bin/cfssl
wget "https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64" -O /usr/local/bin/cfssljson
wget "https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl-certinfo_1.6.1_linux_amd64" -O /usr/local/bin/cfssl-certinfo
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson /usr/local/bin/cfssl-certinfo
```

### 2.创建相关目录

master节点

```bash
mkdir -p /etc/etcd/ssl /etc/kubernetes/pki/etcd  /root/.kube 
```

所有节点(master和node)

```bash
mkdir -p /etc/kubernetes/pki /etc/kubernetes/manifests/ /etc/systemd/system/kubelet.service.d  /var/lib/kubelet /var/log/kubernetes /opt/cni/bin
```

### 3.etcd

进入证书申请配置文件目录操作

```bash
cd k8s_learn_doc/install_resource/k8s_pki_config
```

#### 3.1 etcd CA证书

```bash
cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare /etc/etcd/ssl/etcd-ca
```
#### 3.2 etcd证书

```bash
cfssl gencert \
-ca=/etc/etcd/ssl/etcd-ca.pem \
-ca-key=/etc/etcd/ssl/etcd-ca-key.pem \
-config=ca-config.json \
-hostname=127.0.0.1,k8s-master01,192.168.2.4 \
-profile=kubernetes \
etcd-csr.json | cfssljson -bare /etc/etcd/ssl/etcd
```

#### 3.3 软链接

```bash
ln -s /etc/etcd/ssl/* /etc/kubernetes/pki/etcd/
```

### 4.kubernetes

#### 4.1 kubernetes CA证书

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare /etc/kubernetes/pki/ca
```

#### 4.2 kube-apiserver证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/ca.pem \
-ca-key=/etc/kubernetes/pki/ca-key.pem \
-config=ca-config.json \
-hostname=10.96.0.1,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,192.168.2.4 \
-profile=kubernetes \
apiserver-csr.json | cfssljson -bare /etc/kubernetes/pki/apiserver
```
#### 4.3 kube-controller-manager证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/ca.pem \
-ca-key=/etc/kubernetes/pki/ca-key.pem \
-config=ca-config.json \
-profile=kubernetes \
manager-csr.json | cfssljson -bare /etc/kubernetes/pki/controller-manager
```

#### 4.4 kube-scheduler证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/ca.pem \
-ca-key=/etc/kubernetes/pki/ca-key.pem \
-config=ca-config.json \
-profile=kubernetes \
scheduler-csr.json | cfssljson -bare /etc/kubernetes/pki/scheduler
```

#### 4.5 kube-proxy证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/ca.pem \
-ca-key=/etc/kubernetes/pki/ca-key.pem \
-config=ca-config.json \
-profile=kubernetes \
kube-proxy-csr.json | cfssljson -bare /etc/kubernetes/pki/kube-proxy
```

#### 4.6 admin证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/ca.pem \
-ca-key=/etc/kubernetes/pki/ca-key.pem \
-config=ca-config.json \
-profile=kubernetes \
admin-csr.json | cfssljson -bare /etc/kubernetes/pki/admin
```

#### 4.7 kube-apiserver聚合CA证书

```bash
cfssl gencert -initca front-proxy-ca-csr.json | cfssljson -bare /etc/kubernetes/pki/front-proxy-ca
```

#### 4.8 kube-apiserver聚合证书

```bash
cfssl gencert \
-ca=/etc/kubernetes/pki/front-proxy-ca.pem \
-ca-key=/etc/kubernetes/pki/front-proxy-ca-key.pem \
-config=ca-config.json \
-profile=kubernetes \
front-proxy-client-csr.json | cfssljson -bare /etc/kubernetes/pki/front-proxy-client
```

#### 4.9 Serviceaccount Key

```bash
openssl genrsa -out /etc/kubernetes/pki/sa.key 2048
```

```bash
openssl rsa -in /etc/kubernetes/pki/sa.key -pubout -out /etc/kubernetes/pki/sa.pub
```

## 三、生成kubeconfig配置文件

### 1.下载和安装k8s etcd helm二进制文件

#### 1.1 下载并解压

```bash
wget https://dl.k8s.io/v1.20.11/kubernetes-server-linux-amd64.tar.gz
wget https://github.com/etcd-io/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-amd64.tar.gz
wget https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
```

```bash
tar -xf kubernetes-server-linux-amd64.tar.gz  --strip-components=3 -C /usr/local/bin kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}
```

```bash
tar -zxvf etcd-v3.5.0-linux-amd64.tar.gz --strip-components=1 -C /usr/local/bin etcd-v3.5.0-linux-amd64/etcd{,ctl}
```

```bash
tar xf helm-v3.6.3-linux-amd64.tar.gz && mv linux-amd64/helm /usr/local/bin/helm
```

#### 1.2 配置bash自动补全

```bash
kubectl completion bash > /etc/bash_completion.d/kubectl
```

```bash
helm completion bash > /etc/bash_completion.d/helm
```

### 2.kube-controller-manager

```bash
#设置一个集群项
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true \
--server=https://192.168.2.4:6443 \
--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig

#设置一个环境项，一个上下文
kubectl config set-context system:kube-controller-manager@kubernetes \
--cluster=kubernetes \
--user=system:kube-controller-manager \
--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig

#设置一个用户项
kubectl config set-credentials system:kube-controller-manager \
--client-certificate=/etc/kubernetes/pki/controller-manager.pem \
--client-key=/etc/kubernetes/pki/controller-manager-key.pem \
--embed-certs=true \
--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig

#使用某个环境当做默认环境
kubectl config use-context system:kube-controller-manager@kubernetes \
--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig
```

### 3.kube-scheduler

```bash
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true \
--server=https://192.168.2.4:6443 \
--kubeconfig=/etc/kubernetes/scheduler.kubeconfig


kubectl config set-context system:kube-scheduler@kubernetes \
--cluster=kubernetes \
--user=system:kube-scheduler \
--kubeconfig=/etc/kubernetes/scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
--client-certificate=/etc/kubernetes/pki/scheduler.pem \
--client-key=/etc/kubernetes/pki/scheduler-key.pem \
--embed-certs=true \
--kubeconfig=/etc/kubernetes/scheduler.kubeconfig

kubectl config use-context system:kube-scheduler@kubernetes \
--kubeconfig=/etc/kubernetes/scheduler.kubeconfig
```

### 4.admin

```bash
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true \
--server=https://192.168.2.4:6443 \
--kubeconfig=/etc/kubernetes/admin.kubeconfig

kubectl config set-credentials kubernetes-admin \
--client-certificate=/etc/kubernetes/pki/admin.pem \
--client-key=/etc/kubernetes/pki/admin-key.pem \
--embed-certs=true \
--kubeconfig=/etc/kubernetes/admin.kubeconfig


kubectl config set-context kubernetes-admin@kubernetes \
--cluster=kubernetes \
--user=kubernetes-admin \
--kubeconfig=/etc/kubernetes/admin.kubeconfig

kubectl config use-context kubernetes-admin@kubernetes \
--kubeconfig=/etc/kubernetes/admin.kubeconfig
```

## 四、配置master节点

### 1.配置etcd

#### 1.1 生成etcd配置文件

```bash
cat <<EOF > /etc/etcd/etcd.config.yml
name: 'k8s-master01'
data-dir: /var/lib/etcd
wal-dir: /var/lib/etcd/wal
snapshot-count: 5000
heartbeat-interval: 100
election-timeout: 1000
quota-backend-bytes: 0
listen-peer-urls: 'https://192.168.2.4:2380'
listen-client-urls: 'https://192.168.2.4:2379,http://127.0.0.1:2379'
max-snapshots: 3
max-wals: 5
cors:
initial-advertise-peer-urls: 'https://192.168.2.4:2380'
advertise-client-urls: 'https://192.168.2.4:2379'
discovery:
discovery-fallback: 'proxy'
discovery-proxy:
discovery-srv:
initial-cluster: 'k8s-master01=https://192.168.2.4:2380'
initial-cluster-token: 'etcd-k8s-cluster'
initial-cluster-state: 'new'
strict-reconfig-check: false
enable-v2: true
enable-pprof: true
proxy: 'off'
proxy-failure-wait: 5000
proxy-refresh-interval: 30000
proxy-dial-timeout: 1000
proxy-write-timeout: 5000
proxy-read-timeout: 0
client-transport-security:
  cert-file: '/etc/kubernetes/pki/etcd/etcd.pem'
  key-file: '/etc/kubernetes/pki/etcd/etcd-key.pem'
  client-cert-auth: true
  trusted-ca-file: '/etc/kubernetes/pki/etcd/etcd-ca.pem'
  auto-tls: true
peer-transport-security:
  cert-file: '/etc/kubernetes/pki/etcd/etcd.pem'
  key-file: '/etc/kubernetes/pki/etcd/etcd-key.pem'
  peer-client-cert-auth: true
  trusted-ca-file: '/etc/kubernetes/pki/etcd/etcd-ca.pem'
  auto-tls: true
debug: false
log-package-levels:
log-outputs: [default]
force-new-cluster: false
EOF
```

#### 1.2 生成etcd systemd启动脚本

```bash
cat <<EOF > /usr/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Service
Documentation=https://coreos.com/etcd/docs/latest/
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd --config-file=/etc/etcd/etcd.config.yml
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
Alias=etcd3.service
EOF
```

#### 1.3 启动etcd并配置为开启启动

```bash
systemctl daemon-reload && systemctl enable --now etcd
```

### 2.配置kube-apiserver

#### 2.1 生成kube-apiserver systemd启动脚本

```bash
cat <<EOF > /usr/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
      --v=2  \\
      --logtostderr=true  \\
      --allow-privileged=true  \\
      --bind-address=0.0.0.0  \\
      --secure-port=6443  \\
      --insecure-port=0  \\
      --advertise-address=192.168.2.4 \\
      --service-cluster-ip-range=10.96.0.0/12  \\
      --service-node-port-range=30000-32767  \\
      --etcd-servers=https://192.168.2.4:2379 \\
      --etcd-cafile=/etc/etcd/ssl/etcd-ca.pem  \\
      --etcd-certfile=/etc/etcd/ssl/etcd.pem  \\
      --etcd-keyfile=/etc/etcd/ssl/etcd-key.pem  \\
      --client-ca-file=/etc/kubernetes/pki/ca.pem  \\
      --tls-cert-file=/etc/kubernetes/pki/apiserver.pem  \\
      --tls-private-key-file=/etc/kubernetes/pki/apiserver-key.pem  \\
      --kubelet-client-certificate=/etc/kubernetes/pki/apiserver.pem  \\
      --kubelet-client-key=/etc/kubernetes/pki/apiserver-key.pem  \\
      --service-account-key-file=/etc/kubernetes/pki/sa.pub  \\
      --service-account-signing-key-file=/etc/kubernetes/pki/sa.key  \\
      --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
      --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname  \\
      --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,ResourceQuota  \\
      --authorization-mode=Node,RBAC  \\
      --enable-bootstrap-token-auth=true  \\
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.pem  \\
      --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.pem  \\
      --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client-key.pem  \\
      --requestheader-allowed-names=aggregator  \\
      --requestheader-group-headers=X-Remote-Group  \\
      --requestheader-extra-headers-prefix=X-Remote-Extra-  \\
      --requestheader-username-headers=X-Remote-User
      # --token-auth-file=/etc/kubernetes/token.csv

Restart=on-failure
RestartSec=10s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
```

#### 2.2 启动kube-apiserver并配置为开机启动

```bash
systemctl daemon-reload && systemctl enable --now kube-apiserver
```

### 3.配置kube-controller-manager

#### 3.1生成kube-controller-manager systemd启动脚本

```bash
cat << EOF >  /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
      --v=2 \\
      --logtostderr=true \\
      --address=0.0.0.0 \\
      --root-ca-file=/etc/kubernetes/pki/ca.pem \\
      --cluster-signing-cert-file=/etc/kubernetes/pki/ca.pem \\
      --cluster-signing-key-file=/etc/kubernetes/pki/ca-key.pem \\
      --service-account-private-key-file=/etc/kubernetes/pki/sa.key \\
      --kubeconfig=/etc/kubernetes/controller-manager.kubeconfig \\
      --leader-elect=true \\
      --use-service-account-credentials=true \\
      --node-monitor-grace-period=40s \\
      --node-monitor-period=5s \\
      --pod-eviction-timeout=2m0s \\
      --controllers=*,bootstrapsigner,tokencleaner \\
      --allocate-node-cidrs=true \\
      --cluster-cidr=172.16.0.0/12 \\
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.pem \\
      --node-cidr-mask-size=24 \\
      --cluster-signing-duration=876000h0m0s
      
      
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
```

#### 3.2启动kube-controller-manager并配置为开机启动

```bash
systemctl daemon-reload && systemctl enable --now kube-controller-manager
```

### 4.配置kube-scheduler

#### 4.1 生成kube-scheduler systemd启动脚本

```bash
cat << EOF > /usr/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
      --v=2 \\
      --logtostderr=true \\
      --address=0.0.0.0 \\
      --leader-elect=true \\
      --kubeconfig=/etc/kubernetes/scheduler.kubeconfig

Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
```

#### 4.2 启动kube-scheduler并配置为开机启动

```bash
systemctl daemon-reload && systemctl enable --now kube-scheduler
```

### 5.TLS Bootstrapping配置

#### 5.1生成bootstrap-kubelet.kubeconfig

```bash
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true \
--server=https://192.168.2.4:6443 \
--kubeconfig=/etc/kubernetes/bootstrap-kubelet.kubeconfig


kubectl config set-credentials tls-bootstrap-token-user \
--token=c8ad9c.2e4d610cf3e7426e \
--kubeconfig=/etc/kubernetes/bootstrap-kubelet.kubeconfig


kubectl config set-context tls-bootstrap-token-user@kubernetes \
--cluster=kubernetes \
--user=tls-bootstrap-token-user \
--kubeconfig=/etc/kubernetes/bootstrap-kubelet.kubeconfig


kubectl config use-context tls-bootstrap-token-user@kubernetes \
--kubeconfig=/etc/kubernetes/bootstrap-kubelet.kubeconfig
```

#### 5.2 复制kube admin配置文件到指定位置

```bash
mkdir -p /root/.kube && cp /etc/kubernetes/admin.kubeconfig /root/.kube/config
```

#### 5.3 生成kubernets bootstrap相关系统资源

```bash
cd k8s_learn_doc/install_resource/bootstrap
```

```bash
kubectl create -f bootstrap.secret.yaml
```

## 五、配置node节点

无特殊标注的，均在master节点操作

### 1.kubelet配置

#### 1.1 发送二进制文件

```bash
WorkNodes='k8s-node01 k8s-node02'

cd /etc/kubernetes/
for NODE in $WorkNodes; do
     scp /usr/local/bin/kube{let,-proxy} $NODE:/usr/local/bin/
done
```

#### 1.2 生成kubelet systemd启动脚本

```bash
cat << EOF > /usr/lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet

Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

```bash
cat << EOF > /etc/systemd/system/kubelet.service.d/10-kubelet.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig"
Environment="KUBELET_SYSTEM_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_CONFIG_ARGS=--config=/etc/kubernetes/kubelet-conf.yaml --pod-infra-container-image=registry.cn-qingdao.aliyuncs.com/zz_google_containers/pause-amd64:3.2"
Environment="KUBELET_EXTRA_ARGS=--tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 --image-pull-progress-deadline=30m "
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_SYSTEM_ARGS \$KUBELET_EXTRA_ARGS
EOF
```

#### 1.3 生成kubelet的配置文件

```bash
cat << EOF > /etc/kubernetes/kubelet-conf.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.pem
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
cgroupDriver: systemd
cgroupsPerQOS: true
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
containerLogMaxFiles: 5
containerLogMaxSize: 10Mi
contentType: application/vnd.kubernetes.protobuf
cpuCFSQuota: true
cpuManagerPolicy: none
cpuManagerReconcilePeriod: 10s
enableControllerAttachDetach: true
enableDebuggingHandlers: true
enforceNodeAllocatable:
- pods
eventBurst: 10
eventRecordQPS: 5
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionPressureTransitionPeriod: 5m0s
failSwapOn: true
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
kubeAPIBurst: 10
kubeAPIQPS: 5
makeIPTablesUtilChains: true
maxOpenFiles: 1000000
maxPods: 110
nodeStatusUpdateFrequency: 10s
oomScoreAdj: -999
podPidsLimit: -1
registryBurst: 10
registryPullQPS: 5
resolvConf: /etc/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 2m0s
serializeImagePulls: true
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 4h0m0s
syncFrequency: 1m0s
volumeStatsAggPeriod: 1m0s
rotateServerCertificates: true
allowedUnsafeSysctls:
 - "net.core*"
 - "net.ipv4.*"
kubeReserved:
  cpu: "1"
  memory: 1Gi
  ephemeral-storage: 10Gi
systemReserved:
  cpu: "1"
  memory: 1Gi
  ephemeral-storage: 10Gi
EOF
```

#### 1.4 启动master的kubelet并配置为开机启动

```bash
systemctl daemon-reload && systemctl enable --now kubelet
```

#### 1.5 发送证书和配置文件到其他节点

```bash
WorkNodes='k8s-node01 k8s-node02'

cd /etc/kubernetes/
for NODE in $WorkNodes; do
     for FILE in pki/ca.pem pki/ca-key.pem pki/front-proxy-ca.pem bootstrap-kubelet.kubeconfig; do
       scp /etc/kubernetes/$FILE $NODE:/etc/kubernetes/${FILE}
     done
     scp /usr/lib/systemd/system/kubelet.service $NODE:/usr/lib/systemd/system/
     scp /etc/systemd/system/kubelet.service.d/10-kubelet.conf $NODE:/etc/systemd/system/kubelet.service.d/
     scp /etc/kubernetes/kubelet-conf.yaml $NODE:/etc/kubernetes/
     ssh $NODE "systemctl daemon-reload && systemctl enable --now kubelet"
done
```

### 2.kube-proxy配置

#### 2.1 生成kube-proxy.kubeconfig配置文件

```bash
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/pki/ca.pem \
--embed-certs=true \
--server=https://192.168.2.4:6443 \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig


kubectl config set-context system:kube-proxy@kubernetes \
--cluster=kubernetes \
--user=system:kube-proxy \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
--client-certificate=/etc/kubernetes/pki/kube-proxy.pem \
--client-key=/etc/kubernetes/pki/kube-proxy-key.pem \
--embed-certs=true \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig

kubectl config use-context system:kube-proxy@kubernetes \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig
```

#### 2.2 生成kube-proxy systemd启动脚本

```bash
cat << EOF > /usr/lib/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/etc/kubernetes/kube-proxy-conf.yaml \\
  --v=2

Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
```

#### 2.3 生成kube-proxy配置文件

```bash
cat << EOF > /etc/kubernetes/kube-proxy-conf.yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
clientConnection:
  acceptContentTypes: ""
  burst: 10
  contentType: application/vnd.kubernetes.protobuf
  kubeconfig: /etc/kubernetes/kube-proxy.kubeconfig
  qps: 5
clusterCIDR: 172.16.0.0/12
configSyncPeriod: 15m0s
conntrack:
  max: null
  maxPerCore: 32768
  min: 131072
  tcpCloseWaitTimeout: 1h0m0s
  tcpEstablishedTimeout: 24h0m0s
enableProfiling: false
healthzBindAddress: 0.0.0.0:10256
hostnameOverride: ""
iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: 0s
  syncPeriod: 30s
ipvs:
  masqueradeAll: true
  minSyncPeriod: 5s
  scheduler: "rr"
  syncPeriod: 30s
kind: KubeProxyConfiguration
metricsBindAddress: 127.0.0.1:10249
mode: "ipvs"
nodePortAddresses: null
oomScoreAdj: -999
portRange: ""
udpIdleTimeout: 250ms
EOF
```

#### 2.4 启动master kube-proxy并配置开机启动

```bash
systemctl daemon-reload && systemctl enable --now kube-proxy
```

#### 2.5 发送所有kube-proxy配置文件到其他节点

```bash
WorkNodes='k8s-node01 k8s-node02'

for NODE in $WorkNodes; do
     scp /etc/kubernetes/kube-proxy.kubeconfig $NODE:/etc/kubernetes/kube-proxy.kubeconfig
     scp /usr/lib/systemd/system/kube-proxy.service $NODE:/usr/lib/systemd/system/
     scp /etc/kubernetes/kube-proxy-conf.yaml $NODE:/etc/kubernetes/
     ssh $NODE "systemctl daemon-reload && systemctl enable --now kube-proxy"
done
```

## 六、配置k8s节点角色

master节点

```bash
kubectl label nodes k8s-master01 node-role.kubernetes.io/master=
```

node节点

```bash
kubectl label nodes k8s-node01 k8s-node02 node-role.kubernetes.io/node=
```

配置master节点不接受负载

```bash
kubectl taint node k8s-master01 master=true:NoSchedule
```

## 七、安装Calico

在master节点操作

### 1.下载calico资源文件

```bash
wget https://docs.projectcalico.org/manifests/calico-etcd.yaml
```

### 2.修改calico配置文件

```bash
sed -i 's#etcd_endpoints: "http://<ETCD_IP>:<ETCD_PORT>"#etcd_endpoints: "https://192.168.2.4:2379"#g' calico-etcd.yaml

ETCD_CA=`cat /etc/kubernetes/pki/etcd/etcd-ca.pem | base64 | tr -d '\n'`
ETCD_CERT=`cat /etc/kubernetes/pki/etcd/etcd.pem | base64 | tr -d '\n'`
ETCD_KEY=`cat /etc/kubernetes/pki/etcd/etcd-key.pem | base64 | tr -d '\n'`

sed -i "s@# etcd-key: null@etcd-key: ${ETCD_KEY}@g; s@# etcd-cert: null@etcd-cert: ${ETCD_CERT}@g; s@# etcd-ca: null@etcd-ca: ${ETCD_CA}@g" calico-etcd.yaml


sed -i 's#etcd_ca: ""#etcd_ca: "/calico-secrets/etcd-ca"#g; s#etcd_cert: ""#etcd_cert: "/calico-secrets/etcd-cert"#g; s#etcd_key: "" #etcd_key: "/calico-secrets/etcd-key" #g' calico-etcd.yaml

# 更改此处为自己的pod网段
POD_SUBNET="172.16.0.0/12"

sed -i 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g; s@#   value: "192.168.0.0/16"@  value: '"${POD_SUBNET}"'@g' calico-etcd.yaml

#关闭IPIP模式，如网络环境不是二层互联的可以不操作此步
sed -i 's#value: "Always"#value: "Never"#g' calico-etcd.yaml
```

### 3.安装calico

```bash
kubectl apply -f calico-etcd.yaml
```

## 八、安装coredns

### 1.下载coredns安装文件

```bash
git clone https://github.com/coredns/deployment.git
```

### 2.部署coredns

```bash
cd deployment/kubernetes
./deploy.sh -s -i 10.96.0.10 | kubectl apply -f -
```

## 九、安装ingress-nginx

### 1.给需要部署Ingress的节点打标签

```bash
kubectl label nodes k8s-node01 k8s-node02  ingress=true
```

### 2.安装ingress

```bash
cd k8s_learn_doc/install_resource/ingress_nginx
kubectl create -f deploy.yaml
```
