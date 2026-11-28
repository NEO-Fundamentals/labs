#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
# It puts the faults of exercises 4 and 5 in place with scripts/fault.sh and undoes each one, so the lab is left as after
# a deploy (r2's route back to 10.24.1.0/24 present, fw's rules as in configs/fw-rules.nft).
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=path-trace-routed; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need pt-1-path 'icmp or arp' 2
need pt-2-no-return 'icmp or arp' 1
need pt-3-fw-drop 'icmp or tcp or arp' 1
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
restore() {  # r2's route back and fw's rules as at deploy
  docker exec $N-r2 vtysh -c 'configure terminal' -c 'ip route 10.24.1.0/24 10.24.23.2' >>"$LOG" 2>&1
  docker exec -i $N-fw nft -f - < configs/fw-rules.nft >>"$LOG" 2>&1
}
web() { docker exec $N-h1 curl -s -m 3 -o /dev/null -w '%{http_code}' http://10.24.2.20/; }
# Start as after a deploy; then the lab must be up: h1 gets h2's web page (waits up to 30 seconds).
restore
for i in $(seq 30); do [ "$(web)" = 200 ] && break; sleep 1; done
[ "$(web)" = 200 ] || { echo "h1 cannot reach h2's web page. Is the lab deployed?"; exit 1; }
# 1: the whole path from h1's side, recorded on h1 eth1: a traceroute (each hop's "time exceeded" answer, then h2's
#    "port unreachable") and one web request to h2.
cap pt-1-path h1:eth1 8s; started
docker exec $N-h1 traceroute -n -w 1 -q 1 10.24.2.20 >"/tmp/neo-$L-trace.out"
[ "$(awk 'NR>1 {print $2}' "/tmp/neo-$L-trace.out" | tr '\n' ' ')" = "10.24.1.1 10.24.12.2 10.24.23.3 10.24.2.20 " ] || { echo "      the traceroute did not show the 4 hops"; badf=1; }
[ "$(web)" = 200 ] || { echo "      no web page"; badf=1; }
done_cap
# 2: no way back (exercise 4), recorded on h2 eth1: r2 has lost its route to 10.24.1.0/24. h1's pings reach h2, h2
#    answers, and r2 tells h2 "net 10.24.1.10 unreachable": the replies die at r2.
bash scripts/fault.sh 1 >>"$LOG"
cap pt-2-no-return h2:eth1 8s; started
docker exec $N-h1 ping -c 2 -W 1 10.24.2.20 >/dev/null && { echo "      the ping worked although the route is gone"; badf=1; }
done_cap; restore
# 3: a firewall change drops web traffic (exercise 5), recorded on both fw ports: one ping passes fw in both directions,
#    then h1's web request: its SYNs arrive on eth1 and never leave on eth2.
bash scripts/fault.sh 2 >>"$LOG"
cap pt-3-fw-drop fw:eth1,eth2 9s; started
docker exec $N-h1 ping -c 1 -W 1 10.24.2.20 >/dev/null || { echo "      the ping failed"; badf=1; }
[ "$(web)" = 000 ] || { echo "      the web request was not dropped"; badf=1; }
done_cap; restore
[ "$(web)" = 200 ] || echo "      note: h1 does not get h2's page after the restore"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
