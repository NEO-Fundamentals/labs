#!/bin/sh
# $1 = fw1 or fw2. Load the conntrack netlink module if the kernel has it, start
# conntrackd, then keepalived (which notifies conntrackd on master/backup).
# Copy the matching config to /etc/neo so the notify script finds it.
set -e
role=$1
mkdir -p /etc/neo /var/lock /var/run /var/log
cp "/neo/configs/${role}-conntrackd.conf" /etc/neo/conntrackd.conf
# conntrackd talks to the kernel through nf_conntrack_netlink. The NEO lab VM
# has this module; some kernels (including one build-box kernel) do not.
modprobe nf_conntrack_netlink >/var/log/conntrackd-start.log 2>&1 || true
conntrackd -d -C /etc/neo/conntrackd.conf >>/var/log/conntrackd-start.log 2>&1 || true
if ! pgrep -x conntrackd >/dev/null; then
  echo "conntrackd did not stay up; see /var/log/conntrackd.log" >>/var/log/conntrackd-start.log
fi
nohup keepalived --dont-fork --log-console --log-detail -f "/neo/configs/${role}-keepalived.conf" >/var/log/keepalived.log 2>&1 &
exit 0
