# My VPN Server

基于 **sing-box + Shadowsocks + Nginx** 构建的个人 VPN 节点部署项目。

本项目的目标是：

* 一键部署 Shadowsocks 服务端
* 支持 Shadowsocks 客户端
* 支持 Clash / Clash Meta
* 支持 sing-box 客户端
* 自动生成客户端配置
* 自动生成 Shadowsocks `ss://` 链接
* 自动生成二维码
* 通过 Nginx 提供订阅地址
* 支持后续扩展 HTTPS / 域名
* 服务端配置与客户端配置分离
* 支持重复部署到不同 VPS
* 修改配置后可以快速重新应用，无需重新安装

---

## 1. 整体架构

```text
                         Internet
                            │
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
          Shadowsocks :18188       Nginx :80
                 │                     │
                 │                     ▼
                 │              /随机TOKEN/subscribe.txt
                 │                     │
                 │                     ▼
                 │                Clash / SS
                 │
                 ▼
       ┌─────────────────────┐
       │     sing-box        │
       │  Shadowsocks Server │
       └─────────────────────┘
                 │
                 ▼
              Internet
```

客户端可以使用：

```text
Shadowsocks
Clash / Clash Meta
sing-box
```

配置生成关系：

```text
                     server.env
                         │
                         ▼
                 apply-config.sh
                         │
                         ▼
              /etc/sing-box/config.json
                         │
                         ▼
                    sing-box
```

同时：

```text
                     server.env
                         │
                         ▼
               generate-config.sh
                         │
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
     clash.yaml       ss.txt       sing-box.json
          │              │
          └──────┬───────┘
                 ▼
          subscribe.txt
                 │
                 ▼
              Nginx
```

---

# 2. 项目目录

推荐目录：

```text
/opt/my-vpn/
├── install.sh
├── apply-config.sh
├── generate-config.sh
├── nginx-setup.sh
├── uninstall.sh
├── server.env
├── clients/
│   ├── clash.yaml
│   ├── ss.txt
│   ├── ss.json
│   ├── sing-box.json
│   ├── subscribe.txt
│   └── ss.png
└── README.md
```

服务端 sing-box 配置：

```text
/etc/sing-box/
└── config.json
```

---

# 3. 脚本职责

| 文件                   | 作用                              |
| -------------------- | ------------------------------- |
| `install.sh`         | 首次安装整个 VPN 环境                   |
| `apply-config.sh`    | 将 `server.env` 应用到 sing-box 服务端 |
| `generate-config.sh` | 生成所有客户端配置                       |
| `nginx-setup.sh`     | 配置 Nginx 订阅服务                   |
| `uninstall.sh`       | 卸载 VPN 配置                       |
| `server.env`         | 整个项目的核心配置文件                     |
| `clients/`           | 自动生成的客户端配置                      |

核心设计原则：

> `install.sh` 只负责安装和初始化，不负责维护具体客户端配置。

以后修改配置时，不需要重新运行 `install.sh`。

---

# 4. 系统要求

推荐：

```text
OS:
Ubuntu 22.04 / Ubuntu 24.04

CPU:
1 Core+

Memory:
512 MB+

Network:
公网 IPv4

Privileges:
root
```

最低要求：

* 可以执行 `apt`
* 有公网 IPv4
* 可以开放 TCP 端口
* VPS 提供商允许自定义网络端口

---

# 5. 安装依赖

安装脚本会自动安装：

```text
curl
wget
jq
openssl
ca-certificates
unzip
iproute2
iputils-ping
dnsutils
lsof
qrencode
nginx
ufw
sing-box
```

其中：

```text
sing-box
```

负责：

```text
Shadowsocks Server
```

Nginx 负责：

```text
Subscription Server
```

qrencode 负责：

```text
Shadowsocks QR Code
```

---

# 6. 第一次部署

## 6.1 创建项目目录

```bash
mkdir -p /opt/my-vpn
cd /opt/my-vpn
```

