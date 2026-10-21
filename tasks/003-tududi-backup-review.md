# 003：Tududi 备份范围与调度核查

状态：存储与卷内容元数据已核实；备份调度待确认，任务继续进行。发起及本次证据接收日期：2026-10-21。当前执行主体为本地监督者及用户，尚未发布 Web 配置修改任务。

## 目标与已知前提

查清 Tududi 的数据、备份存储位置和调度来源，为后续备份与恢复方案提供事实。DDNS 仍在单独调试，不纳入本任务。

任务 002 的证据确认：

- 运行容器为 `chrisvel/tududi:1.9.5`，状态 healthy，重启策略 unless-stopped。
- `/app/db` 和 `/app/uploads` 为可写 bind，位于约 1TB 系统盘上的 `/srv/persistent/data/tududi/`。
- `/app/backups` 为 Docker volume，数据位于约 500GB 的 Docker 数据盘；用户后续元数据结果确认该卷当前为空。
- 数据库目录中有两份备份类文件，以及当前数据库和 WAL / SHM；尚未验证两份文件的一致性、完整性或恢复能力。
- 本地可读的系统 timer 和 `/etc/cron.d` 未见明显 Tududi 备份项；个人 crontab、容器内调度及应用设置仍未知。

## 本次操作边界

只查询镜像和 Compose 的卷声明、实际挂载元数据、备份卷顶层文件名与大小、个人 crontab 的汇总。数据库、上传文件和备份内容均不打开；不创建备份、不执行恢复、不改权限、不重启或重建容器。

不要因为卷位于 Docker data-root 就将其认定为可丢弃，也不要为检查而执行 prune、删除 volume 或 `compose down -v`。

## 用户管理员检查

用户已返回 [003-tududi-backup-readonly.sh](../checks/003-tududi-backup-readonly.sh) 的结果，无需重跑完整检查。实际镜像声明三个卷目标，Compose 仅管理 db / uploads 两个 bind、无顶层命名卷；backups 卷为 local driver、无 Compose 标签，顶层条目数 0。三项挂载的实际文件系统已确认，与此前推断相符。

判断：符合镜像默认生成匿名卷的情形；这只是对元数据和 Docker 行为的推断，不是最初创建请求的原始记录。该卷检查时为空，两份数据库目录备份另存于系统盘。没有证据证明 uploads 已备份，也未验证恢复。

原脚本只输出了 crontab 退出码、未保留错误原因，导致查询失败时也显示 active_entry_count=0。现已修正脚本：只在查询成功或识别出明确的 no-crontab 信息时记录任务数，其他失败以 null 表示未知。该修正不改变已经收到的历史证据。

## 最小补充检查

只需在 Ubuntu 管理员会话补充以下命令，不再枚举卷或读取数据库；stdout 被丢弃，不展示 crontab 中的命令或凭据，只保留 stderr 原因和查询是否成功。

```bash
for account in root eureka; do
    printf '\n=== %s crontab ===\n' "$account"
    if sudo env LC_ALL=C crontab -u "$account" -l >/dev/null; then
        printf 'query_success; contents not displayed\n'
    else
        printf 'query_nonzero; see diagnostic above\n'
    fi
done
```

即使确认两个个人 crontab 不存在，也不能排除应用或容器内调度。后续需基于应用备份设置或实现补齐这一点；不通过触发备份接口来试探。

核对结果与剩余重点：

1. 已确认实际镜像声明 `/app/backups`、Compose 未显式管理该卷；元数据符合默认匿名卷行为，不以名称作为唯一依据。
2. 已确认 `/app/backups` 位于 Docker 数据盘且检查时为空；不在本轮创建或删除文件。
3. 已确认数据库与 uploads 的实际文件系统为系统盘；完整恢复不能只关注 SQLite 主文件。
4. 待确认 root / 管理员个人 crontab 的查询失败原因。即使两者均不存在，仍可能有间接脚本、容器内调度或其他调度器，不能据此断定没有自动备份。

当前剩余缺口是调度来源、uploads 是否覆盖、离机副本与恢复能力。下一项实施任务的准备方向为：确定可接受的数据丢失窗口、备份目标及保留策略，设计 SQLite 一致性备份和 uploads / 必要配置覆盖，再安排隔离恢复验证。目标位置和恢复方式未定前不发布具体部署命令。

## 验收标准与后续

- 形成可追踪的数据 / 备份位置表，明确已证实和仍未知的调度来源。
- 将卷是否为空、是否被 Compose 管理、同机不同盘和离机副本区分记录。
- 明确仍需覆盖数据库、uploads、必要配置及恢复演练的范围，准备下一项独立实施任务；本任务不以“恢复成功”结项。
- 保存必要脱敏证据、更新状态文档并审查 Git Diff；不公开业务文件名中可能存在的个人信息。

后续如设计 SQLite 热备份，应参考 [SQLite 在线备份机制](https://www.sqlite.org/backup.html) 和 [WAL 持久状态说明](https://www.sqlite.org/wal.html)，不能把单独复制运行中的主库文件当作一致性备份已验收。
