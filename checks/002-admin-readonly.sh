#!/usr/bin/env bash
# 用户在 Ubuntu 管理员会话中执行；仅查询，不修改配置或运行状态。
# 输出如有真实公网地址、凭据或需脱敏域名，替换后再回传。
set -eu

sudo -v

printf '\n=== UFW 当前规则 ===\n'
sudo ufw status verbose
sudo ufw show added

printf '\n=== Docker 实际容器 ===\n'
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

printf '\n=== Docker 运行时存储与代理匹配情况 ===\n'
sudo docker info --format 'Root={{.DockerRootDir}} Driver={{.Driver}} DriverStatus={{json .DriverStatus}}'
sudo docker info --format 'HTTPProxyMatchesExpected={{eq .HTTPProxy "http://192.168.1.120:5780"}} HTTPSProxyMatchesExpected={{eq .HTTPSProxy "http://192.168.1.120:5780"}} NoProxyMatchesExpected={{eq .NoProxy "localhost,127.0.0.1,::1,192.168.1.0/24"}}'

printf '\n=== 应用实际参数（不输出环境变量或完整 inspect） ===\n'
for container in tududi caddy ddns-go; do
    sudo docker inspect "$container" --format 'Name={{.Name}} Image={{.Config.Image}} State={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}} Restart={{.HostConfig.RestartPolicy.Name}} Network={{.HostConfig.NetworkMode}} Ports={{json .HostConfig.PortBindings}} Mounts={{range .Mounts}}[{{.Type}} {{.Source}} -> {{.Destination}} rw={{.RW}}]{{end}}'
done

printf '\n=== DDNS 配置权限（不读取内容） ===\n'
sudo stat -c '%A %U:%G %s bytes %n' \
    /srv/persistent/secrets/ddns-go \
    /srv/persistent/secrets/ddns-go/.ddns_go_config.yaml

printf '\n=== Tududi 数据库及备份文件元数据（不打开数据库） ===\n'
sudo find /srv/persistent/data/tududi/db -maxdepth 1 -type f \
    -printf '%m %u:%g %s bytes %TY-%Tm-%TdT%TH:%TM:%TS %f\n'

printf '\n=== Netplan 持久配置摘要（隐藏公网地址） ===\n'
sudo python3 - <<'PY'
import ipaddress
import json
from pathlib import Path
import yaml

config = yaml.safe_load(Path('/etc/netplan/00-installer-config.yaml').read_text())
interface = config.get('network', {}).get('ethernets', {}).get('enp34s0')
if interface is None:
    print('enp34s0 not found in expected file; report without changing configuration')
else:
    addresses = []
    for value in interface.get('addresses', []):
        address = ipaddress.ip_interface(value)
        addresses.append(str(address) if address.ip.is_private or address.ip.is_loopback else '<PUBLIC_IP>')
    print(json.dumps({
        'interface': 'enp34s0',
        'dhcp4': interface.get('dhcp4'),
        'dhcp6': interface.get('dhcp6'),
        'accept-ra': interface.get('accept-ra'),
        'addresses': addresses,
        'expected_ipv4_present': '192.168.1.110/24' in interface.get('addresses', []),
        'expected_gateway_present': interface.get('gateway4') == '192.168.1.1' or any(
            route.get('to') in ('default', '0.0.0.0/0') and route.get('via') == '192.168.1.1'
            for route in interface.get('routes', [])
        ),
    }, ensure_ascii=False))
PY
