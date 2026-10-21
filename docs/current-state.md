# 服务器当前状态

本页面向 Web ChatGPT。核验主体为本地 Codex，来源分为专用普通账号的直接 SSH 读取、本机 Windows 只读检查、用户返回的管理员实际命令输出，以及待核验的 Web 历史摘要。

核验日期：2026-10-21（Asia/Shanghai）；首轮服务器报告时间为 23:25:55。服务器自报 NTP 已启用、已同步，宿主机时区为 UTC。以下是该轮检查的快照，不代表持续监测。

用户于同日返回了任务 002 的管理员检查结果，命令执行的精确时间未提供；下文注明来源，不能把文件修改时间当作命令执行时间。用户明确要求 DDNS 保持调试中，本轮后续工作聚焦其他运维内容。

## 已核实的基础状态

| 项目 | Verified：证据来源逐项说明 |
|---|---|
| 系统 | Ubuntu 26.04.1 LTS；Linux 7.0.0-38-generic，x86_64 |
| CPU / 内存 | AMD Ryzen 5 3600，6 核 12 线程；约 16GB RAM（`free` 显示 15Gi），4Gi swap |
| 内网 | 直接读取运行状态为 `192.168.1.110/24`、默认网关 `192.168.1.1`；用户管理员摘要确认 Netplan 中 dhcp4=false、固定地址和网关均符合预期，dhcp6=true，accept-ra 未显式配置 |
| IPv6 | 网卡有 global scope IPv6 地址，但尚未测试公网可达性或 DDNS；真实地址不公开 |
| 宿主机服务 | 直接读取 Docker、containerd、SSH 为 active/running；UFW unit 为 active/exited，实际用户规则另由管理员输出补齐 |
| Docker | 客户端 Docker 29.9.1、Compose v5.6.0；用户管理员输出确认运行时 data-root、snapshotter、代理及三项容器参数，详见下文 |
| TCP 监听 | 22、80 有非回环监听；13002、19876、2019 为回环监听；本轮未发现 TCP 443 监听 |
| 系统更新 | APT 配置启用了每日索引更新和 unattended-upgrade，相关 timer 存在，允许来源见下文；未核实近期升级记录或回滚机制 |

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
- `/etc/docker/daemon.json` 声明 data-root 为 `/srv/docker-data/engine/docker`、日志驱动为 `local`。用户返回的 `docker info` 进一步确认实际 data-root 相同，Driver 为 `overlayfs`，DriverStatus 为 `io.containerd.snapshotter.v1`；文件中没有显式 features 开关不代表该运行时功能未启用。实际日志驱动未在本次管理员输出中查询。
- `/etc/containerd/config.toml` 为 v4，root 为 `/srv/docker-data/engine/containerd`，state 为 `/run/containerd`。
- Docker 和 containerd 的 drop-in 均有 `RequiresMountsFor`、`AssertPathIsMountPoint`，并在启动前调用 `/usr/local/sbin/verify-docker-data-disk`。
- 已读取该检查脚本源码：校验挂载点和 UUID，不匹配时退出失败。未执行该脚本、重启服务、移除磁盘或进行故障注入。

这证明保护配置存在，不能替代缺盘故障测试或当前全部应用的冷启动验收。

## 应用与 DDNS

本地监督者仍无 Docker API 权限；以下实际容器参数依据用户返回的 `docker ps -a` 和选择性 `docker inspect`，不是监督者直接调用 Docker API 获得。三项容器均为 running、重启策略均为 unless-stopped。

