#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
# It stops web-2's web server for a while (exercise 3) and starts it again, so the lab is left as after a deploy.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=load-balancer-haproxy; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need lb-1-full-proxy 'http or tcp' 4
need lb-2-member-down 'http or tcp' 2
need lb-3-persistence 'http or tcp' 4
# Wait until the pcapng file has its header (the recording has actually started).
_wait_one() {
  local file="$1" proc="${2-}" i=0 sz
  while true; do
    if [ -s "$file" ]; then
      sz=$(wc -c < "$file")
      [ "${sz:-0}" -ge 32 ] && return 0
    fi
    if [ -n "$proc" ] && ! kill -0 "$proc" 2>/dev/null; then
      return 1
    fi
    i=$((i+1))
    [ "$i" -ge 80 ] && return 1
    sleep 0.5
  done
}
# For the single-capture style (uses $f and $cpid) or the multi style (files[] / pids[]).
wait_started() {
  local i wf proc
  if [ "${#files[@]}" -gt 0 ]; then
    for i in "${!files[@]}"; do
      wf=${files[$i]}
      proc=${pids[$i]}
      if ! _wait_one "$wf.tmp" "$proc"; then
        echo "      capture did not start: $wf"
        badf=1
      fi
    done
  else
    if ! _wait_one "$f.tmp" "$cpid"; then
      echo "      capture did not start: $f"
      badf=1
    fi
  fi
}
_count_frames() {
  local file="$1" filt="${2-}" n
  if command -v tshark >/dev/null; then
    if [ -n "$filt" ]; then
      n=$(tshark -r "$file" -Y "$filt" -T fields -e frame.number 2>/dev/null | wc -l)
    else
      n=$(tshark -r "$file" -T fields -e frame.number 2>/dev/null | wc -l)
    fi
    echo "${n:-0}"
  elif command -v capinfos >/dev/null; then
    capinfos -M -c "$file" 2>/dev/null | awk -F: '/Number of packets/{gsub(/ /,"",$2); print $2+0; exit}'
  else
    echo "?"
  fi
}
# Return 0 if the pcap has at least $min frames matching $filt (or any non-empty file if tshark is missing).
_verify_pcap() {
  local file="$1" filt="$2" min="$3" n
  n=$(_count_frames "$file" "$filt")
  if [ "$n" = "?" ]; then
    echo "      note: tshark is not installed; only checked that $file is not empty"
    [ -s "$file" ]
    return
  fi
  if [ "${n:-0}" -ge "$min" ]; then
    return 0
  fi
  if [ -n "$filt" ]; then
    echo "      $file: expected at least $min frame(s) matching ($filt), found $n"
  else
    echo "      $file: expected at least $min frame(s), found $n"
  fi
  return 1
}
_need_of() {  # _need_of <path> -> prints filter<TAB>min
  local base; base=$(basename "$1" .pcapng)
  if [ -n "${NEED_MIN[$base]+x}" ]; then
    printf "%s\t%s\n" "${NEED_FILT[$base]}" "${NEED_MIN[$base]}"
  else
    # Safety net: at least one frame that is not an IPv6 Router/Neighbor Solicitation or Advertisement.
    printf "%s\t%s\n" "not (icmpv6.type == 133 or icmpv6.type == 134 or icmpv6.type == 135 or icmpv6.type == 136)" 1
  fi
}
_file_ok() {  # _file_ok <final path>: tmp must exist, pass the protocol/frame check
  local f="$1" filt min
  [ -s "$f.tmp" ] || return 1
  IFS=$'\t' read -r filt min < <(_need_of "$f")
  [ -n "$min" ] || min=1
  _verify_pcap "$f.tmp" "$filt" "$min"
}
files=(); pids=()
cap() {  # cap <file> <node:interface[,interface]> <seconds>: record in the background into a .tmp file
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & pids+=($!)
  files+=("captures/$1.pcapng")
}
started() { wait_started; }   # wait until each recording has actually started (pcapng header written)
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty and the checks passed
  local i f
  for i in "${!files[@]}"; do f=${files[$i]}
    if wait "${pids[$i]}" && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
    else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
      echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  done
  files=(); pids=(); badf=
}
member() {  # member <web-N> <UP|DOWN|MAINT>: wait up to 15 s until lb's pool_web reports that status
  for i in $(seq 15); do st "$1" | grep -qx "$2" && return 0; sleep 1; done
  echo "      $1 did not become $2"; badf=1
}
st() { docker exec $N-client curl -s -m 2 'http://10.22.1.1:8404/stats;csv' | awk -F, -v s="$1" '$1=="pool_web" && $2==s {print $18}'; }
web2_up() { docker exec $N-web-2 pgrep -f web_echo.py >/dev/null || docker exec -d $N-web-2 sh -c 'python3 -u /neo/scripts/web_echo.py web-2 >>/var/log/web.log 2>&1'; }
# Start as after a deploy (all members up and enabled, weight 1), then the lab must be up: the client gets a page
# through the virtual server (waits up to 30 seconds).
web2_up
for s in web-1 web-2 web-3; do docker exec $N-lb python3 /neo/scripts/hapctl.py set server pool_web/$s state ready >>"$LOG" 2>&1
  docker exec $N-lb python3 /neo/scripts/hapctl.py set server pool_web/$s weight 1 >>"$LOG" 2>&1; done
