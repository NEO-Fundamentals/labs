#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=multivendor-access-trunk; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need mvat-1-trunk-tags 'vlan' 2
need mvat-2-vlan20-not-allowed 'vlan or arp or icmp' 1
need mvat-3-access-vs-trunk 'arp or icmp or vlan' 1
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
ping_ok() { docker exec $N-h$1 ping -c 2 -W 1 "$2" >>"$LOG" 2>&1; }   # ping_ok <host number> <address>
expect_ok() { ping_ok "$1" "$2" || { echo "      h$1 -> $2 should work and did not"; badf=1; }; }
expect_no() { ping_ok "$1" "$2" && { echo "      h$1 -> $2 should fail and worked"; badf=1; }; true; }
ch() { bash "changes/$1.sh" >>"$LOG" 2>&1 || badf=1; }
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
# SR Linux must be up and both VLANs must cross the trunk. The loop ends after 180 seconds.
wait_for 180 ping_ok 1 10.35.0.12 || { echo "h1 cannot reach h3 after 180 seconds. Is the lab deployed?"; exit 1; }
wait_for 30 ping_ok 2 10.35.0.22 || { echo "h2 cannot reach h4. Is the lab deployed?"; exit 1; }
# 1: the trunk: h1 pings h3 (VLAN 10) and h2 pings h4 (VLAN 20); every frame on the trunk carries an 802.1Q tag.
#    Recorded on sw2 eth1 (the trunk, Linux end).
cap mvat-1-trunk-tags sw2:eth1 10s; started
expect_ok 1 10.35.0.12; expect_ok 2 10.35.0.22; expect_no 1 10.35.0.22
done_cap
# 2: VLAN 20 is missing from sw2's trunk (the lesson's practice). sw1 still sends VLAN 20 tagged; sw2 drops it.
#    VLAN 10 still works. Recorded on sw2 eth1.
ch sw2-trunk-drop-20
cap mvat-2-vlan20-not-allowed sw2:eth1 10s; started
expect_ok 1 10.35.0.12; expect_no 2 10.35.0.22
done_cap
ch sw2-trunk-undo
wait_for 20 ping_ok 2 10.35.0.22 || echo "      note: h2 -> h4 not back after 20 s"
# 3: mode mismatch: sw2's eth1 becomes an access port in VLAN 10, sw1's end stays a trunk. VLAN 10 frames from sw2
#    now leave untagged and sw1 has no untagged subinterface on the trunk: both VLANs fail. Recorded on sw2 eth1.
ch sw2-eth1-access-10
cap mvat-3-access-vs-trunk sw2:eth1 10s; started
expect_no 1 10.35.0.12; expect_no 2 10.35.0.22
done_cap
ch sw2-eth1-trunk
wait_for 20 ping_ok 1 10.35.0.12 || echo "      note: h1 -> h3 not back after 20 s"
wait_for 20 ping_ok 2 10.35.0.22 || echo "      note: h2 -> h4 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