将项目文件放入：

```text
/opt/my-vpn/
```

至少包含：

```text
install.sh
apply-config.sh
generate-config.sh
nginx-setup.sh
uninstall.sh
server.env
```

---

## 6.2 添加执行权限

```bash
chmod +x \
    /opt/my-vpn/install.sh \
    /opt/my-vpn/apply-config.sh \
    /opt/my-vpn/generate-config.sh \
    /opt/my-vpn/nginx-setup.sh \
    /opt/my-vpn/uninstall.sh
```

---

# 7. server.env

`server.env` 是整个项目的核心配置文件。

推荐模板：

```bash
SERVER_PORT=18188

SS_METHOD=aes-256-gcm
SS_PASSWORD=
NODE_NAME=US-Aliyun

PUBLIC_IP=

ENABLE_SUBSCRIPTION=true
SUBSCRIBE_TOKEN=

DOMAIN=

ENABLE_HTTPS=false
ACME_EMAIL=

NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

ENABLE_UFW=true
SSH_PORT=22
```

---

# 8. server.env 参数说明

## 8.1 SERVER_PORT

Shadowsocks 服务端监听端口。

默认：

```bash
SERVER_PORT=18188
```

例如：

```bash
SERVER_PORT=443
```

注意：

修改以后必须重新执行：

```bash
./apply-config.sh
./generate-config.sh
```

同时确保 VPS 安全组允许对应端口。

---

## 8.2 SS_METHOD

Shadowsocks 加密方式。

当前：

```bash
SS_METHOD=aes-256-gcm
```

服务端和客户端必须保持一致。

---

## 8.3 SS_PASSWORD

Shadowsocks 密码。

可以留空：

```bash
SS_PASSWORD=
```

首次执行：

```bash
./install.sh
```

时，系统会自动生成随机密码。

也可以手动指定：

```bash
SS_PASSWORD=your-strong-password
```

建议使用长度较长的随机密码。

---

## 8.4 NODE_NAME

客户端显示的节点名称。

例如：

```bash
NODE_NAME=US-Aliyun
```

Clash 中会显示：

```text
US-Aliyun
```

---

## 8.5 PUBLIC_IP

服务器公网 IP。

一般建议：

```bash
PUBLIC_IP=
```

由脚本自动检测。

如果 VPS 有多个公网 IP，可以手动指定：

```bash
PUBLIC_IP=1.2.3.4
```

---

## 8.6 ENABLE_SUBSCRIPTION

是否启用 Nginx 订阅。

启用：

```bash
ENABLE_SUBSCRIPTION=true
```

关闭：

```bash
ENABLE_SUBSCRIPTION=false
```

推荐开启。

---

## 8.7 SUBSCRIBE_TOKEN

订阅地址中的随机路径。

例如：

```text
http://1.2.3.4/8f31c9d1a2/subscribe.txt
```

其中：

```text
8f31c9d1a2
```

就是 Token。

可以留空：

```bash
SUBSCRIBE_TOKEN=
```

脚本会自动生成。

不要使用：

```text
subscribe
vpn
admin
test
123456
```

这种容易被猜测的路径。

---

## 8.8 DOMAIN

域名。

没有域名：

```bash
DOMAIN=
```

有域名：

```bash
DOMAIN=vpn.example.com
```

使用域名时，需要先把 DNS：

```text
vpn.example.com
```

解析到 VPS 公网 IP。

---

## 8.9 ENABLE_HTTPS

当前默认：

```bash
ENABLE_HTTPS=false
```

如果以后配置 Let's Encrypt：

```bash
ENABLE_HTTPS=true
```

同时需要：

```bash
DOMAIN=vpn.example.com
ACME_EMAIL=your@email.com
```

HTTPS 是订阅服务层面的配置，与 Shadowsocks 本身没有直接关系。

---

## 8.10 ENABLE_UFW

