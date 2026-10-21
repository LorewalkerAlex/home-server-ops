# 服务器事实表

文档更新：2026-10-22。以下是已记录的快照，不代表持续监测。

来源：A＝本地只读核验（2026-10-21）；B＝用户返回的管理员输出（2026-10-21—22，精确执行时间未提供）；C＝用户确认的设计（2026-10-22）；H＝Web 历史交接，未独立复核。

| 类别 | 项目 | 事实或约定 | 来源 / 状态 |
|---|---|---|---|
| 基础 | 系统 | Ubuntu 26.04.1 LTS；Linux 7.0.0-38-generic，x86_64 | A，已核实 |
| 基础 | 硬件 | Ryzen 5 3600，6 核 12 线程；约 16GB RAM，4Gi swap | A，已核实 |
| 基础 | 网络 | `enp34s0`：`192.168.1.110/24`，网关 `192.168.1.1`；Netplan 为 `/etc/netplan/00-installer-config.yaml`，dhcp4=false、dhcp6=true | A+B，已核实 |
| 基础 | IPv6 | 网卡有 global scope 地址，公网可达性和 IPv6 DDNS 未验收；真实地址不公开 | A，部分待验证 |
| 基础 | 时间与更新 | 主机时区 UTC，NTP 自报已同步；APT 自动更新及 unattended-upgrades 已启用，近期升级结果未核实 | A，部分待验证 |
| 存储 | 1TB SSD | `/dev/nvme0n1`，系统分区 `nvme0n1p2` 挂载 `/`；保留重建服务所需的配置、业务数据和私密资料 | A+C |
| 存储 | 500GB SSD | `/dev/nvme1n1p1`，ext4，挂载 `/srv/docker-data`；用于镜像等可重建 Docker 运行时内容 | A+C |
| 存储 | 数据盘保护 | UUID `880cc4e1-3cf0-44cb-aa71-97d0bc3b15a5`；fstab 含 nofail 和 10 秒设备超时；Docker/containerd 启动依赖挂载并校验 UUID，未做缺盘故障测试 | A，配置已核实 |
| 存储 | 3TB HDD | `/dev/sda` 有两个分区，未显示挂载点；不得因未挂载就认定为空盘，禁止未经授权的磁盘写入 | A+C |
| 目录 | 部署配置 | `/srv/apps/<服务>/` 保存 Compose 等声明，已见 tududi、caddy、ddns-go；沿用现有目录 | A+B，已核实 |
| 目录 | 持久数据 | `/srv/persistent/data/<服务>/` 保存业务数据；当前位于 1TB 系统盘 | A+B，已核实 |
| 目录 | 私密配置 | `/srv/persistent/secrets/<服务>/` 保存凭据和敏感配置；当前位于系统盘，内容不进入公开仓库 | A+B+C |
| Docker | 版本与运行时 | Docker 客户端 29.9.1、Compose v5.6.0；Docker/containerd 服务运行；实际 Driver=overlayfs、snapshotter=io.containerd.snapshotter.v1 | A+B，已核实 |
| Docker | 数据路径 | Docker root：`/srv/docker-data/engine/docker`；containerd root：`/srv/docker-data/engine/containerd`，state：`/run/containerd` | A+B，已核实 |
| Docker | 宿主机配置 | `/etc/docker/daemon.json`、`/etc/containerd/config.toml`；两服务的 systemd drop-in 位于各自 `/etc/systemd/system/<服务>.service.d/`，校验脚本为 `/usr/local/sbin/verify-docker-data-disk` | A，已核实 |
| Docker | 代理 | HTTP/HTTPS 代理实际为 `http://192.168.1.120:5780`；NO_PROXY 为 localhost、127.0.0.1、::1、192.168.1.0/24；依赖 Windows PC，TCP 可达，未重新拉取镜像验证 | A+B，已核实 |
| Docker | 容器策略 | Tududi、Caddy、ddns-go 均 running，restart=unless-stopped；仅 Tududi 配置并通过健康检查 | B，已核实 |
| Tududi | 服务与入口 | 任务管理；`chrisvel/tududi:1.9.5`，healthy；`127.0.0.1:13002→3002`，经 Caddy 的 LAN 根路径访问，HTTP 200 | A+B，已核实 |
| Tududi | 配置与数据 | `/srv/apps/tududi/compose.yaml`；db、uploads 分别从 `/srv/persistent/data/tududi/` bind 到 `/app/db`、`/app/uploads`，均可写 | B，已核实 |
| Tududi | 备份相关现状 | 数据库目录有两份备份类文件及 WAL/SHM；`/app/backups` 为 500GB 盘上的 Docker 卷，检查时为空。未验收一致性、uploads 覆盖或恢复能力 | B，部分待验证 |
| Caddy | 服务与入口 | `caddy:2.11.4-alpine`，host 网络，HTTP 80；根路径反代 `127.0.0.1:13002` | A+B，已核实 |
| Caddy | 配置与数据 | `/srv/apps/caddy/compose.yaml`、`Caddyfile`；Caddyfile 只读挂载；`/data`、`/config` 对应 `/srv/persistent/data/caddy/` 下同名目录 | A+B，已核实 |
| Caddy | DDNS 管理路由 | `/ddns-go/*` 去前缀后反代 `127.0.0.1:19876`；已有 Location 前缀重写，限制来源 `192.168.1.0/24`，其他来源返回 403 | A，已核实配置及回环拒绝 |
| ddns-go | 容器 | `ghcr.io/jeessy2/ddns-go:v6.17.7`；`127.0.0.1:19876→9876`；Compose 在 `/srv/apps/ddns-go/compose.yaml` | A+B，已核实 |
| ddns-go | 配置 | `/srv/persistent/secrets/ddns-go/.ddns_go_config.yaml`，目录 700、文件 600；目录可写挂载 `/root`。Compose 声明 300 秒间隔、Asia/Shanghai 时区，未逐项复核运行时参数 | A+B，部分为配置声明 |
| ddns-go | 页面与功能 | 上次 `/ddns-go/` 已跳到 `/ddns-go/login`，登录页和 8 个静态资源返回 200；登录后功能、DNS 自动更新仍调试中 | A+C，功能未验收 |
| DDNS | DNS 服务商 | 历史方案为阿里云 DNS、IPv4 更新已有记录；当前记录名、类型、TTL、有效 RAM 权限及更新结果未独立核验 | H，待验证 |
| 网络 | 防火墙 | UFW active，默认入站/转发 deny、出站 allow；用户规则只允许 LAN 网段到 TCP 22、80。未做完整 Docker 转发链及公网端到端验收 | B，核验范围有限 |
| 网络 | 监听与公网 | 已见 22、80 非回环监听，13002、19876、2019 为回环监听；上次未见 TCP 443。当前路由器映射及公网 HTTP/HTTPS 未验收 | A，部分待验证 |
| 运维 | 调度与备份阶段 | root、eureka 没有个人 crontab；应用内调度未知。用户计划服务基本稳定后再建设 persistent 备份，不将未建设备份视为当前缺陷 | B+C |
| 约定 | 数据边界 | 按内容判断是否需保留，不能把所有 Docker volume 都当成可丢弃数据；Git 只保存 Web 所需知识和脱敏摘要 | C，用户约定 |
