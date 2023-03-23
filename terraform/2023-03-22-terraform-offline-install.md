Terraform离线环境使用

### 初始文件准备

#### 获取 terraform bin文件
先准备一台可联网的Centos/RHEL，安装terraform 或者把terraform的安装文件下载下来

官方文档：支持 MAC，Win，Linux  
https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli

Centos/RHEL  
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform
```

检查版本
```bash
[root@centos8 azure-terraform]# terraform version
Terraform v1.3.9
on linux_amd64
+ provider registry.terraform.io/hashicorp/azurerm v3.44.1

[root@centos8 test]# whereis terraform
terraform: /usr/bin/terraform
```

把 /usr/bin/terraform 文件上传到离线环境

#### 获取 terraform 插件
新建一个目录，创建要用的 providers.tf 文件，文件中定义好要使用的插件，比如此处是 azurerm 不低于3.0版本  
执行 terraform init 则会依照版本要求下载最新的插件，存放路径为当前目录的 .terraform  
将来要使用其他插件，也是在此文件定义插件版本，执行 init 命令自动下载插件  

```bash
mkdir test
cd test/

# 新建 providers.tf 文件
[root@centos8 test]# cat providers.tf
terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 初始化插件
[root@centos8 test]# terraform init

[root@centos8 test]# tree .terraform
.terraform
└── providers
    └── registry.terraform.io
        └── hashicorp
            └── azurerm
                └── 3.48.0
                    └── linux_amd64
                        └── terraform-provider-azurerm_v3.48.0_x5


# 把插件打包
tar -czvf  providers.tgz .terraform/providers/
```

### terraform 离线环境安装配置

把 terraform bin文件和 providers.tgz 上传到离线环境 $HOME

#### bin 文件和插件导入

bin文件导入
```bash
sudo chmod +x terraform
sudo mv terraform /usr/local/bin/

# 如果没有 sudo 权限，就放在自己目录
mkdir $HOME/bin
mv terraform $HOME/bin

# 检查版本
[caifeng@cnacebasy0008l ~]$ terraform version
Terraform v1.3.9
on linux_amd64

# 开启命令自动补全，执行完重新进入下bas窗口
touch ~/.bashrc
terraform -install-autocomplete
```

导入插件

```bash
cd $HOME
tar -zxvf providers.tgz

# 目录结构如下
/home/caifeng
[caifeng@cnacebasy0008l ~]$ pwd
/home/caifeng
[caifeng@cnacebasy0008l ~]$ tree .terraform/
.terraform/
└── providers
    └── registry.terraform.io
        └── hashicorp
            └── azurerm
                └── 3.48.0
                    └── linux_amd64
                        └── terraform-provider-azurerm_v3.48.0_x5


6 directories, 1 file

```

#### 环境配置

由于 terraform init 默认会联网下载插件，并存放在当前目录的 .terraform，所以需要指定插件路径，一旦指定了插件路径，路径下没有对应插件，init 就会报错，即使电脑能联网也不会去联网下载。

创建 providers.tf  
注意 version 要指定当前插件的具体版本，不可模糊匹配。 provider 里中国区环境添加 environment = "china",global 环境去掉这行  

```bash
terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }
}

provider "azurerm" {
  environment = "china"
  features {}
}

```

**init 方法1：**  
手动指定插件
```bash
terraform init -plugin-dir=$HOME/.terraform/providers
```

输出
```bash
[caifeng@cnacebasy0008l CNAZE2UAKSVPMS01]$ terraform init -plugin-dir=$HOME/.terraform/providers

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "3.48.0"...
- Installing hashicorp/azurerm v3.48.0...
- Installed hashicorp/azurerm v3.48.0 (unauthenticated)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

╷
│ Warning: Incomplete lock file information for providers
│
│ Due to your customized provider installation methods, Terraform was forced to calculate lock file checksums locally for the following
│ providers:
│   - hashicorp/azurerm
│
│ The current .terraform.lock.hcl file only includes checksums for linux_amd64, so Terraform running on another platform will fail to install
│ these providers.
│
│ To calculate additional checksums for another platform, run:
│   terraform providers lock -platform=linux_amd64
│ (where linux_amd64 is the platform to generate)
╵

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

```bash
[caifeng@cnacebasy0008l CNAZE2UAKSVPMS01]$ cat .terraform/plugin_path
[
  "/home/caifeng/.terraform/providers"

```

**init 方法2：**  
```bash
vim ~/.terraformrc

[root@centos8 test]# cat ~/.terraformrc
provider_installation {
  filesystem_mirror {
    path    = "/root/.terraform/providers"
    include = ["registry.terraform.io/*/*"]
  }
}
```

init 找不到文件的话，重新ssh登入下。


### backup  
以下使用服务主体认证的方式 providers.tf 写法，留作备用，这次不需要。  
国内21世纪环境要写 environment = "china" ，global 环境不需要。

```bash
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
  environment = "china"
  subscription_id   = "<azure_subscription_id>"
  tenant_id         = "<azure_subscription_tenant_id>"
  client_id         = "<service_principal_appid>"
  client_secret     = "<service_principal_password>"
}
```

### 参考文档
https://lonegunmanb.github.io/introduction-terraform/5.1.%E5%91%BD%E4%BB%A4%E8%A1%8C%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6.html

关注我的github，后续更新会同步上去

https://github.com/cai11745/hybrid-cloud