是否自动配置服务器内部 UFW。

启用：

```bash
ENABLE_UFW=true
```

脚本会开放：

```text
SSH
Shadowsocks
HTTP
HTTPS
```

但是：

> UFW 不等于云厂商安全组。

阿里云 ECS 仍然需要单独配置安全组。

---

## 8.11 SSH_PORT

SSH 端口。

默认：

```bash
SSH_PORT=22
```

如果服务器 SSH 使用其他端口，例如：

```bash
SSH_PORT=2222
```

必须修改。

否则开启 UFW 后可能导致 SSH 无法连接。

---

# 9. 推荐的第一次配置

如果当前目标只是测试美国 VPS 的网络效果：

```bash
SERVER_PORT=18188

SS_METHOD=aes-256-gcm
SS_PASSWORD=
NODE_NAME=US-Aliyun

PUBLIC_IP=

ENABLE_SUBSCRIPTION=true
SUBSCRIBE_TOKEN=

DOMAIN=

ENABLE_HTTPS=false
ACME_EMAIL=

NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

ENABLE_UFW=true
SSH_PORT=22
```

不要一开始就增加 HTTPS、域名等复杂因素。

先验证：

```text
VPS
 ↓
Shadowsocks
 ↓
手机 / PC
```

再验证：

```text
VPS
 ↓
Nginx
 ↓
订阅
 ↓
Clash
```

最后再增加：

```text
Domain
 ↓
HTTPS
 ↓
Subscription
```

---

# 10. 执行安装

进入项目目录：

```bash
cd /opt/my-vpn
```

执行：

```bash
./install.sh
```

安装过程包括：

```text
1. 安装系统依赖
2. 安装 sing-box
3. 安装 Nginx
4. 安装 qrencode
5. 创建 server.env
6. 配置 sing-box
7. 启动 sing-box
8. 生成客户端配置
9. 配置 Nginx
10. 配置 UFW
11. 执行健康检查
```

---

# 11. 安装完成后的文件

成功后：

```text
/opt/my-vpn/clients/
```

应该包含：

```text
clash.yaml
ss.txt
ss.json
sing-box.json
subscribe.txt
ss.png
```

---

# 12. Shadowsocks 客户端

查看 Shadowsocks URI：

```bash
cat /opt/my-vpn/clients/ss.txt
```

格式：

```text
ss://xxxxxxxxxxxxxxxx@SERVER_IP:18188#US-Aliyun
```

可以直接复制到支持 Shadowsocks URI 的客户端。

---

# 13. Shadowsocks 二维码

二维码：

```text
/opt/my-vpn/clients/ss.png
```

查看：

```bash
ls -lh /opt/my-vpn/clients/ss.png
```

可以将该图片下载到手机，然后扫码导入。

---

# 14. Clash

Clash 配置：

```text
/opt/my-vpn/clients/clash.yaml
```

内容结构：

```yaml
proxies:
  - name: "US-Aliyun"
    type: ss
    server: SERVER_IP
    port: 18188
    cipher: aes-256-gcm
    password: "PASSWORD"
```

可以将该 YAML 导入支持 Clash 配置的客户端。

---

# 15. sing-box

sing-box 客户端配置：

```text
/opt/my-vpn/clients/sing-box.json
```

主要用于 sing-box 客户端。

---

# 16. Nginx 订阅

开启：

```bash
ENABLE_SUBSCRIPTION=true
```

安装完成后会生成：

```text
/opt/my-vpn/clients/subscribe.txt
```

同时 Nginx 会暴露一个随机路径。

例如：

```text
http://SERVER_IP/8f31c9d1a2b3c4d5/subscribe.txt
```

如果配置了域名：

```text
http://vpn.example.com/8f31c9d1a2b3c4d5/subscribe.txt
```

客户端可以直接使用该 URL 作为订阅地址。

---

# 17. Nginx 安全设计

Nginx 不直接暴露整个：