| 应用 | 配置与用户管理员运行时证据 | 直接 HTTP / 监听证据 |
|---|---|---|
| Caddy | 已读 Compose 与管理员实际参数一致：`caddy:2.11.4-alpine`、host 网络；Caddyfile 只读挂载，`/data`、`/config` 可写绑定到 `/srv/persistent/data/caddy/`；未配置健康检查 | LAN 根路径返回 200；80 和回环 2019 有监听 |
| ddns-go | 已读 Compose 与用户返回的实际镜像、端口和配置目录挂载一致；`ghcr.io/jeessy2/ddns-go:v6.17.7`，`127.0.0.1:19876:9876`，`/root` 为可写 bind；未配置健康检查。Compose 另外声明只读根文件系统、300 秒间隔和 Asia/Shanghai 时区，这几项未在运行时 inspect 中单独核对 | 保留上一轮匿名页面及资源的 HTTP 结果；功能仍调试中，不继续排查或宣称验收通过 |
| Tududi | 用户管理员输出：`chrisvel/tududi:1.9.5`、healthy、`127.0.0.1:13002:3002`，网络 `tududi_default`；`/app/db`、`/app/uploads` 分别可写绑定到 `/srv/persistent/data/tududi/db` 和 `uploads`，`/app/backups` 另为 Docker volume | `127.0.0.1:13002/` 和经 Caddy 的 LAN 根路径均返回 200；健康检查 healthy 不等于恢复能力已验收 |

未配置健康检查与健康检查失败是不同状态，不能因 Caddy / ddns-go 显示 not-configured 就判断应用故障。

### DDNS 管理入口已经发生变化

交接说明中的“`/ddns-go/` 跳出前缀进入 `/login`”已经不符合本次观察，不能继续按未修复故障指导修改。

- 当前 Caddyfile 的 `handle_path /ddns-go/*` 中已有 `header_down Location ^/(.*)$ /ddns-go/$1`。
- `/ddns-go` 配有 308 到 `/ddns-go/` 的规范化规则；本轮未单独请求无尾斜线入口。
- 配置中有 `remote_ip 192.168.1.0/24` 限制，其他来源返回 403；从服务器回环来源访问该管理路径实际返回 403，服务器通过自身 LAN 地址访问返回预期响应。尚未从外网独立测试。
- 登录页引用的 8 个本地 CSS / JS 资源均在 `/ddns-go/static/` 下，逐个 GET 返回 200。

本次只验证匿名页面和资源；未登录管理页面，未验证登录提交、会话、登录后 API 或设置保存。更未触发 DNS 更新，不能将页面可访问写成 DDNS 自动更新成功。

### DDNS 与公网仍待核验

用户明确说明 DDNS 仍在调试，暂不作为当前监督工作的推进重点。以下未知项保留，待用户交接调试结果后另行验收。

历史交接描述：阿里云域名及 DNS、ddns-go IPv4、RAM 仅查询与更新已有记录，以及 OpenAPI Explorer 的人工测试成功。这些尚未独立复核。

当前仍未知：实际记录名、类型、TTL、DNS 值与家庭公网 IPv4 是否一致、自动更新成功时间、有效 RAM 策略、路由器当前转发及公网 HTTPS 可用性。无需为核验 DDNS 而先开放公网端口。

## 防火墙与代理

- 用户管理员输出确认 UFW 为 active，默认入站 deny / 出站 allow / 转发 deny；当前显示的用户规则仅允许 `192.168.1.0/24` 到 TCP 22、80，`ufw show added` 与之相符。未检查完整 Docker 转发链或独立做公网探测，不能外推为所有网络路径均已验收。
- Docker systemd 代理文件声明 HTTP_PROXY / HTTPS_PROXY 为 `http://192.168.1.120:5780`，NO_PROXY 为 `localhost,127.0.0.1,::1,192.168.1.0/24`，未含代理用户名密码；用户返回的 `docker info` 三项匹配结果均为 true，确认守护进程实际生效值符合预期。
- 本机 Windows 地址为 `192.168.1.120/24`，5780 有 TCP 监听；从服务器连接该端口成功。仅验证 TCP 连通，不代表代理转发或镜像拉取成功，本轮不拉取镜像。
- Windows 未发现显示名称精确等于 `TEMP-HTTP-Test-18080` 的规则，不能据此排除其他名称的同类规则。

## 数据保护与更新

用户管理员返回的元数据确认：

- Tududi 数据库目录中有 `production.sqlite3`（660），以及对应 WAL / SHM（660）；文件属主均为 eureka。
- 有 `db-backup-20261021134257.sqlite3` 和 `db-premigrate-20260920000002-make-user-email-nullable.sqlite3` 两份备份类文件（644）。先前直接检查发现其父目录受 750 权限限制，不能仅凭文件 644 就认定全体用户可访问。
- ddns-go 配置目录为 700，配置文件为 600，属主为 eureka；只验证元数据，没有读取凭据或有效 DNS 设置。

