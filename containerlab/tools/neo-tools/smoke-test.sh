#!/bin/bash
# Usage: smoke-test.sh <image>   Checks every tool the labs rely on is present and that nftables and dnsmasq really run.
IMG=${1:-ghcr.io/neo-fundamentals/neo-tools:1.0.0}
fail=0
for t in ip ping tcpdump nft conntrack iperf3 nc dig dnsmasq dhclient sshd ssh haproxy keepalived snmpd snmpget python3 curl ethtool traceroute swanctl; do
  if docker run --rm --entrypoint sh "$IMG" -c "command -v $t >/dev/null || ls /usr/sbin/$t /usr/lib/ipsec/$t >/dev/null 2>&1"; then echo "ok   $t"; else echo "MISSING $t"; fail=1; fi
done
docker run --rm --entrypoint sh "$IMG" -c 'ls /etc/ssh/ssh_host_* >/dev/null 2>&1' && { echo "FAIL the image contains ssh host keys"; fail=1; } || echo "ok   no ssh host keys baked into the image"
C=neo-tools-smoke
docker rm -f $C $C-2 >/dev/null 2>&1
docker run -d --name $C --cap-add NET_ADMIN "$IMG" >/dev/null
sleep 2
docker exec $C sh -c 'nft add table inet t && nft add chain inet t c "{ type filter hook input priority 0; policy accept; }" && nft add rule inet t c tcp dport 9 drop && nft list ruleset | grep -q "dport 9"' && echo "ok   nft rule loads" || { echo "FAIL nft rule"; fail=1; }
docker exec $C sh -c 'dnsmasq --no-daemon --test -C /dev/null' >/dev/null 2>&1 && echo "ok   dnsmasq config test" || { echo "FAIL dnsmasq"; fail=1; }
docker exec $C sh -c 'ls /etc/ssh/ssh_host_ed25519_key >/dev/null && /usr/sbin/sshd -t' && echo "ok   sshd host keys + config" || { echo "FAIL sshd"; fail=1; }
docker exec $C sh -c 'haproxy -v | head -1' && echo "ok   haproxy runs" || { echo "FAIL haproxy"; fail=1; }
docker run -d --name $C-2 --cap-add NET_ADMIN "$IMG" >/dev/null; sleep 2
K1=$(docker exec $C sh -c 'cat /etc/ssh/ssh_host_ed25519_key.pub'); K2=$(docker exec $C-2 sh -c 'cat /etc/ssh/ssh_host_ed25519_key.pub')
[ -n "$K1" ] && [ "$K1" != "$K2" ] && echo "ok   two containers get different ssh host keys" || { echo "FAIL ssh host keys are not unique per container"; fail=1; }
docker rm -f $C $C-2 >/dev/null
docker images --format 'size: {{.Size}}  {{.Repository}}:{{.Tag}}' "$IMG"
[ $fail = 0 ] && echo "SMOKE TEST PASSED" || { echo "SMOKE TEST FAILED"; exit 1; }