```text
/opt/my-vpn/clients/
```

只允许访问：

```text
/<SUBSCRIBE_TOKEN>/subscribe.txt
```

例如：

```text
/8f31c9d1a2b3c4d5/subscribe.txt
```

其他路径：

```text
/
```

会返回：

```text
404
```

这样可以避免：

```text
/opt/my-vpn/clients/
```

下面的其他配置文件被直接下载。

---

# 18. 检查 Nginx

查看：

```bash
systemctl status nginx
```

检查配置：

```bash
nginx -t
```

查看监听端口：

```bash
ss -lntp | grep nginx
```

查看订阅：

```bash
curl http://127.0.0.1/<SUBSCRIBE_TOKEN>/subscribe.txt
```

正常应该返回：

```text
ss://xxxxxxxxxxxxxxxx@SERVER_IP:18188#US-Aliyun
```

---

# 19. 阿里云安全组

如果使用阿里云 ECS，除了 UFW，还需要在：

```text
阿里云控制台
→ ECS
→ 安全组
→ 入方向
```

开放：

```text
TCP 18188
TCP 80
```

如果以后启用 HTTPS：

```text
TCP 443
```

SSH：

```text
TCP 22
```

如果 SSH 使用其他端口，则使用实际端口。

---

# 20. 检查服务端端口

查看：

```bash
ss -lntp
```

应该看到类似：

```text
LISTEN 0 4096 0.0.0.0:18188
LISTEN 0 511  0.0.0.0:80
```

IPv6：

```text
[::]:18188
[::]:80
```

---

# 21. 检查 sing-box

查看状态：

```bash
systemctl status sing-box
```

只看运行状态：

```bash
systemctl is-active sing-box
```

查看日志：

```bash
journalctl -u sing-box -n 100 --no-pager
```

实时日志：

```bash
journalctl -u sing-box -f
```

---

# 22. 检查 sing-box 配置

配置文件：

```text
/etc/sing-box/config.json
```

检查：

```bash
sing-box check -c /etc/sing-box/config.json
```

格式化：

```bash
sing-box format -w -c /etc/sing-box/config.json
```

---

# 23. 修改配置

不要直接修改：

```text
/etc/sing-box/config.json
```

应该修改：

```text
/opt/my-vpn/server.env
```

例如：

```bash
vim /opt/my-vpn/server.env
```

然后：

```bash
./apply-config.sh
```

最后：

```bash
./generate-config.sh
```

---

# 24. 修改 Shadowsocks 密码

修改：

```bash
SS_PASSWORD=NEW_PASSWORD
```

执行：

```bash
./apply-config.sh
./generate-config.sh
```

新的配置会自动生成：

```text
ss.txt
ss.json
clash.yaml
sing-box.json
subscribe.txt
ss.png
```

---

# 25. 修改服务器端口

例如：

```bash
SERVER_PORT=443
```

执行：

```bash
./apply-config.sh
./generate-config.sh
```

同时检查：

```text
云厂商安全组
UFW
```

是否允许：

```text
TCP 443
```

---

# 26. 修改节点名称

例如：

```bash
NODE_NAME=US-CloudCone
```

执行：

```bash
./generate-config.sh
```

不需要重启 sing-box。

---

# 27. 修改订阅 Token

修改：

```bash
SUBSCRIBE_TOKEN=新的随机Token
```

然后：

```bash
./nginx-setup.sh
```

旧订阅地址会失效。

---

# 28. 推荐的配置修改流程

如果修改的是服务端参数：

```text
server.env
    ↓
apply-config.sh
    ↓
generate-config.sh
```

如果只是修改客户端显示名称：

```text
server.env
    ↓
generate-config.sh
```

如果修改订阅 Token / Nginx：

```text
server.env
    ↓
nginx-setup.sh
```

---

# 29. 完整健康检查

可以依次执行：

```bash
systemctl is-active sing-box
```