用户进一步返回了任务 003 的镜像、Compose、卷和目录检查结果（2026-10-21 接收，精确执行时间未知）：

| 路径 | Verified：当前存储与内容证据 |
|---|---|
| `/app/db` | Compose 显式 bind 到系统盘上的 `/srv/persistent/data/tududi/db`，与实际挂载一致；该目录中有前述两份备份类文件 |
| `/app/uploads` | Compose 显式 bind 到系统盘上的 `/srv/persistent/data/tududi/uploads`，与实际挂载一致；没有检查其业务内容或证实上传文件已备份 |
| `/app/backups` | 实际为 local driver volume，位于 `/srv/docker-data` 数据盘；顶层目录枚举为 0 项、未截断，检查时为空 |

镜像声明 `/app/backups`、`/app/db`、`/app/uploads` 为卷目标；当前 Compose 只为 db 和 uploads 提供 bind，未声明 backups 或顶层命名卷。backups 卷无 Compose 标签，创建时间为 `2026-10-21T13:38:28Z`。Inferred：该挂载符合镜像声明触发 Docker 自动创建匿名卷的行为；仅凭该挂载不能证明已配置备份策略。参见 [Dockerfile VOLUME](https://docs.docker.com/reference/dockerfile/#volume) 和 [匿名卷说明](https://docs.docker.com/engine/storage/volumes/#named-and-anonymous-volumes)。未读取最初的容器创建请求，不将创建过程冒充直接观察。

空卷不等于数据库目录中的两份备份不存在，也不能证明应用从未执行过任何备份。当前不能把这个空挂载作为已有备份方案，更不能据此决定删除、迁移或重建卷。

备份存在性已经有证据，但备份一致性、恢复演练、保留策略、离机副本和应用更新回滚仍未验收。数据库目录中存在 WAL；不应将复制单个正在使用的主数据库文件作为已完成的一致性热备份。后续方案需遵循 [SQLite WAL 说明](https://www.sqlite.org/wal.html) 和 [在线备份机制](https://www.sqlite.org/backup.html)，本次未打开数据库或执行备份。

本地只读检查未找到 `/srv/backups`、`/srv/persistent/backups`、`/etc/restic`、`/etc/borg`；`/etc/cron.d` 仅列出占位文件和 e2scrub_all。已见的系统 timer 无明显 Tududi 备份项。用户返回的 root / eureka crontab 查询均退出 1，原脚本未保留 stderr，结果中的 0 项不能当作“成功查询后没有任务”；需区分没有 crontab 与其他查询失败。容器内调度和应用备份设置同样未知，自动备份、uploads 覆盖、保留策略与离机副本尚未获证实。

unattended-upgrades 服务为 active/running，APT 配置允许发行版及 security / ESM 安全来源。是否最近升级成功、自动重启行为、应用镜像更新和回滚流程仍未核实，不将系统包自动升级等同于容器自动更新。

## 历史决策与计划

来源：用户于 2026-10-21 转交的 Web Project 摘要，未附完整历史原始输出。以下作为历史上下文保留，与上面的直接核验分开：

- 目标是长期运行个人自托管环境，逐步承接云端个人服务；以 Docker / Compose 和 Caddy 为主要部署及入口方案。
- 目录设计把应用数据、秘密配置与可丢弃运行时数据分开；这种语义划分不代表位于不同物理设备。
- 旧网段 `192.168.71.0/24`、旧 Server 地址及提议中的其他目录方案已被替代，不应据此建立平行部署。
- 当前 DDNS 方向为 IPv4；公网 HTTPS 尚未验收。
- ShellUI、Beszel、消费统计、异机备份及恢复演练属于计划或待验证。宿主机 PATH 中未找到 tailscale、restic、smartctl、beszel，不足以证明容器或其他形式的部署不存在。

## 当前交接动作

[002：历史交接核查与基线建立](../tasks/002-baseline-review.md) 的基础范围已完成，DDNS 按用户要求另行验收。当前优先推进 [003：Tududi 备份范围与调度核查](../tasks/003-tududi-backup-review.md)，先只读查清，不创建、迁移或删除备份，也不重复应用已有的 Caddy 修复。
