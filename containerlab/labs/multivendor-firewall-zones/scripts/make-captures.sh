#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
# It loads the deploy policy (configs/srx-zones.nft) first and again at the end, so the lab is left as after a deploy.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=multivendor-firewall-zones; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need srx-1-zone-pairs 'tcp or icmp or http' 2
need srx-2-host-inbound 'tcp or icmp' 1
need srx-3-new-zone-pair 'tcp or icmp or http' 2
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
cap() {  # cap <file> <node:interface> <seconds>: record in the background into a .tmp file
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
policy() { docker exec $N-fw nft -f /neo/configs/srx-zones.nft >>"$LOG" 2>&1; }
web() {  # web <node> <url> <expected code>
  local c; c=$(docker exec $N-$1 curl -s -m 3 -o /dev/null -w '%{http_code}' "$2")
  [ "$c" = "$3" ] || { echo "      $1 $2: expected http $3, got $c"; badf=1; }
}
pings() {  # pings <node> <address> <expected replies of 2>
  local r; r=$(docker exec $N-$1 ping -c 2 -i 0.5 -W 1 "$2" | awk '/packets transmitted/{print $4}')
  [ "$r" = "$3" ] || { echo "      $1 ping $2: expected $3 replies, got ${r:-?}"; badf=1; }
}
# Start as after a deploy, then the lab must be up: host-a reaches host-b's web page (waits up to 30 seconds).
policy
for i in $(seq 30); do docker exec $N-host-a curl -s -m 2 -o /dev/null http://10.40.2.20/ && break; sleep 1; done
docker exec $N-host-a curl -s -m 2 -o /dev/null http://10.40.2.20/ || { echo "host-a cannot reach host-b. Is the lab deployed?"; exit 1; }
# 1: zone pairs, recorded on fw eth2 (untrust): trust -> untrust allowed (host-a to host-b); untrust -> trust has no
#    policy (host-b's three SYNs to host-a, no answer); untrust -> dmz allowed by web-in (host-b to host-c).
cap srx-1-zone-pairs fw:eth2 12s; started
web host-a http://10.40.2.20/ 200; web host-b http://10.40.1.10:8080/ 000; web host-b http://10.40.3.30/ 200
done_cap
# 2: host-inbound traffic, recorded on fw eth2: two pings to fw's untrust address get no reply; ping is allowed in the
#    untrust zone; two more pings are answered.
cap srx-2-host-inbound fw:eth2 10s; started
pings host-b 10.40.2.1 0
docker exec $N-fw nft add element inet srx ping-zones '{ "eth2" }' >>"$LOG" 2>&1
pings host-b 10.40.2.1 2
done_cap; policy
# 3: a missing zone pair, recorded on fw eth3 (dmz): host-c's SYNs to host-b (dmz -> untrust, no policy), then the
#    policy dmz-updates is added and the same request works.
cap srx-3-new-zone-pair fw:eth3 12s; started
web host-c http://10.40.2.20/ 000
docker exec $N-fw sh -c 'nft add chain inet srx from-dmz-to-untrust && nft add rule inet srx from-dmz-to-untrust tcp dport 80 counter accept comment "\"policy dmz-updates: any any junos-http, permit\"" && nft add element inet srx zone_pair "{ \"eth3\" . \"eth2\" : jump from-dmz-to-untrust }"' >>"$LOG" 2>&1
web host-c http://10.40.2.20/ 200
done_cap; policy
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