```bash
systemctl is-active nginx
```

```bash
sing-box check -c /etc/sing-box/config.json
```

```bash
nginx -t
```

```bash
ss -lntp
```

```bash
ufw status
```

检查订阅：

```bash
curl http://127.0.0.1/<SUBSCRIBE_TOKEN>/subscribe.txt
```

---

# 30. 常见问题

## 30.1 sing-box 启动失败

执行：

```bash
systemctl status sing-box --no-pager
```

然后：

```bash
journalctl -u sing-box -n 100 --no-pager
```

检查配置：

```bash
sing-box check -c /etc/sing-box/config.json
```

---

## 30.2 客户端连接不上

按照以下顺序检查：

```text
1. sing-box 是否运行
2. 18188 是否监听
3. UFW 是否放行
4. 阿里云安全组是否放行
5. 客户端 IP / 端口是否正确
6. Shadowsocks 密码是否正确
7. Shadowsocks 加密方式是否一致
```

---

## 30.3 Nginx 启动失败

执行：

```bash
nginx -t
```

查看：

```bash
systemctl status nginx
```

日志：

```bash
journalctl -u nginx -n 100 --no-pager
```

---

## 30.4 订阅 URL 打不开

检查：

```bash
systemctl status nginx
```

然后：

```bash
nginx -t
```

再：

```bash
curl http://127.0.0.1/<SUBSCRIBE_TOKEN>/subscribe.txt
```

如果本机可以访问，但是公网不能访问：

```text
优先检查：
阿里云安全组
UFW
公网 IP
```

---

## 30.5 端口监听正常，但是外网连接不上

这是 VPS 部署中非常常见的问题。

例如：

```bash
ss -lntp | grep 18188
```

显示：

```text
0.0.0.0:18188
```

并不代表公网一定可以连接。

需要同时检查：

```text
sing-box
    ↓
Ubuntu UFW
    ↓
阿里云安全组
    ↓
公网
```

任何一层阻断都可能导致连接失败。

---

# 31. Nginx 与 Shadowsocks 的关系

需要明确：

```text
Nginx
```

不是 Shadowsocks 服务端。

它只负责：

```text
订阅文件分发
```

真正提供代理能力的是：

```text
sing-box
```

即：

```text
客户端
  │
  ├── Shadowsocks → sing-box → Internet
  │
  └── HTTP Subscription → Nginx
```

所以：

> Nginx 挂了，Shadowsocks 节点本身仍然可能正常工作。

反过来：

> sing-box 挂了，订阅 URL 仍然可能可以访问，但节点无法连接。

---

# 32. 为什么要拆分脚本

本项目采用：

```text
install.sh
apply-config.sh
generate-config.sh
nginx-setup.sh
```

而不是把所有逻辑写进一个巨大脚本。

原因：

### install.sh

负责：

```text
安装
初始化
```

### apply-config.sh

负责：

```text
服务端配置
```

### generate-config.sh

负责：

```text
客户端配置
```

### nginx-setup.sh

负责：

```text
订阅服务
```

这样可以避免：

```text
修改客户端配置
↓
重新安装整个服务器
```

---

# 33. 推荐部署流程

第一次：

```bash
cd /opt/my-vpn
./install.sh
```

以后：

```text
修改 server.env
       ↓
根据修改内容执行对应脚本
       ↓
检查服务状态
       ↓
客户端刷新配置
```

---

# 34. 卸载

执行：

```bash
./uninstall.sh
```

脚本会删除：

```text
sing-box 配置
VPN 项目
Nginx VPN 配置
```

默认不会自动卸载：

```text
nginx
sing-box
ufw
```

因为这些可能被服务器上的其他服务使用。

---

# 35. 安全注意事项

## 35.1 不要公开 server.env

`server.env` 包含：

```text
SS_PASSWORD
SUBSCRIBE_TOKEN
```

权限应该保持：

```bash
chmod 600 /opt/my-vpn/server.env
```

