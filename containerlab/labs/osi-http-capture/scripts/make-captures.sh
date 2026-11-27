#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. Writes ../captures/*.pcapng.
# Run it from the lab folder:  bash scripts/make-captures.sh
cd "$(dirname "$0")/.." || exit 1
L=osi-http-capture; N=clab-$L; mkdir -p captures
cap() {  # cap <file> : record the PC's cable for 6 s in the background, then give it 2 s to start
  containerlab capture --name $L --target pc:eth1 --duration 6s -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 2
}
cap osi-http-ok;      docker exec $N-pc curl -s -o /dev/null http://www.osi-lab.example/; wait
docker exec $N-srv nginx -s stop; sleep 1
cap osi-http-refused; docker exec $N-pc curl -s -o /dev/null http://www.osi-lab.example/; wait
docker exec $N-srv nginx; sleep 1
docker exec $N-srv pkill dnsmasq; sleep 1
cap osi-dns-down;     docker exec $N-pc curl -s -o /dev/null http://www.osi-lab.example/; wait
docker exec $N-srv dnsmasq --conf-file=/etc/neo/dnsmasq.conf
ls -l captures
