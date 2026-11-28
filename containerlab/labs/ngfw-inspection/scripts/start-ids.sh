#!/bin/sh
# Start Suricata as an inline IPS between eth1 and eth2, then the policy
# watcher and the log adapter. Wait until the command socket is up.
set -e
mkdir -p /etc/suricata/rules /var/log/suricata /var/run /etc/neo /run
cp /neo/configs/suricata.yaml /etc/suricata/suricata.yaml
if [ -f /neo/configs/inspect-start.rules ]; then
  cp /neo/configs/inspect-start.rules /etc/neo/inspect.rules
fi
python3 /neo/scripts/load-policy.py
# hostname lookup is not required here; wait for the socket instead
nohup suricata -c /etc/suricata/suricata.yaml --af-packet >/var/log/suricata/start.log 2>&1 &
i=0
while [ "$i" -lt 40 ]; do
  if [ -S /var/run/suricata-command.socket ]; then
    break
  fi
  i=$((i + 1))
  sleep 0.25
done
nohup python3 /neo/scripts/load-policy.py --watch >/var/log/policy-watch.log 2>&1 &
nohup python3 /neo/scripts/inspect-log.py >/var/log/inspect-log.err 2>&1 &
# give the adapter a moment to create inspect.log
i=0
while [ "$i" -lt 20 ]; do
  if [ -f /var/log/inspect.log ]; then
    exit 0
  fi
  i=$((i + 1))
  sleep 0.25
done
exit 0