---

## 35.2 不要公开 clients 目录

尤其不要让 Nginx 直接暴露：

```text
/opt/my-vpn/clients/
```

其中包含：

```text
ss.json
sing-box.json
clash.yaml
```

这些文件包含完整认证信息。

Nginx 只应该提供：

```text
subscribe.txt
```

---

## 35.3 订阅 Token 等同于访问凭证

例如：

```text
http://SERVER_IP/8f31c9d1a2b3c4d5/subscribe.txt
```

拥有这个 URL 的人可以获取节点配置。

因此：

```text
不要公开发布订阅 URL
不要提交到 GitHub
不要发到公共群组
```

---

# 36. Git 管理建议

如果将项目放入 Git：

推荐：

```text
Git
├── install.sh
├── apply-config.sh
├── generate-config.sh
├── nginx-setup.sh
├── uninstall.sh
├── server.env.example
└── README.md
```

不要提交：

```text
server.env
clients/
```

推荐 `.gitignore`：

```gitignore
server.env
clients/
*.png
```

然后：

```bash
cp server.env.example server.env
```

每台服务器单独配置：

```text
server.env
```

这样以后可以把整个项目作为模板保存。

---

# 37. 推荐的最终 Git 项目结构

```text
my-vpn/
├── .gitignore
├── README.md
├── install.sh
├── apply-config.sh
├── generate-config.sh
├── nginx-setup.sh
├── uninstall.sh
└── server.env.example
```

服务器运行后：

```text
/opt/my-vpn/
├── server.env
├── install.sh
├── apply-config.sh
├── generate-config.sh
├── nginx-setup.sh
├── uninstall.sh
└── clients/
```

---

# 38. 后续扩展

当前版本：

```text
Shadowsocks
      │
      ├── Shadowsocks Client
      ├── Clash
      └── sing-box
```

未来可以继续扩展：

```text
Shadowsocks
VLESS
VMess
Trojan
Hysteria 2
TUIC
```

同时客户端配置生成器可以扩展：

```text
Clash
sing-box
Shadowsocks
Surge
Loon
Quantumult X
```

而不需要重新设计：

```text
install.sh
```

---

# 39. 推荐的最终操作规范

### 第一次部署

```bash
cd /opt/my-vpn
./install.sh
```

### 修改服务端配置

```bash
vim /opt/my-vpn/server.env
./apply-config.sh
./generate-config.sh
```

### 修改 Nginx / 订阅

```bash
./nginx-setup.sh
```

### 查看服务

```bash
systemctl status sing-box
systemctl status nginx
```

### 查看日志

```bash
journalctl -u sing-box -f
```

```bash
journalctl -u nginx -f
```

### 检查配置

```bash
sing-box check -c /etc/sing-box/config.json
```

```bash
nginx -t
```

### 查看端口

```bash
ss -lntp
```

---

# 40. 最终架构总结

本项目最终采用：

```text
                  ┌──────────────────┐
                  │    server.env    │
                  │   唯一配置入口    │
                  └────────┬─────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
     apply-config.sh              generate-config.sh
             │                           │
             ▼                           ├── Clash
    sing-box server                      ├── SS
             │                           ├── sing-box
             │                           └── Subscription
             │
             ▼
       Shadowsocks
             │
             ▼
        Internet


                    Subscription
                         │
                         ▼
                       Nginx
                         │
                         ▼
              /随机TOKEN/subscribe.txt
```

核心原则：

```text
安装与配置分离
服务端与客户端配置分离
VPN 与订阅服务分离
敏感配置不进入 Git
云厂商安全组与 UFW 分开管理
```

最终目标是：

```bash
./install.sh
```

完成首次部署；

以后只维护：

```text
server.env
```

并根据实际修改执行：

```bash
./apply-config.sh
./generate-config.sh
./nginx-setup.sh
```

即可完成整个 VPN 节点的配置维护。
