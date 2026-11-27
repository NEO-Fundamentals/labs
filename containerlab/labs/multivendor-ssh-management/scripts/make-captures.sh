#!/bin/bash
# Re-record this lab's sample captures from the admin-host cable. The lab must be deployed and scripts/setup-keys.sh run once.
# Run from the lab folder:  bash scripts/make-captures.sh   (about one minute)
# It uses its own known_hosts file on admin-host, so your own known_hosts is not changed. device gets its first host key back at the end.
cd "$(dirname "$0")/.." || exit 1
L=multivendor-ssh-management; N=clab-$L; IP=192.168.50.1; mkdir -p captures
KH=/root/.ssh/known_hosts_captures
S="ssh -o BatchMode=yes -o ConnectTimeout=5 -o UserKnownHostsFile=$KH"
docker exec $N-admin-host test -f /root/.ssh/id_netops || { echo "No keys yet. Is the lab deployed (containerlab inspect --all)? Run: bash scripts/setup-keys.sh"; exit 1; }
docker exec $N-admin-host rm -f $KH
cap() {  # cap <name> <seconds>: record in the background, then give it 4 s to start
  containerlab capture --name $L --target admin-host:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 4
}
run() { echo "== $1"; docker exec $N-admin-host sh -c "$2" 2>&1 | tail -2; }
cap sshmgmt-1-unknown-host 6s;  run "unknown host key" "$S -i /root/.ssh/id_netops netops@$IP hostname"; wait
docker exec $N-admin-host sh -c "ssh-keyscan -t ed25519 $IP 2>/dev/null > $KH"
cap sshmgmt-2-login-ok 6s;      run "known host, right key" "$S -i /root/.ssh/id_netops netops@$IP hostname"; wait
cap sshmgmt-3-old-key 6s;       run "old key" "$S -i /root/.ssh/id_old netops@$IP hostname"; wait
bash scripts/device-sshd.sh rebuild >/dev/null
cap sshmgmt-4-host-key-changed 6s; run "rebuilt device" "$S -i /root/.ssh/id_netops netops@$IP hostname"; wait
bash scripts/device-sshd.sh restore >/dev/null; bash scripts/device-sshd.sh stop
cap sshmgmt-5-refused 6s;       run "sshd stopped" "$S -i /root/.ssh/id_netops netops@$IP hostname"; wait
bash scripts/device-sshd.sh start; docker exec $N-admin-host rm -f $KH
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
ls -l captures
