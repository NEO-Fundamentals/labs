#!/bin/bash
# Re-record this lab's sample captures from host-a's cable. The lab must be deployed. Run from the lab folder:
#   bash scripts/make-captures.sh        (no password needed; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
L=tcp-troubleshooting; N=clab-$L; A=$N-host-a; IP=172.16.100.20; mkdir -p captures
restart_noread() {  # the zero-window test leaves a stuck connection; restart that server so later captures stay clean
  docker exec $N-host-b pkill -f 'tcp-server.py noread'; sleep 1
  docker exec -d $N-host-b python3 /neo/scripts/tcp-server.py noread 8082; sleep 2
}
cap() {  # cap <name> <seconds>: record in the background, then give it 2 s to start
  containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 2
}
cap tcp-fault-drop 14s;   bash scripts/faults.sh drop on;  docker exec $A nc -w 10 $IP 8080;  bash scripts/faults.sh drop off; wait
cap tcp-fault-reject 6s;  docker exec $A nc -w 3 $IP 8081; wait
cap tcp-fault-loss 14s;   bash scripts/faults.sh loss on;  docker exec $A sh -c "nc -w 10 $IP 8080 | wc -c"; bash scripts/faults.sh loss off; wait
cap tcp-fault-zerowin 14s; docker exec $A sh -c "head -c 3000000 /dev/zero | nc -w 8 $IP 8082"; wait
restart_noread
cap tcp-fault-mtu 16s;    bash scripts/faults.sh mtu on;   docker exec $A sh -c "head -c 100000 /dev/zero | nc -w 10 $IP 8085"; bash scripts/faults.sh mtu off; wait
cap tcp-fault-midrst 8s;  docker exec $A sh -c "nc -w 5 $IP 8083 | wc -c"; wait
# trim each packet to 200 bytes (the payload is filler) so the files stay small
for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
ls -l captures
