# Kubernetes 1.28.1 集群搭建手册

## 1 环境准备
### 1.1 安装docker及docker
#### 更新yum源为浙大镜像源
```
sed -e 's|^mirrorlist=|#mirrorlist=|g' \
         -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.zju.edu.cn|g' \
         -i.bak \
         /etc/yum.repos.d/CentOS-*.repo
yum makecache
```
#### 安装前卸载旧版本docker
```
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
```

#### 添加docker仓库
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

#### 安装
sudo yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#### 设置开机自启
systemctl enable docker --now

### 1.2 安装cri-dockerd
Docker Engine 没有实现 CRI， 而这是容器运行时在 Kubernetes 中工作所需要的。 为此，必须安装一个额外的服务 cri-dockerd。 cri-dockerd 是一个基于传统的内置 Docker 引擎支持的项目， 它在 1.24 版本从 kubelet 中移除。
#### 
```
cd ~
wget  wget https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.4/cri-dockerd-0.3.4.amd64.tgz
tar xvf cri-dockerd-0.3.4.amd64.tgz
mv cri-dockerd/cri-dockerd /usr/bin

# test
cri-dockerd --version

wget https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/raw/master/packaging/systemd/cri-docker.socket
wget https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/raw/master/packaging/systemd/cri-docker.service
mv cri-docker.socket cri-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket
```

### 1.3 转发 IPv4 并让 iptables 看到桥接流量
```
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 设置所需的 sysctl 参数，参数在重新启动后保持不变
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system
```

通过运行以下指令确认 `br_netfilter` 和 `overlay` 模块被加载：

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
```
通过运行以下指令确认 `net.bridge.bridge-nf-call-iptables`、`net.bridge.bridge-nf-call-ip6tables`
和 `net.ipv4.ip_forward` 系统变量在你的 `sysctl` 配置中被设置为 1：

```bash
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

### 1.4 关闭防火墙
```
systemctl stop firewalld
systemctl disable firewalld
```

### 1.5 修改hostname，并写入/etc/hosts
注意hostname仅使用小写字母与'-', 不要使用下划线'_'

### 1.6 cgroup

## 2 基于 Red Hat 的发行版安装kubeadm kubelet kubectl

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# 使用aliyun镜像源替代google
sed -i 's#packages.cloud.google.com#mirrors.aliyun.com/kubernetes#g' /etc/yum.repos.d/kubernetes.repo

# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 不加版本号则为最新版
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet
```

<!--
  **Notes:**

  - Setting SELinux in permissive mode by running `setenforce 0` and `sed ...` effectively disables it.
    This is required to allow containers to access the host filesystem, which is needed by pod networks for example.
    You have to do this until SELinux support is improved in the kubelet.

  - You can leave SELinux enabled if you know how to configure it but it may require settings that are not supported by kubeadm.

  - If the `baseurl` fails because your Red Hat-based distribution cannot interpret `basearch`, replace `\$basearch` with your computer's architecture.
  Type `uname -m` to see that value.
  For example, the `baseurl` URL for `x86_64` could be: `https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64`.
-->
**请注意：**

- 通过运行命令 `setenforce 0` 和 `sed ...` 将 SELinux 设置为 permissive 模式可以有效地将其禁用。
  这是允许容器访问主机文件系统所必需的，而这些操作是为了例如 Pod 网络工作正常。

  你必须这么做，直到 kubelet 做出对 SELinux 的支持进行升级为止。

- 如果你知道如何配置 SELinux 则可以将其保持启用状态，但可能需要设定 kubeadm 不支持的部分配置

- 如果由于该 Red Hat 的发行版无法解析 `basearch` 导致获取 `baseurl` 失败，请将 `\$basearch` 替换为你计算机的架构。
  输入 `uname -m` 以查看该值。
  例如，`x86_64` 的 `baseurl` URL 可以是：`https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64`。

## 3 集群初始化
### 3.1 拉取需要的image，使用如下命令可以获取当前k8s需要拉取的image版本
```
kubeadm config images list
```
可直接使用如下脚本从阿里云拉取镜像并更改tag
```
vi pull_k8s_image.sh
```

```
#!/bin/bash

set -e

for image in $( kubeadm config images list | sed 's#registry.k8s.io#registry.aliyuncs.com/google_containers#g' )
do
  echo $image
  docker pull $image
  docker tag $image $(echo $image | sed 's#registry.aliyuncs.com/google_containers#registry.k8s.io#g')
  docker rmi $image
  echo ------------------------------------------
  echo ------------------------------------------
done
```
执行此脚本拉取镜像
```
bash pull_k8s_image.sh
```
** coredns可能下载失败，手动pull更改tag解决 **
```
docker pull coredns/coredns:1.10.1
docker tag coredns/coredns:1.10.1 registry.k8s.io/coredns/coredns:v1.10.1
docker rmi coredns/coredns:1.10.1
```

### 3.2 init并加入集群
```
kubeadm init \
  --apiserver-advertise-address=192.168.198.101 \
  --cri-socket unix:///var/run/cri-dockerd.sock \
  --control-plane-endpoint=cluster-endpoint \
  --kubernetes-version v1.28.1 \
  --service-cidr=10.1.0.0/16 \
  --pod-network-cidr=10.244.0.0/16 \
  --v=5
```
#### 有可能缺失pause:3.6, 补充后再执行kubeadm reset --cri-socket unix:///var/run/cri-dockerd.sock再执行init
```
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6 registry.k8s.io/pause:3.6
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6
```

#### init成功后执行，改命令会在init时提示
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### (node)同上
```
kubeadm join cluster-endpoint:6443 --token 64aec8.cmw1rlpwnlxd6iuy \
         --cri-socket unix:///var/run/cri-dockerd.sock \
         --discovery-token-ca-cert-hash sha256:e1d05d55d8ece9c16b48047aff2f86318c05cf2f416c238965adf7304bac867c
```

### 3.3 安装网络插件（CNI）

```
kubelet create -f https://raw.githubusercontent.com/projectcalico/calico/release-v3.26/manifests/tigera-operator.yaml
```
使用kubectl get pods -n tigera-operator, pod运行后下载下面文件，并修改cidr为kubeadm init指定的网段
```
wget https://raw.githubusercontent.com/projectcalico/calico/release-v3.26/manifests/custom-resources.yaml
```

修改完成后执行
```
kubectl create -f custom-resources.yaml
```

## 4 部署应用
...
