#!/bin/bash
# Switch one SSH fault on host-b on or off. Run from the lab folder on the VM, for example:
#   bash scripts/faults.sh refused on      (sshd stopped: nothing listens on port 22, "Connection refused")
#   bash scripts/faults.sh drop on         (host-b drops packets to port 22: "Operation timed out" with this lab's client; other clients may say "Connection timed out")
#   bash scripts/faults.sh banner on       (a silent program holds port 22: "timed out during banner exchange")
#   bash scripts/faults.sh hostkey on      (host-b gets a new host key: "REMOTE HOST IDENTIFICATION HAS CHANGED")
# Use "off" to put each one back. "bash scripts/faults.sh status" shows what is on.
B=clab-ssh-sessions-host-b
X() { docker exec $B sh -c "$1"; }
start_sshd() { X 'pkill -f "silent-listener[.]py"; [ -f /run/sshd.pid ] && kill -0 $(cat /run/sshd.pid) 2>/dev/null || /usr/sbin/sshd -f /etc/neo/sshd_config -E /var/log/sshd.log'; }
stop_sshd()  { X '[ -f /run/sshd.pid ] && kill $(cat /run/sshd.pid) 2>/dev/null; rm -f /run/sshd.pid; sleep 1'; }
case "$1 $2" in
  "refused on")  stop_sshd ;;
  "refused off") start_sshd ;;
  "drop on")     X 'tc qdisc add dev eth1 ingress 2>/dev/null; tc filter add dev eth1 parent ffff: protocol ip prio 1 u32 match ip protocol 6 0xff match ip dport 22 0xffff action drop' ;;
  "drop off")    X 'tc qdisc del dev eth1 ingress 2>/dev/null; true' ;;
  "banner on")   stop_sshd; docker exec -d $B python3 /neo/silent-listener.py 22; sleep 1 ;;
  "banner off")  start_sshd ;;
  "hostkey on")  X 'K=/etc/ssh/ssh_host_ed25519_key; [ -f $K.lesson ] || { cp -p $K $K.lesson; cp -p $K.pub $K.pub.lesson; }; rm -f /tmp/newkey /tmp/newkey.pub; ssh-keygen -q -t ed25519 -N "" -f /tmp/newkey && mv -f /tmp/newkey $K && mv -f /tmp/newkey.pub $K.pub'; stop_sshd; start_sshd ;;
  "hostkey off") X 'K=/etc/ssh/ssh_host_ed25519_key; [ -f $K.lesson ] && cp -p $K.lesson $K && cp -p $K.pub.lesson $K.pub'; stop_sshd; start_sshd ;;
  "status ")     X 'echo "port 22 listeners:"; ss -ltnp | grep ":22 " || echo "  none"; echo "drop filter:"; tc filter show dev eth1 parent ffff: 2>/dev/null | grep -q u32 && echo "  on" || echo "  off"; echo "host key:"; ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub' ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
