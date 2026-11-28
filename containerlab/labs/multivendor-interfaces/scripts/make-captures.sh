#!/bin/bash
# Re-record this lab's sample capture from l's eth1 cable. The lab must be deployed. Run from the lab folder:
#   sudo bash scripts/make-captures.sh        (asks for your password)
cd "$(dirname "$0")/.." || exit 1
# It overwrites a sample in captures/ only when the new recording succeeds; a failed one prints FAIL and the old sample stays.
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
fails=0; LOG=/tmp/neo-$(basename "$PWD")-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need interfaces-ping-ok 'icmp' 2
need interfaces-ping-typo 'arp' 1
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
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
L=multivendor-interfaces; N=clab-$L; mkdir -p captures
cap() { containerlab capture --name $L --target l:eth1 --duration "$2" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & cpid=$!; f="captures/$1.pcapng"; wait_started; }
# FRR applies its startup file a few seconds after deploy: wait until L has its address
SECONDS=0   # the wait below ends after 90 seconds at most (it checks the clock, not a number of tries)
until docker exec $N-l ip -br addr show eth1 2>/dev/null | grep -q "10\.0\.2\.1/30"; do
  [ $SECONDS -lt 90 ] || { echo "L has no address on eth1 after 90 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
  sleep 2
done
# Works: ping across the /30
cap interfaces-ping-ok 6s;       docker exec $N-l ping -c 3 -W 1 10.0.2.2; done_cap
# Typo: R moves to 10.0.2.6/30, so L cannot reach 10.0.2.2 (ARP requests go unanswered)
docker exec -i $N-r vtysh < changes/r-typo.txt >/dev/null
docker exec $N-l ip neigh flush all   # forget R's old hardware address so the ARP requests show
cap interfaces-ping-typo 10s;    docker exec $N-l ping -c 3 -W 1 10.0.2.2; done_cap
docker exec -i $N-r vtysh < changes/r-fix.txt >/dev/null
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