for i in $(seq 30); do docker exec $N-client curl -s -m 2 -o /dev/null http://10.22.1.100/ && break; sleep 1; done
docker exec $N-client curl -s -m 2 -o /dev/null http://10.22.1.100/ || { echo "the client cannot reach the virtual server. Is the lab deployed?"; exit 1; }
member web-1 UP; member web-2 UP; member web-3 UP; badf=
# 1: the full proxy, recorded on both lb ports at once: six requests from the client to the VIP 10.22.1.100 (client
#    side) and lb's own connections from 10.22.2.1 to web-1, web-2 and web-3 (server side), with X-Forwarded-For.
#    The server side also carries lb's health checks (GET /health) every 2 seconds.
cap lb-1-full-proxy lb:eth1,eth2 8s; started
out=$(docker exec $N-client sh -c 'for i in 1 2 3 4 5 6; do curl -s -m 3 http://10.22.1.100/; done')
for s in web-1 web-2 web-3; do echo "$out" | grep -q "served by $s; connection from 10.22.2.1" || { echo "      no answer from $s through the VIP"; badf=1; }; done
done_cap
# 2: a member goes down, recorded on lb eth2 (server side): web-2's server is stopped; health checks to 10.22.2.12 are
#    refused (RST); a request sent to web-2 before the monitor marks it down waits for lb's retries and gets 503.
cap lb-2-member-down lb:eth2 14s; started
docker exec $N-web-2 pkill -f web_echo.py
docker exec $N-client sh -c 'for i in 1 2 3 4 5 6; do curl -s -m 10 -o /dev/null -w "%{http_code}\n" http://10.22.1.100/; done' >"/tmp/neo-$L-codes.out"
grep -q 503 "/tmp/neo-$L-codes.out" || echo "      (no request reached web-2 before it was marked down; the capture still shows the refused checks)"
member web-2 DOWN
done_cap; web2_up; member web-2 UP
# 3: cookie persistence on the second virtual server (port 8080), recorded on lb eth1 (client side): the first answer
#    sets the cookie NEO_LB, and the next three requests carry it and stay on the same member.
cap lb-3-persistence lb:eth1 8s; started
docker exec $N-client sh -c ': > /tmp/neo-jar; curl -s -m 3 -c /tmp/neo-jar -o /dev/null http://10.22.1.100:8080/; for i in 1 2 3; do curl -s -m 3 -b /tmp/neo-jar http://10.22.1.100:8080/; done' >"/tmp/neo-$L-persist.out"
[ "$(cut -d';' -f1 "/tmp/neo-$L-persist.out" | sort -u | wc -l)" = 1 ] || { echo "      the requests did not stay on one member"; badf=1; }
done_cap
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
