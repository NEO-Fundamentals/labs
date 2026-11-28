#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
# It puts the faults of exercises 2 to 4 in place with scripts/fault.sh and undoes each one, so the lab is left as after a
# deploy (HAProxy reloaded with configs/haproxy.cfg, all three web servers running normally).
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=load-balancer-troubleshooting; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need lbts-1-app-down 'http or tcp' 2
need lbts-2-broken-member 'http or tcp' 2
need lbts-3-wrong-monitor 'http or tcp' 2
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
member() {  # member <web-N> <UP|DOWN|MAINT>: wait up to 15 s until lb's pool_web reports that status (read on lb itself,
            # so the status requests stay off the recorded wires)
  for i in $(seq 15); do st "$1" | grep -qx "$2" && return 0; sleep 1; done
  echo "      $1 did not become $2"; badf=1
}
st() { docker exec $N-lb curl -s -m 2 'http://10.23.1.1:8404/stats;csv' | awk -F, -v s="$1" '$1=="pool_web" && $2==s {print $18}'; }
web_ok() {  # web_ok <web-N>: the member runs its normal web server (a --broken one is stopped first)
  docker exec $N-$1 pkill -f "web_echo.py $1 --broken" 2>/dev/null
  docker exec $N-$1 pgrep -f web_echo.py >/dev/null || docker exec -d $N-$1 sh -c "python3 -u /neo/scripts/web_echo.py $1 >>/var/log/web.log 2>&1"
}
restore() {  # all three web servers normal, HAProxy with the lesson configuration, all members up
  for s in web-1 web-2 web-3; do web_ok $s; done
  docker exec $N-lb sh /neo/scripts/reload.sh /neo/configs/haproxy.cfg >>"$LOG" 2>&1
  for s in web-1 web-2 web-3; do member $s UP; done
}
codes() { docker exec $N-client sh -c "for i in \$(seq $1); do curl -s -m 10 -o /dev/null -w '%{http_code}\n' http://10.23.1.100/; done"; }
# Start as after a deploy; then the lab must be up: the client gets a page through the virtual server (waits up to 30 s).
for i in $(seq 30); do docker exec $N-client curl -s -m 2 -o /dev/null http://10.23.1.100/ && break; sleep 1; done
docker exec $N-client curl -s -m 2 -o /dev/null http://10.23.1.100/ || { echo "the client cannot reach the virtual server. Is the lab deployed?"; exit 1; }
restore; badf=
# 1: the VIP is up, the application is down (exercise 2), recorded on both lb ports: the web servers stop, the health
#    checks to all three members are refused ([RST, ACK]), and once all are down the client's requests get an
#    immediate 503 from lb, with no connection to any member.
cap lbts-1-app-down lb:eth1,eth2 16s; started
bash scripts/fault.sh 1 >>"$LOG"
for s in web-1 web-2 web-3; do member $s DOWN; done
[ "$(codes 3 | sort -u)" = 503 ] || { echo "      the requests did not all get 503"; badf=1; }
done_cap; restore
# 2: one member's application fails while its web server runs (exercise 3), recorded on lb eth2 (server side): the
#    health checks to web-3 still get 200 (GET /health), and the requests lb sends to web-3 get 500.
cap lbts-2-broken-member lb:eth2 10s; started
bash scripts/fault.sh 2 >>"$LOG"; sleep 1
n=$(codes 6 | grep -c 500); [ "$n" = 2 ] || { echo "      expected 2 answers 500 of 6, got $n"; badf=1; }
member web-3 UP
done_cap; restore
# 3: a configuration change with the wrong monitor page (exercise 4), recorded on lb eth2: after the reload every
#    health check asks GET /healthz and every member answers 404, so all three are marked down.
cap lbts-3-wrong-monitor lb:eth2 10s; started
bash scripts/fault.sh 3 >>"$LOG"
for s in web-1 web-2 web-3; do member $s DOWN; done
done_cap; restore
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
