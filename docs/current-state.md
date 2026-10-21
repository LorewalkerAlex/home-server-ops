# 服务器当前状态

本页面向 Web ChatGPT。核验主体为本地 Codex，来源为专用普通账号的直接 SSH 读取、本机 Windows 只读检查，以及用户提供的 Web 交接说明。

核验日期：2026-10-21（Asia/Shanghai）；首轮服务器报告时间为 23:25:55。服务器自报 NTP 已启用、已同步，宿主机时区为 UTC。以下是该轮检查的快照，不代表持续监测。

## 已核实的基础状态

| 项目 | Verified：本轮直接核实 |
|---|---|
| 系统 | Ubuntu 26.04.1 LTS；Linux 7.0.0-38-generic，x86_64 |
| CPU / 内存 | AMD Ryzen 5 3600，6 核 12 线程；约 16GB RAM（`free` 显示 15Gi），4Gi swap |
| 内网 | `enp34s0` 为 `192.168.1.110/24`，默认网关 `192.168.1.1` |
| IPv6 | 网卡有 global scope IPv6 地址，但尚未测试公网可达性或 DDNS；真实地址不公开 |
| 宿主机服务 | Docker、containerd、SSH 为 active/running；UFW unit 为 active/exited，不能据此认定实际规则已验收 |
| Docker 客户端 | Docker 29.9.1、Compose v5.6.0；守护进程运行参数和容器明细待管理员验证 |
| TCP 监听 | 22、80 有非回环监听；13002、19876、2019 为回环监听；本轮未发现 TCP 443 监听 |
| 系统更新 | APT 配置启用了每日索引更新和 unattended-upgrade，相关 timer 存在；未核实近期升级记录、源范围或回滚机制 |

监听状态不等于防火墙放行，也不等于公网可达。路由器的型号、DHCP 池及端口映射仍仅有历史描述。

## 存储与目录

| 设备 / 路径 | Verified：本轮直接核实 |
|---|---|
| `/dev/nvme0n1` | 931.5G SSD；`nvme0n1p2` 为 ext4，挂载于 `/` |
| `/dev/nvme1n1` | 465.8G SSD；`nvme1n1p1` 为 ext4，挂载于 `/srv/docker-data` |
| Docker 数据盘 UUID | `880cc4e1-3cf0-44cb-aa71-97d0bc3b15a5`，与历史交接一致 |
| `/srv/persistent/data`、`/srv/persistent/secrets` | 当前均位于系统盘 `/dev/nvme0n1p2`，不是 Docker 数据盘上的独立挂载 |
| `/dev/sda` | 2.7T 磁盘，有两个分区；`lsblk` 未显示挂载点和文件系统类型，不能据此判定为空盘或无数据 |

用户历史约束要求保护约 3TB 的 `/dev/sda`，不得格式化、重新分区或执行其他破坏性操作。本轮仅查看设备和挂载元数据。

已读取的配置事实：

- `/etc/fstab` 将上述 UUID 挂载到 `/srv/docker-data`，选项为 `defaults,nofail,x-systemd.device-timeout=10s`。
- `/etc/docker/daemon.json` 声明 data-root 为 `/srv/docker-data/engine/docker`、日志驱动为 `local`；本次读取的文件没有显式 `features.containerd-snapshotter` 配置，运行时存储驱动不能靠历史描述认定。
- `/etc/containerd/config.toml` 为 v4，root 为 `/srv/docker-data/engine/containerd`，state 为 `/run/containerd`。
- Docker 和 containerd 的 drop-in 均有 `RequiresMountsFor`、`AssertPathIsMountPoint`，并在启动前调用 `/usr/local/sbin/verify-docker-data-disk`。
- 已读取该检查脚本源码：校验挂载点和 UUID，不匹配时退出失败。未执行该脚本、重启服务、移除磁盘或进行故障注入。

这证明保护配置存在，不能替代缺盘故障测试或当前全部应用的冷启动验收。

## 应用与 DDNS

以下 Compose 内容只代表磁盘上的部署声明。没有 Docker API 权限，尚不能确认容器实际使用的镜像、重启策略、挂载和端口是否与声明完全一致。

