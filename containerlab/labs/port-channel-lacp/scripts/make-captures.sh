#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=port-channel-lacp; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need lacp-1-member-1 'lacp' 4
need lacp-1-member-2 'lacp' 4
need lacp-2-member-down 'lacp' 4
need lacp-3-partner-silent 'lacp' 4
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
ping_ok()   { docker exec $N-h1 ping -c 3 -W 1 10.43.0.12 >>"$LOG" 2>&1; }
expect_ok() { ping_ok || { echo "      h1 -> h2 should work and did not"; badf=1; }; }
expect_no() { ping_ok && { echo "      h1 -> h2 should fail and worked"; badf=1; }; true; }
is_srl() { docker exec $N-$1 sh -c 'command -v sr_cli' >/dev/null 2>&1; }
sr() {  # apply a change: SR Linux CLI in the full lab, or the matching .sh in the lighter lab
  if is_srl "$1"; then
    docker exec -i $N-$1 sr_cli <"changes/$2" >>"$LOG" 2>&1 || badf=1
  else
    bash "changes/${2%.cli}.sh" >>"$LOG" 2>&1 || badf=1
  fi
}
lag_up() { docker exec $N-sw1 sr_cli "show lag lag1" 2>>"$LOG" | grep -q "lag1 is up"; }
lag_down() { ! lag_up; }
two_up() { [ "$(docker exec $N-sw1 sr_cli "show lag lag1" 2>>"$LOG" | grep -cE '^\| ethernet-1/[12] +\| up ')" = 2 ]; }
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
# Both switches must be up and the port channel bundled (SR Linux takes a minute or two). The loop ends after 180 seconds.
wait_for 180 two_up || { echo "lag1 on sw1 does not have two members up after 180 seconds. Is the lab deployed?"; exit 1; }
wait_for 60 ping_ok || { echo "h1 cannot reach h2. Is the lab deployed?"; exit 1; }
# 1: the bundle: LACPDUs once a second each way on BOTH members, and h1's ping to h2 (it uses one member: the hash picks it).
cap lacp-1-member-1 sw1:e1-1 10s; cap lacp-1-member-2 sw1:e1-2 10s; started
expect_ok; two_up || badf=1
done_cap
# 2: one member down: sw1's ethernet-1/2 is disabled. lag1 stays up on one member; h1 still reaches h2, over member 1.
cap lacp-2-member-down sw1:e1-1 12s; started
sr sw1 sw1-member2-down.cli
sleep 2; lag_up || badf=1; expect_ok
done_cap
sr sw1 sw1-member2-up.cli
wait_for 30 two_up || echo "      note: two members not up again after 30 s"
# 3: LACP off at one end: sw2's lag1 becomes a static LAG and sends no LACPDUs. sw1 hears no partner, takes both
#    members out of the bundle (lacp-down) and lag1 goes down: h1 cannot reach h2. Then the change is undone.
cap lacp-3-partner-silent sw1:e1-1 12s; started
sr sw2 sw2-lacp-off.cli
wait_for 8 lag_down || { echo "      lag1 on sw1 did not go down"; badf=1; }
expect_no
done_cap
sr sw2 sw2-lacp-on.cli
wait_for 30 two_up || echo "      note: two members not up again after 30 s"
wait_for 20 ping_ok || echo "      note: h1 -> h2 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
