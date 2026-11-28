#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a
# new recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about a minute)
# It puts each fault in place with scripts/fault.sh and undoes each one, so the lab is left as after a deploy.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=troubleshooting-capstone; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ts-1-wrong-vlan 'arp or icmp or vlan or tcp' 1
need ts-2-no-return 'icmp or arp or tcp' 1
need ts-3-fw-drop 'icmp or tcp or arp' 1
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
cap() {
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & pids+=($!)
  files+=("captures/$1.pcapng")
}
started() { wait_started; }   # wait until each recording has actually started (pcapng header written)
done_cap() {
  local i f
  for i in "${!files[@]}"; do f=${files[$i]}
    if wait "${pids[$i]}" && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
    else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
      echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  done
  files=(); pids=(); badf=
}
restore() {
  docker exec $N-sw ip link set eth3 master vlan10 >>"$LOG" 2>&1
  docker exec $N-r2 ip route replace 10.26.10.0/24 via 10.26.23.2 >>"$LOG" 2>&1
  docker exec -i $N-fw nft -f - < configs/fw-rules.nft >>"$LOG" 2>&1
}
ok_web() { docker exec $N-host-a curl -s -m 3 http://10.26.2.20/ | grep -q 'hello from h2'; }
# Start as after a deploy; wait until host-a reaches the web server (up to 30 seconds).
restore; sleep 2
for i in $(seq 30); do ok_web && break; sleep 1; done
ok_web || { echo "host-a cannot reach h2. Is the lab deployed?"; exit 1; }
# 1: wrong VLAN (exercise 3), recorded on sw eth1 and eth5 (r1's VLAN 10 and VLAN 20 links): host-b's
#    "Who has 10.26.10.1?" arrives on the VLAN 20 link; r1's "Who has 10.26.10.12?" goes out in VLAN 10; no answers.
bash scripts/fault.sh 1 >>"$LOG"
cap ts-1-wrong-vlan sw:eth1,eth5 9s; started
docker exec $N-host-b ip neigh flush dev eth1 >>"$LOG" 2>&1
docker exec $N-host-b ping -c 2 -W 1 10.26.10.1 >/dev/null && { echo "      host-b reached its gateway in the wrong VLAN"; badf=1; }
docker exec $N-r1 ip neigh flush to 10.26.10.12 >>"$LOG" 2>&1
docker exec $N-r1 ping -c 2 -W 1 10.26.10.12 >/dev/null && { echo "      r1 reached host-b in the wrong VLAN"; badf=1; }
done_cap; restore; sleep 2
ok_web || { echo "lab did not recover after fault 1"; exit 1; }
# 2: missing return route to VLAN 10 (exercise 4), recorded on h2 eth1: host-a's pings arrive and the replies leave;
#    r2 then sends ICMP net unreachable for 10.26.10.11 (only one may appear: the kernel rate-limits them).
bash scripts/fault.sh 2 >>"$LOG"
cap ts-2-no-return h2:eth1 8s; started
docker exec $N-host-a ping -c 2 -W 1 10.26.2.20 >/dev/null && { echo "      host-a reached h2 with no return route"; badf=1; }
done_cap; restore; sleep 2
ok_web || { echo "lab did not recover after fault 2"; exit 1; }
# 3: firewall change drops web (exercise 5), recorded on fw eth1 and eth2: SYNs arrive on eth1 and nothing leaves eth2.
bash scripts/fault.sh 3 >>"$LOG"
cap ts-3-fw-drop fw:eth1,eth2 8s; started
docker exec $N-host-a ping -c 1 -W 1 10.26.2.20 >/dev/null || { echo "      ping failed after the firewall change"; badf=1; }
docker exec $N-host-a curl -s -m 3 -o /dev/null -w '%{http_code}' http://10.26.2.20/ | grep -q '^000$' || { echo "      curl was not blocked"; badf=1; }
done_cap; restore; sleep 2
ok_web || echo "      note: host-a does not reach h2 after the restore"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
