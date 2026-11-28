#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=spanning-tree-triangle; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need stp-1-bpdus 'stp' 4
need stp-2-link-failure 'stp' 4
need stp-3-new-root 'stp' 4
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
ping_ok()   { docker exec $N-h$1 ping -c 2 -W 1 "$2" >>"$LOG" 2>&1; }   # ping_ok <host number> <address>
expect_ok() { ping_ok "$1" "$2" || { echo "      h$1 -> $2 should work and did not"; badf=1; }; }
state()     { docker exec $N-$1 bridge link show dev "$2" | grep -o 'state [a-z]*'; }   # state <switch> <port>
expect_state() { [ "$(state "$1" "$2")" = "state $3" ] || { echo "      $1 $2 should be $3, is $(state "$1" "$2")"; badf=1; }; }
root_id()   { docker exec $N-$1 cat /sys/class/net/br0/bridge/root_id; }
ch() { bash "changes/$1.sh" >>"$LOG" 2>&1 || badf=1; }
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
blocked()    { [ "$(state sw3 eth2)" = "state blocking" ]; }
forwarding() { [ "$(state sw3 eth2)" = "state forwarding" ]; }
sw3_root()   { [ "$(root_id sw2)" = "0000.020000080003" ]; }
# The tree must be settled before we start (about 10 s after Deploy). The loop ends after 60 seconds.
wait_for 60 blocked || { echo "sw3 eth2 is not blocking after 60 seconds. Is the lab deployed?"; exit 1; }
wait_for 30 ping_ok 1 10.8.0.13 || { echo "h1 cannot reach h3. Is the lab deployed?"; exit 1; }
# 1: the settled tree: sw1 (the root) sends a BPDU every second on its designated port toward sw2. Recorded on sw2 eth1.
cap stp-1-bpdus sw2:eth1 10s
expect_ok 1 10.8.0.12; expect_state sw3 eth2 blocking; [ "$(root_id sw2)" = "1000.020000080001" ] || badf=1
done_cap
# 2: link failure: the sw1 - sw3 link is cut; sw3's blocked port (eth2, toward sw2) goes listening -> learning ->
#    forwarding and becomes sw3's root port. Recorded on that port, sw3 eth2.
cap stp-2-link-failure sw3:eth2 22s
ch cut-sw1-sw3
wait_for 15 forwarding || { echo "      sw3 eth2 did not reach forwarding in 15 s"; badf=1; }
# The switches may still send h3's frames the old way for a few seconds (their MAC tables are being re-learned), so retry.
wait_for 10 ping_ok 1 10.8.0.13 || { echo "      h1 -> 10.8.0.13 should work and did not (10 s after forwarding)"; badf=1; }
done_cap
ch restore-sw1-sw3
wait_for 30 blocked || echo "      note: sw3 eth2 not blocking again after 30 s"
# 3: a new root: sw3 gets priority 0 and wins the election; the BPDUs on sw2 eth1 now name sw3 as the root
#    (0000.020000080003). Recorded on sw2 eth1. Then the change is undone.
cap stp-3-new-root sw2:eth1 14s
ch sw3-priority-0
wait_for 8 sw3_root || { echo "      sw2 does not see sw3 as the root"; badf=1; }
done_cap
ch sw3-priority-undo
wait_for 30 blocked || echo "      note: sw3 eth2 not blocking again after 30 s"
wait_for 20 ping_ok 1 10.8.0.13 || echo "      note: h1 -> h3 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
