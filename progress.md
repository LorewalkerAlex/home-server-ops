# 项目进度

更新：2026-10-22。仅记录已确定事项；本地 Codex 根据证据验收后勾选。服务器参数及核验来源见 [facts.yaml](facts.yaml)。

## 已完成

- [x] Ubuntu Server 安装及固定内网 IPv4 配置。
- [x] Docker、Compose 与 containerd 基础搭建。
- [x] 采用 1TB 配置与持久数据、500GB Docker 运行时的目录分工，并配置挂载与 UUID 启动检查。
- [x] Tududi 部署，健康检查通过，db 和 uploads 持久挂载；访问入口的后续变更见未完成项及 facts.yaml。
- [x] Caddy 局域网反代及 DDNS 管理路径的前缀处理、LAN 来源限制。
- [x] DDNS 部署与自动更新：2026-10-22 管理入口由本地核验，定时检测有用户提供日志，自动更新成功由用户明确确认。

## 未完成

- [ ] Tududi 公网 HTTPS 接入：目标 `https://tududi.<DOMAIN>:18443`；路由器 TCP `18443 → 192.168.1.110:443`，Caddy 域名反代 `127.0.0.1:13002`。尚未完成可信证书、外网登录与功能验收。

  已完成部分：用户已添加 Tududi CNAME、调整 Caddy 域名路由并验证重载，新增 UFW IPv4 80/443 规则及路由器映射。本地只读复核上游 200、IP 根路径 404、域名 HTTP 跳转及 LAN 管理入口限制；用户在公司外网测得 18080/18443 TCP 可达、80/443 不通。证据来源与范围见 facts.yaml，不将运营商封锁作为确定根因。

  当前上下文：Caddy 仍为 `caddy:2.11.4-alpine`、host 网络；配置 `/srv/apps/caddy/Caddyfile`，Compose `/srv/apps/caddy/compose.yaml`。`/data`、`/config` 分别挂载 `/srv/persistent/data/caddy/data` 和 `/srv/persistent/data/caddy/config`。域名站点代理 Tududi，`http://192.168.1.110` 中 `/ddns-go/` 仅允许 LAN，根路径返回 404。HTTP 18080 当前跳到标准 HTTPS 443，不能用它判断 18443 的应用访问结果。

  下一步建议（由 Web 指导、用户授权执行）：采用 DNS-01 签发与续期。先在现有 Caddy 项目构建并验证带 AliDNS 的镜像，不替换运行容器、不带凭据构建。固定 Caddy `v2.11.4`，插件 `github.com/caddy-dns/alidns@c8c945ded9ace193e86f063842ba59981b35146b`（依赖 libdns/alidns v1.0.7）。构建结果须确认 Caddy 版本及 `dns.providers.alidns` 模块；此处仅完成源码和官方方案审查，尚未实际构建。

  RAM 最小动作候选：根据固定版本 CertMagic 的 Append/Delete 调用及 AliDNS provider 代码，`alidns:DescribeDomains` 使用 `Resource: "*"`；`alidns:DescribeDomainRecords`、`alidns:AddDomainRecord`、`alidns:DeleteDomainRecord` 限制到 `acs:alidns::<ACCOUNT_ID>:domain/<DOMAIN>`。本路径不预先授予 UpdateDomainRecord、DeleteSubDomainRecords 或完整 DNS 管理权限。这仅针对本任务 DNS-01，不是插件所有功能的通用策略；候选需在执行中验证，不凭一次 AccessDenied 直接扩权。

  权限边界：这是动作和域名层面的限制，不能限制为“仅 ACME TXT”；同一 zone 的其他记录仍处于相应增删权限范围。用户授权前应明确此范围；若要求记录级隔离，先另行设计受限验证 zone 或 challenge 委派。为 Caddy 建独立 RAM 身份及凭据，不复用或扩权 DDNS 账号。RAM、AccessKey、自定义镜像及 DNS-01 均尚未执行。

  镜像验证后再配置凭据与签发：凭据建议放 `/srv/persistent/secrets/caddy/alidns.env`，按运行需要设置权限（目录 0700、文件 0600），由 Compose 注入；Caddyfile 使用 `{env.ALIYUN_ACCESS_KEY_ID}` 与 `{env.ALIYUN_ACCESS_KEY_SECRET}`，仅在 Tududi 站点配置 DNS-01，不额外启用其他 DNS 自动发布。不得把密钥写入镜像、构建参数或公开配置。保留既有数据挂载及 host 网络，只调整 TLS 验证和镜像，不重写已验证的反代、不改变 Tududi 端口或数据库。

  维护要求：在服务器现有 Caddy 项目保存 Dockerfile 和构建版本记录；升级 Caddy 或插件时重新构建并验证。检查挂载配置确实为所编辑版本，避免单文件 bind 与编辑器更换 inode 导致容器读旧文件。签发正式证书并验证自动续期配置；失败重试出现 staging 地址本身不代表显式使用测试 CA，也不算正式证书验收通过。

  验收与返回：真实外网直接访问带 18443 的目标 URL，校验证书信任链、域名及有效期；验证 Tududi 登录、刷新、保存任务与跳转保持正确端口。提供脱敏证书及应用结果、镜像版本和模块结果、最终 RAM 策略及 TXT 清理结果；不给出凭据。确认 DDNS 管理入口仍仅 LAN 可用、原有服务正常。验收后清理不再使用的 18080；18443 承载所选方案，继续保留。重新评估标准 80/443 映射与公网规则；若保留 HTTP 跳转，应明确其到 18443 的行为。

  回退：保留当前官方镜像和切换前的 Compose、Caddyfile。若 DNS-01 方案失败，回退本次镜像与 TLS 配置，保留应用数据及现有路由；需要回到本轮公网接入之前时，原配置备份为 `/srv/apps/caddy/Caddyfile.bak-20261022-015403`，同时按实际记录撤销本任务新增的 UFW/路由器规则。不要清空 Caddy /data、删除 DDNS A/CNAME 或使用 down -v。

  参考：[AliDNS 插件](https://github.com/caddy-dns/alidns/tree/c8c945ded9ace193e86f063842ba59981b35146b)、[固定版 provider](https://github.com/libdns/alidns/tree/v1.0.7)、[阿里云授权](https://www.alibabacloud.com/help/en/dns/api-alidns-2015-01-09-ram)、[Caddy HTTPS](https://caddyserver.com/docs/automatic-https)、[官方镜像构建](https://hub.docker.com/_/caddy)。

派发具体任务时，在本文件补充目标、范围、相关参数或配置片段、约束、验收标准及需返回的脱敏证据；按需补充回滚方案。
