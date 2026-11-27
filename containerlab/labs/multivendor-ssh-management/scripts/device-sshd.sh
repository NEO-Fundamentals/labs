#!/bin/bash
# Change the SSH server on the device. Run from the lab folder on the VM:
#   bash scripts/device-sshd.sh rebuild   (device gets a new host key, as if the device were rebuilt)
#   bash scripts/device-sshd.sh restore   (device gets its first host key back)
#   bash scripts/device-sshd.sh stop      (sshd stopped: "Connection refused")
#   bash scripts/device-sshd.sh start     (sshd started again)
#   bash scripts/device-sshd.sh fingerprint   (the device host key fingerprint, read on the device itself: the "console" check)
R=clab-multivendor-ssh-management-device
X() { docker exec $R sh -c "$1"; }
K=/etc/ssh/ssh_host_ed25519_key
start() { X "[ -f /run/sshd.pid ] && kill -0 \$(cat /run/sshd.pid) 2>/dev/null || /usr/sbin/sshd -f /etc/neo/sshd_config -E /var/log/sshd.log"; }
stop()  { X "[ -f /run/sshd.pid ] && kill \$(cat /run/sshd.pid) 2>/dev/null; rm -f /run/sshd.pid; sleep 1"; }
case "$1" in
  rebuild) X "[ -f $K.first ] || { cp -p $K $K.first; cp -p $K.pub $K.pub.first; }; rm -f /tmp/newkey /tmp/newkey.pub; ssh-keygen -q -t ed25519 -N '' -f /tmp/newkey && mv -f /tmp/newkey $K && mv -f /tmp/newkey.pub $K.pub"; stop; start; X "ssh-keygen -lf $K.pub" ;;
  restore) X "[ -f $K.first ] && cp -p $K.first $K && cp -p $K.pub.first $K.pub"; stop; start; X "ssh-keygen -lf $K.pub" ;;
  stop) stop ;;
  start) start ;;
  fingerprint) X "ssh-keygen -lf $K.pub" ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
