# Kubernetes 1.28.1 集群搭建手册

## 1、安装
### 安装docker及docker
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
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

### 安装Kubernetes
Docker Engine 没有实现 CRI， 而这是容器运行时在 Kubernetes 中工作所需要的。 为此，必须安装一个额外的服务 cri-dockerd。 cri-dockerd 是一个基于传统的内置 Docker 引擎支持的项目， 它在 1.24 版本从 kubelet 中移除。

{{< tabs name="k8s_install" >}}
{{% tab name="基于 Debian 的发行版" %}}

<!--
1. Update the `apt` package index and install packages needed to use the Kubernetes `apt` repository:
-->
1. 更新 `apt` 包索引并安装使用 Kubernetes `apt` 仓库所需要的包：

   ```shell
   sudo apt-get update
   sudo apt-get install -y apt-transport-https ca-certificates curl
   ```

<!--
2. Download the Google Cloud public signing key:
-->
2. 下载 Google Cloud 公开签名秘钥：

   ```shell
   curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
   ```

<!--
3. Add the Kubernetes `apt` repository:
-->
3. 添加 Kubernetes `apt` 仓库：

   ```shell
   echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
   ```

<!--
4. Update `apt` package index, install kubelet, kubeadm and kubectl, and pin their version:
-->
4. 更新 `apt` 包索引，安装 kubelet、kubeadm 和 kubectl，并锁定其版本：

   ```shell
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   sudo apt-mark hold kubelet kubeadm kubectl
   ```
{{< note >}}
<!--
In releases older than Debian 12 and Ubuntu 22.04, `/etc/apt/keyrings` does not exist by default.
You can create this directory if you need to, making it world-readable but writeable only by admins.
-->
在低于 Debian 12 和 Ubuntu 22.04 的发行版本中，`/etc/apt/keyrings` 默认不存在。
如有需要，你可以创建此目录，并将其设置为对所有人可读，但仅对管理员可写。
{{< /note >}}

{{% /tab %}}

{{% tab name="基于 Red Hat 的发行版" %}}

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

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

{{% /tab %}}
{{% tab name="无包管理器的情况" %}}
<!--
Install CNI plugins (required for most pod network):
-->
安装 CNI 插件（大多数 Pod 网络都需要）：

```bash
CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz
```

<!--
Define the directory to download command files
-->
定义要下载命令文件的目录。

{{< note >}}
<!--
The `DOWNLOAD_DIR` variable must be set to a writable directory.
If you are running Flatcar Container Linux, set `DOWNLOAD_DIR="/opt/bin"`.
-->
`DOWNLOAD_DIR` 变量必须被设置为一个可写入的目录。
如果你在运行 Flatcar Container Linux，可设置 `DOWNLOAD_DIR="/opt/bin"`。
{{< /note >}}

```bash
DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
```

<!--
Install crictl (required for kubeadm / Kubelet Container Runtime Interface (CRI))
-->
安装 crictl（kubeadm/kubelet 容器运行时接口（CRI）所需）

```bash
CRICTL_VERSION="v1.27.0"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
```

<!--
Install `kubeadm`, `kubelet`, `kubectl` and add a `kubelet` systemd service:
-->
安装 `kubeadm`、`kubelet`、`kubectl` 并添加 `kubelet` 系统服务：

```bash
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
ARCH="amd64"
cd $DOWNLOAD_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

RELEASE_VERSION="v0.15.1"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

<!--
Install `kubectl` by following the instructions on [Install Tools page](/docs/tasks/tools/#kubectl).
Enable and start `kubelet`:
-->
请参照[安装工具页面](/zh-cn/docs/tasks/tools/#kubectl)的说明安装 `kubelet`。
激活并启动 `kubelet`：

```bash
systemctl enable --now kubelet
```

{{< note >}}
<!--
The Flatcar Container Linux distribution mounts the `/usr` directory as a read-only filesystem.
Before bootstrapping your cluster, you need to take additional steps to configure a writable directory.
See the [Kubeadm Troubleshooting guide](/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/#usr-mounted-read-only/) to learn how to set up a writable directory.
-->
Flatcar Container Linux 发行版会将 `/usr/` 目录挂载为一个只读文件系统。
在启动引导你的集群之前，你需要执行一些额外的操作来配置一个可写入的目录。
参见 [kubeadm 故障排查指南](/zh-cn/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/#usr-mounted-read-only/)
以了解如何配置一个可写入的目录。
{{< /note >}}

{{% /tab %}}
{{< /tabs >}}

<!--
The kubelet is now restarting every few seconds, as it waits in a crashloop for
kubeadm to tell it what to do.
-->
kubelet 现在每隔几秒就会重启，因为它陷入了一个等待 kubeadm 指令的死循环。
