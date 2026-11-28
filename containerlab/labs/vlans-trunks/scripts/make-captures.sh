#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=vlans-trunks; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need vlan-1-trunk '(arp or icmp) and vlan' 2
need vlan-2-native-mismatch 'arp or icmp' 2
need vlan-3-vlan30-not-on-trunk 'arp or icmp' 2
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
cap() {  # cap <file> <node:interface> <seconds>: record in the background into a .tmp file, then wait until the recording has actually started
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
ping_ok()   { docker exec $N-host-$1 ping -c 3 -W 1 "$2" >>"$LOG" 2>&1; }   # ping_ok <host number> <address>
expect_ok() { ping_ok "$1" "$2" || { echo "      host-$1 -> $2 should work and did not"; badf=1; }; }
expect_no() { ping_ok "$1" "$2" && { echo "      host-$1 -> $2 should fail and worked"; badf=1; }; true; }
flush()     { for h in 1 2 3 4; do docker exec $N-host-$h ip neigh flush all; done; }   # forget learned MACs on the hosts
is_srl() { docker exec $N-$1 sh -c 'command -v sr_cli' >/dev/null 2>&1; }
sr() {  # apply a change on sw2: SR Linux CLI in the full lab, or the matching .sh in the lighter lab
  if is_srl sw2; then
    docker exec -i $N-sw2 sr_cli <"changes/$1" >>"$LOG" 2>&1 || badf=1
  else
    bash "changes/${1%.cli}.sh" >>"$LOG" 2>&1 || badf=1
  fi
}
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
# In the lighter lab, do not overwrite the sample captures (they were recorded on the full lab).
wait_for 60 docker exec $N-sw2 true || { echo "sw2 is not up. Is the lab deployed?"; exit 1; }
if ! is_srl sw2; then
  echo "ok    lighter lab: sample captures were recorded on the full lab and were not overwritten"
  ls -l captures
  exit 0
fi
# Both switches must forward before we start (SR Linux takes a minute or two). The loop ends after 180 seconds.
wait_for 180 ping_ok 1 10.7.0.12 || { echo "host-1 cannot reach host-3 after 180 seconds. Is the lab deployed?"; exit 1; }
wait_for 60 ping_ok 2 10.7.0.32 || { echo "host-2 cannot reach host-4. Is the lab deployed?"; exit 1; }
# 1: the trunk: host-1 pings host-3 (VLAN 10, the native VLAN, crosses untagged) and host-2 pings host-4
#    (VLAN 30, crosses with an 802.1Q tag, VLAN ID 30). Recorded on sw1's trunk port.
flush; cap vlan-1-trunk sw1:e1-3 14s
expect_ok 1 10.7.0.12; expect_ok 2 10.7.0.32
done_cap
# 2: native VLAN mismatch: sw2 puts untagged trunk frames into VLAN 30. host-1 (VLAN 10 on sw1) now reaches
#    host-4 (VLAN 30 on sw2), and no longer host-3. Then the change is undone.
sr sw2-native-30.cli; flush; cap vlan-2-native-mismatch sw1:e1-3 14s
expect_ok 1 10.7.0.32; expect_no 1 10.7.0.12
done_cap
sr sw2-native-undo.cli; flush
wait_for 20 ping_ok 1 10.7.0.12 || echo "      note: host-1 -> host-3 not back after 20 s"
# 3: VLAN 30 not on the trunk at sw2: sw1 still sends tagged VLAN 30 frames, sw2 drops them. VLAN 10 still works.
sr sw2-trunk-drop-30.cli; flush; cap vlan-3-vlan30-not-on-trunk sw1:e1-3 14s
expect_no 2 10.7.0.32; expect_ok 1 10.7.0.12
done_cap
sr sw2-trunk-undo.cli; flush
wait_for 20 ping_ok 2 10.7.0.32 || echo "      note: host-2 -> host-4 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