| 应用 | 已读配置 | 直接 HTTP / 监听证据 |
|---|---|---|
| Caddy | `/srv/apps/caddy/compose.yaml`：`caddy:2.11.4-alpine`、host 网络、unless-stopped；Caddyfile 只读挂载，状态目录在 `/srv/persistent/data/caddy/` | LAN 根路径返回 200；80 和回环 2019 有监听 |
| ddns-go | `/srv/apps/ddns-go/compose.yaml`：`ghcr.io/jeessy2/ddns-go:v6.17.7`、unless-stopped、`127.0.0.1:19876:9876`、只读根文件系统；秘密配置目录挂载到 `/root`；参数为配置路径、监听 `:9876`、间隔 300 秒，TZ 为 Asia/Shanghai | 后端根路径返回 307 到 `/login`；LAN `/ddns-go/` 返回 307 到 `/ddns-go/login`，该登录页返回 200 |
| Tududi | `/srv/apps/tududi` 不可进入，Compose 和数据库不可读取；镜像 1.9.5、健康状态和备份文件目前仅有历史描述 | `127.0.0.1:13002/` 和经 Caddy 的 LAN 根路径均返回 200；HTTP 响应不能证明容器健康检查状态或数据库可恢复 |

### DDNS 管理入口已经发生变化

交接说明中的“`/ddns-go/` 跳出前缀进入 `/login`”已经不符合本次观察，不能继续按未修复故障指导修改。

- 当前 Caddyfile 的 `handle_path /ddns-go/*` 中已有 `header_down Location ^/(.*)$ /ddns-go/$1`。
- `/ddns-go` 配有 308 到 `/ddns-go/` 的规范化规则；本轮未单独请求无尾斜线入口。
- 配置中有 `remote_ip 192.168.1.0/24` 限制，其他来源返回 403；从服务器回环来源访问该管理路径实际返回 403，服务器通过自身 LAN 地址访问返回预期响应。尚未从外网独立测试。
- 登录页引用的 8 个本地 CSS / JS 资源均在 `/ddns-go/static/` 下，逐个 GET 返回 200。

本次只验证匿名页面和资源；未登录管理页面，未验证登录提交、会话、登录后 API 或设置保存。更未触发 DNS 更新，不能将页面可访问写成 DDNS 自动更新成功。

### DDNS 与公网仍待核验

历史交接描述：阿里云域名及 DNS、ddns-go IPv4、RAM 仅查询与更新已有记录，以及 OpenAPI Explorer 的人工测试成功。这些尚未独立复核。

当前仍未知：实际记录名、类型、TTL、DNS 值与家庭公网 IPv4 是否一致、自动更新成功时间、有效 RAM 策略、路由器当前转发及公网 HTTPS 可用性。无需为核验 DDNS 而先开放公网端口。

## 防火墙与代理

- UFW 可读配置为 `ENABLED=yes`、IPv6 启用、默认入站 DROP / 出站 ACCEPT / 转发 DROP；实际加载的规则及 Docker 转发影响待管理员查询，尚未做端到端防火墙验收。
- Docker systemd 代理文件声明 HTTP_PROXY / HTTPS_PROXY 为 `http://192.168.1.120:5780`，NO_PROXY 为 `localhost,127.0.0.1,::1,192.168.1.0/24`，未含代理用户名密码；守护进程实际生效值待查询。
- 本机 Windows 地址为 `192.168.1.120/24`，5780 有 TCP 监听；从服务器连接该端口成功。仅验证 TCP 连通，不代表代理转发或镜像拉取成功，本轮不拉取镜像。
- Windows 未发现显示名称精确等于 `TEMP-HTTP-Test-18080` 的规则，不能据此排除其他名称的同类规则。

## 历史决策与计划

来源：用户于 2026-10-21 转交的 Web Project 摘要，未附完整历史原始输出。以下作为历史上下文保留，与上面的直接核验分开：

- 目标是长期运行个人自托管环境，逐步承接云端个人服务；以 Docker / Compose 和 Caddy 为主要部署及入口方案。
- 目录设计把应用数据、秘密配置与可丢弃运行时数据分开；这种语义划分不代表位于不同物理设备。
- 旧网段 `192.168.71.0/24`、旧 Server 地址及提议中的其他目录方案已被替代，不应据此建立平行部署。
- 当前 DDNS 方向为 IPv4；公网 HTTPS 尚未验收。
- ShellUI、Beszel、消费统计、异机备份及恢复演练属于计划或待验证。宿主机 PATH 中未找到 tailscale、restic、smartctl、beszel，不足以证明容器或其他形式的部署不存在。

## 当前交接动作

优先完成 [002：历史交接核查与基线建立](../tasks/002-baseline-review.md) 中的管理员只读检查，再决定下一项 Web 执行任务。不要重复应用已经存在的 Caddy 重定向修复。
