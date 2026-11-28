#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about eight minutes,
# because the silent-failure test has to wait for RIP's 180-second timeout)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=rip-four-routers; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need rip-1-steady 'rip' 2
need rip-2-silent-failure 'rip' 4
need rip-3-link-down-poison 'rip' 2
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
cap() {  # cap <file> <node:interfaces> <seconds>: record in the background into a .tmp file, then wait until the recording has actually started
  f=captures/$1.pcapng
  containerlab capture --name $L --target "$2" --duration "$3" -w "$f.tmp" >>"$LOG" 2>&1 & cpid=$!
  wait_started
}
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
via() { docker exec $N-r1 vtysh -c "show ip route 10.40.0.0/24" 2>/dev/null | grep -oE '172\.16\.1[23]\.2, via' | head -1 | cut -d, -f1; }
wait_via() {  # wait_via <next hop> <max seconds>: poll r1's route to 10.40.0.0/24 every second
  local t0=$SECONDS
  until [ "$(via)" = "$1" ]; do [ $((SECONDS - t0)) -lt "$2" ] || return 1; sleep 1; done
  echo "      r1 uses $1 after $((SECONDS - t0)) s"
}
# Wait until r1 has the 3-hop route through r3 (RIP needs up to a minute after Deploy). The loop ends after 120 seconds.
wait_via 172.16.13.2 120 >/dev/null || { echo "r1 has no route to 10.40.0.0/24 via r3 after 120 seconds. Is the lab deployed?"; exit 1; }
# 1: steady state on the r1 - r2 link: regular updates to 224.0.0.9, split horizon.
cap rip-1-steady r1:eth2 70s; done_cap
# 2: silent failure: the bridge in the r1 - r3 cable stops forwarding, both ports stay up. r1 keeps the dead route until
#    the 180-second timeout, then takes r2's 4-hop offer. Recorded on both r1 links.
cap rip-2-silent-failure r1:eth2,eth3 260s
docker exec $N-mid ip link set br0 down
wait_via 172.16.12.2 250 || { echo "      r1 did not move to r2 within 250 s"; badf=1; }
done_cap
docker exec $N-mid ip link set br0 up
wait_via 172.16.13.2 90 >/dev/null || echo "      note: r1 is not back on r3 after 90 s"
# 3: cable unplugged: both ports of the r1 - r3 cable go down (the bridge's two ports), so r1 and r3 notice at once.
#    r1 sends a triggered update with metric 16 (the poison) and moves to r2 at r2's next regular update.
cap rip-3-link-down-poison r1:eth2 40s
docker exec $N-mid sh -c "ip link set eth1 down; ip link set eth2 down"
wait_via 172.16.12.2 35 || { echo "      r1 did not move to r2 within 35 s"; badf=1; }
done_cap
docker exec $N-mid sh -c "ip link set eth1 up; ip link set eth2 up"
wait_via 172.16.13.2 90 >/dev/null || echo "      note: r1 is not back on r3 after 90 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
