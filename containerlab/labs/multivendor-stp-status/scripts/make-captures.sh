#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=multivendor-stp-status; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need mvstp-1-rstp-bpdus 'stp' 4
need mvstp-2-stp-bpdus 'stp' 4
need mvstp-3-alternate-takeover 'stp' 4
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
is_srl() { docker exec $N-$1 sh -c 'command -v sr_cli' >/dev/null 2>&1; }
sr() {  # apply a change: SR Linux CLI in the full lab, or the matching .sh in the lighter lab
  if is_srl "$1"; then
    docker exec -i $N-$1 sr_cli <"changes/$2" >>"$LOG" 2>&1 || badf=1
  else
    bash "changes/${2%.cli}.sh" >>"$LOG" 2>&1 || badf=1
  fi
}
linux_role() {  # linux_role <iface> on sw2: ROOT, DESIGNATED or ALTERNATE from sysfs
  # root_port is the bridge port number (brport/port_no), not the ifindex.
  local st pno rp
  st=$(docker exec $N-sw2 cat /sys/class/net/$1/brport/state 2>/dev/null | tr -d '\r\n') || { echo OTHER; return; }
  pno=$(docker exec $N-sw2 cat /sys/class/net/$1/brport/port_no 2>/dev/null | tr -d '\r\n')
  rp=$(docker exec $N-sw2 cat /sys/class/net/br0/bridge/root_port 2>/dev/null | tr -d '\r\n')
  case $st in
    3) if [ -n "$pno" ] && [ -n "$rp" ] && [ $((pno)) -eq $((rp)) ]; then echo ROOT; else echo DESIGNATED; fi ;;
    4) echo ALTERNATE ;;
    *) echo OTHER ;;
  esac
}
ch() { bash "changes/$1.sh" >>"$LOG" 2>&1 || badf=1; }
srport() { docker exec $N-$1 sr_cli "info from state /interface ethernet-1/$2 subinterface 0 bridge-table stp" 2>>"$LOG"; }
role() {  # role <switch> <port number>: ROOT, DESIGNATED, ALTERNATE...
  if is_srl "$1"; then
    srport "$1" "$2" | awk '/port-role/{print $2}'
  else
    case $2 in
      1) linux_role eth1 ;;
      2) linux_role eth2 ;;
      *) echo OTHER ;;
    esac
  fi
}
lxstate() { docker exec $N-sw3 bridge link show dev "$1" | grep -o 'state [a-z]*'; }
settled()   { [ "$(lxstate eth2)" = "state blocking" ] && [ "$(role sw2 1)" = ROOT ]; }
sw3_root()  { [ "$(role sw2 1)" = ALTERNATE ] && [ "$(role sw2 2)" = ROOT ]; }
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
# sw1 (and sw2 in the full lab) must be up and the tree settled (sw3 eth2 blocking). The loop ends after 180 seconds.
wait_for 180 settled || { echo "the tree is not settled after 180 seconds (sw3 eth2 blocking, sw2 e1-1 root). Is the lab deployed?"; exit 1; }
wait_for 30 ping_ok 1 10.36.0.13 || { echo "h1 cannot reach h3. Is the lab deployed?"; exit 1; }
# 1 and 2: the settled tree, recorded at the same time on two links that both carry sw1's BPDUs:
#    sw2 e1-1 (SR Linux to SR Linux): Rapid STP BPDUs (version 2); sw3 eth1 (SR Linux to Linux bridge): classic 802.1D
#    configuration BPDUs, because sw1 falls back to 802.1D on the port that faces the Linux bridge.
# In the lighter lab, do not overwrite the sample captures (they were recorded on the full lab).
# Also skip the Rapid STP alternate-port takeover: Linux 802.1D does not take over in 3 s.
if ! is_srl sw2; then
  ping_ok 1 10.36.0.12 || { echo "      h1 cannot reach h2"; fails=$((fails+1)); }
  [ "$(srport sw1 2 | awk '/oper-protocol/{print $2}')" = stp ] || { echo "      sw1 e1-2 should talk 802.1D (stp)"; fails=$((fails+1)); }
  ch sw3-priority-0
  wait_for 30 sw3_root || { echo "      sw2 eth1 should be ALTERNATE with sw3 as root"; fails=$((fails+1)); }
  wait_for 20 ping_ok 2 10.36.0.13 || { echo "      h2 cannot reach h3 with sw3 as root"; fails=$((fails+1)); }
  ch sw3-priority-undo
  wait_for 40 settled || echo "      note: the tree is not back to the start after 40 s"
  wait_for 20 ping_ok 1 10.36.0.13 || echo "      note: h1 -> h3 not back after 20 s"
  echo "ok    lighter lab: tree settled, new root, pings (sample captures not overwritten; Rapid STP alternate takeover needs the full lab)"
  ls -l captures
  [ $fails = 0 ] || { echo "$fails check(s) FAILED"; exit 1; }
  exit 0
fi
sw2cap=sw2:e1-1
cap mvstp-1-rstp-bpdus $sw2cap 10s; cap mvstp-2-stp-bpdus sw3:eth1 10s; started
ping_ok 1 10.36.0.12 || badf=1
[ "$(srport sw1 2 | awk '/oper-protocol/{print $2}')" = stp ] || { echo "      sw1 e1-2 should talk 802.1D (stp)"; badf=1; }
done_cap
# 3: Rapid STP's alternate port. sw3 gets priority 0 and becomes the root; sw2's e1-1 (toward sw1) becomes ALTERNATE.
#    Then the sw2 - sw3 link is cut: sw2's alternate port becomes its root port at once. Recorded on sw2 e1-1.
ch sw3-priority-0
wait_for 30 sw3_root || { echo "      sw2 e1-1 should be ALTERNATE with sw3 as root"; badf=1; }
wait_for 20 ping_ok 2 10.36.0.13 || badf=1
cap mvstp-3-alternate-takeover $sw2cap 12s; started
sr sw2 sw2-cut-to-sw3.cli
wait_for 3 eval '[ "$(role sw2 1)" = ROOT ]' || { echo "      sw2 e1-1 did not become ROOT within 3 s"; badf=1; }
wait_for 5 ping_ok 2 10.36.0.13 || { echo "      h2 -> h3 should work and did not"; badf=1; }
done_cap
sr sw2 sw2-restore-to-sw3.cli
ch sw3-priority-undo
wait_for 40 settled || echo "      note: the tree is not back to the start after 40 s"
wait_for 20 ping_ok 1 10.36.0.13 || echo "      note: h1 -> h3 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
