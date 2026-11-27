#!/bin/bash
# Re-record this lab's sample captures from host-a's cable. The lab must be deployed and
# scripts/setup-keys.sh run once. Run from the lab folder:  bash scripts/make-captures.sh   (about two minutes)
# It uses its own known_hosts file on host-a, so your own known_hosts is not changed. Every fault is put back.
cd "$(dirname "$0")/.." || exit 1
L=ssh-sessions; N=clab-$L; IP=172.16.100.20; mkdir -p captures
KH=/root/.ssh/known_hosts_captures
S="ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o UserKnownHostsFile=$KH"
docker exec $N-host-a rm -f $KH
# r1 (FRR) loads its addresses 10-20 s after deploy: wait until host-a can reach host-b
ok=; for i in $(seq 45); do docker exec $N-host-a ping -c 1 -W 1 $IP >/dev/null 2>&1 && { ok=1; break; }; sleep 2; done   # waits at most 90 s
[ -n "$ok" ] || { echo "host-a cannot reach host-b after 90 seconds. Is the lab deployed (containerlab inspect --all)? Did you run scripts/setup-keys.sh?"; exit 1; }
cap() {  # cap <name> <seconds>: record in the background, then give it 4 s to start
  containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 4
}
run() { echo "== $1"; docker exec $N-host-a sh -c "$2" 2>&1 | tail -2; }
cap ssh-1-ok 8s;               run "works" "$S -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh refused on
cap ssh-2-refused 6s;          run "refused" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh refused off; bash scripts/faults.sh drop on
cap ssh-3-timeout 10s;         run "timed out" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh drop off; bash scripts/faults.sh banner on
cap ssh-4-banner-timeout 10s;  run "banner timeout" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh banner off
cap ssh-5-kex-mismatch 6s;     run "kex mismatch" "$S -o KexAlgorithms=diffie-hellman-group1-sha1 -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh hostkey on
cap ssh-6-hostkey-changed 6s;  run "host key changed" "$S -o StrictHostKeyChecking=yes -i /root/.ssh/id_lab labuser@$IP hostname"; wait
bash scripts/faults.sh hostkey off
cap ssh-7-permission-denied 6s; run "permission denied" "$S -i /root/.ssh/id_other labuser@$IP hostname"; wait
docker exec $N-host-a rm -f $KH
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
ls -l captures
