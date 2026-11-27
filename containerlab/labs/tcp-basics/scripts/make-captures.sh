#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. Writes ../captures/*.pcapng.
# Run it from the lab folder:  bash scripts/make-captures.sh
cd "$(dirname "$0")/.." || exit 1
L=tcp-basics; N=clab-$L; mkdir -p captures
cap() {  # cap <file> <seconds> : record host-a's cable in the background, then give it 2 s to start
  containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 2
}
# Run 1: a normal connection (host-b answers, sends one line, closes)
docker exec -d $N-host-b sh -c 'echo "hello from host-b" | nc -l -p 9000'; sleep 1
cap tcp-run1-normal 6s;   docker exec $N-host-a nc -w 3 172.16.100.20 9000; wait
# Run 2: refused (nothing is listening on port 9000)
cap tcp-run2-refused 6s;  docker exec $N-host-a nc -w 3 172.16.100.20 9000; wait
# Run 3: silent drop (r1 throws host-b's packets away without a reply); the SYN is retried
docker exec $N-r1 ip route add blackhole 172.16.100.20/32
cap tcp-run3-silent-drop 12s; docker exec $N-host-a nc -w 9 172.16.100.20 9000; wait
docker exec $N-r1 ip route del blackhole 172.16.100.20/32
ls -l captures
