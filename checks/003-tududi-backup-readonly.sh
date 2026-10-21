#!/usr/bin/env bash
# 在 Ubuntu 管理员会话中运行；仅检查配置与元数据，不备份、不恢复、不删除。
(
set -eu
sudo python3 -u - <<'PY'
import itertools
import json
import re
import subprocess
from pathlib import Path
import yaml

def docker_json(*args):
    result = subprocess.run(['docker', *args], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)

container = docker_json('inspect', 'tududi')[0]
image = docker_json('image', 'inspect', container['Image'])[0]
print('=== 运行镜像声明的卷目标 ===')
print(json.dumps({'declared_volume_targets': sorted((image.get('Config', {}).get('Volumes') or {}).keys())}))

print('=== Compose 中的卷声明（不输出 environment / env_file 内容） ===')
compose_path = Path('/srv/apps/tududi/compose.yaml')
compose = yaml.safe_load(compose_path.read_text()) or {}
for name, service in (compose.get('services') or {}).items():
    print(json.dumps({'service': name, 'volumes': service.get('volumes', [])}, ensure_ascii=False))
print(json.dumps({'top_level_volume_names': sorted((compose.get('volumes') or {}).keys())}))

print('=== 应用数据与备份挂载的元数据 ===')
for mount in container.get('Mounts', []):
    target = mount.get('Destination')
    if target not in ('/app/db', '/app/uploads', '/app/backups'):
        continue
    source = mount['Source']
    print(json.dumps({'target': target, 'type': mount.get('Type'), 'source': source, 'rw': mount.get('RW')}, ensure_ascii=False))
    subprocess.run(['findmnt', '-T', source, '-o', 'TARGET,SOURCE,FSTYPE'], check=True)
    if target == '/app/backups':
        if mount.get('Type') == 'volume' and mount.get('Name'):
            volume = docker_json('volume', 'inspect', mount['Name'])[0]
            print(json.dumps({'volume_driver': volume.get('Driver'), 'created_at': volume.get('CreatedAt'), 'compose_label_keys': sorted(key for key in (volume.get('Labels') or {}) if key.startswith('com.docker.compose.'))}))
        entries = list(itertools.islice(Path(source).iterdir(), 31))
        print(json.dumps({'entry_count_capped_at_31': len(entries), 'truncated_after_30': len(entries) > 30}))
        for entry in entries[:30]:
            stat = entry.lstat()
            print(json.dumps({'entry': entry.name, 'mode': oct(stat.st_mode & 0o777), 'bytes': stat.st_size, 'mtime_epoch': stat.st_mtime, 'is_symlink': entry.is_symlink()}, ensure_ascii=False))

print('=== 用户 crontab 摘要（不输出命令或凭据） ===')
for user in ('root', 'eureka'):
    result = subprocess.run(['crontab', '-u', user, '-l'], capture_output=True, text=True)
    entries = [line.strip() for line in result.stdout.splitlines() if line.strip() and not line.lstrip().startswith('#') and not re.match(r'^\s*[A-Za-z_]\w*\s*=', line)]
    print(json.dumps({'user': user, 'query_exit_code': result.returncode, 'active_entry_count': len(entries), 'backup_keyword_matches': sum(bool(re.search(r'backup|restic|borg|tududi', line, re.I)) for line in entries)}))
PY
)
