#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=ospf-single-area; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ospf-1-adjacency 'ospf' 4
need ospf-2-cost-change 'ospf' 4
need ospf-3-hello-mismatch 'ospf' 4
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
full() { docker exec $N-r1 vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full"; }
nh() { docker exec $N-r1 vtysh -c "show ip route 10.10.2.0/24" 2>/dev/null | grep -oE '10\.10\.1[23]\.2, via' | head -1 | cut -d, -f1; }
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
two_full() { [ "$(full)" = 2 ]; }
one_full() { [ "$(full)" = 1 ]; }
via() { [ "$(nh)" = "$1" ]; }
vt() { docker exec -i $N-r1 vtysh <"changes/$1" >>"$LOG" 2>&1 || badf=1; }
# r1 needs two Full neighbours (r2 and r3) before we start. The loop ends after 90 seconds.
wait_for 90 two_full || { echo "r1 does not have two Full OSPF neighbours after 90 seconds. Is the lab deployed?"; exit 1; }
# 1: adjacency on the r1 - r2 link: hellos every second, then r2's port goes down and up again, so the two routers
#    build the adjacency from scratch (Hello, Database Description, LS Request, LS Update, LS Ack).
cap ospf-1-adjacency r1:eth2 25s
docker exec $N-r2 ip link set eth2 down; sleep 3; docker exec $N-r2 ip link set eth2 up
wait_for 18 two_full || { echo "      r1 - r2 did not come back to Full"; badf=1; }
done_cap
# 2: cost change: r1 eth2 cost 100, r1 floods its new router LSA and moves 10.10.2.0/24 to r3; then the cost goes back.
cap ospf-2-cost-change r1:eth2,eth3 20s
vt r1-cost-100.vtysh
wait_for 8 via 10.10.13.2 || { echo "      r1 did not move to r3"; badf=1; }
sleep 4; vt r1-cost-undo.vtysh
wait_for 8 via 10.10.12.2 || { echo "      r1 did not move back to r2"; badf=1; }
done_cap
# 3: hello mismatch: r1 sends hellos every 2 s on eth2, r2 every 1 s. Both ignore each other's hellos, so the
#    neighbour never reaches Full, while a plain ping on the same cable works.
cap ospf-3-hello-mismatch r1:eth2 20s
vt r1-hello-mismatch.vtysh
wait_for 10 one_full || { echo "      r1 - r2 did not leave Full"; badf=1; }
done_cap
vt r1-hello-undo.vtysh
wait_for 20 two_full || echo "      note: r1 - r2 not back to Full after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
