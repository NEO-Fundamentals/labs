#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about a minute)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=firewall-zones; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need fw-1-default-deny 'tcp' 1
need fw-2-stateful-zones 'tcp' 4
need fw-3-stateless-hole 'tcp' 4
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
cap() {  # cap <file> <node:interface> <seconds>: record in the background into a .tmp file (several may run at once)
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & pids+=($!)
  files+=("captures/$1.pcapng")
}
started() { wait_started; }   # wait until each recording has actually started (pcapng header written)
done_cap() {  # wait for the recordings; keep each only if containerlab succeeded, the file is not empty, it has the expected frames, and the checks passed
  local i f
  for i in "${!files[@]}"; do f=${files[$i]}
    if wait "${pids[$i]}" && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
    else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
      echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  done
  files=(); pids=(); badf=
}
policy() { docker exec -i $N-fw nft -f - <"changes/$1.nft" >>"$LOG" 2>&1 || badf=1; }   # policy <change file name>
web() { docker exec $N-$1 curl -s -m 3 -o /dev/null -w '%{http_code}' "$2" 2>>"$LOG"; }  # web <host> <url>: HTTP code, 000 = no answer
expect() { local got; got=$(web "$2" "$3"); [ "$got" = "$1" ] || { echo "      $2 -> $3 should give $1, gave $got"; badf=1; }; }
probe() { docker exec $N-host-b python3 /neo/scripts/sport80-probe.py 2>>"$LOG"; }
# The lab must be up with the zone policy: host-a reaches host-b's web page. Waits up to 30 seconds.
for i in $(seq 30); do [ "$(web host-a http://10.13.2.20/)" = 200 ] && break; sleep 1; done
[ "$(web host-a http://10.13.2.20/)" = 200 ] || { echo "host-a cannot reach host-b's web page. Is the lab deployed?"; exit 1; }
# 1: default deny only. host-a asks host-b for a page; fw drops the SYN and its two retries. Recorded on fw eth1 (inside):
#    three SYNs from host-a, nothing comes back.
policy fw-default-deny
cap fw-1-default-deny fw:eth1 10s; started
expect 000 host-a http://10.13.2.20/
done_cap
# 2: the stateful zone policy. Recorded on fw eth2 (outside): host-a's request to host-b goes out and its replies come
#    back (inside -> outside, then established); host-b's SYNs to host-a:8080 arrive here and go no further.
policy fw-zones
cap fw-2-stateful-zones fw:eth2 12s; started
expect 200 host-a http://10.13.2.20/
expect 000 host-b http://10.13.1.10:8080/
done_cap
# 3: the stateless mistake. Recorded on fw eth1 (inside): with "anything from port 80 back in", host-b opens a NEW
#    connection from source port 80 to host-a:8080 and gets the page. Then the zone policy is loaded again.
policy fw-stateless
cap fw-3-stateless-hole fw:eth1 10s; started
probe | grep -q "got through" || { echo "      the source-port-80 probe should get through and did not"; badf=1; }
done_cap
policy fw-zones
probe | grep -q "blocked" || echo "      note: the probe should be blocked by the zone policy and was not"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
