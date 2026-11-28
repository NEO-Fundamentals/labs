#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
# It starts by switching any route leak off, and it switches the leak off again at the end.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=vrf-two-tables; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need vrf-1-isolation 'icmp or arp' 2
need vrf-2-one-way-leak 'icmp or arp' 2
need vrf-3-two-way-leak 'icmp or arp' 2
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
cap() {  # cap <file> "<node:interface> ..." <seconds>: record in the background into a .tmp file, then wait until the recording has actually started
  f=captures/$1.pcapng; local t targets=()
  for t in $2; do targets+=(--target "$t"); done
  containerlab capture --name $L "${targets[@]}" --duration "$3" -w "$f.tmp" >>"$LOG" 2>&1 & cpid=$!
  wait_started
}
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
srl() { docker exec -i $N-r1 sr_cli <"changes/$1" >>"$LOG" 2>&1; }
ping3() { docker exec $N-h1 ping -c 3 -W 1 10.12.3.10 >>"$LOG" 2>&1; }  # true only if replies come back
# SR Linux needs a minute or two after Deploy. Wait until it accepts the "no leak" change. The loop ends after 180 seconds.
t0=$SECONDS; until srl leak-undo.cli; do
  [ $((SECONDS - t0)) -lt 180 ] || { echo "r1 (SR Linux) does not accept commands after 180 seconds. Is the lab deployed?"; exit 1; }
  sleep 5; done
sleep 2
# 1: isolation: h1 (VRF alpha) pings h3 (VRF beta). alpha has no route to 10.12.3.0/24, so r1 answers "net unreachable".
cap vrf-1-isolation "h1:eth1 h3:eth1" 10s
ping3 && { echo "      h1 reached h3 without a leak"; badf=1; }
done_cap
# 2: one-way leak: alpha learns h3's route, beta does not learn h1's. The request reaches h3, the reply is lost at r1.
srl leak-1-alpha-takes-h3.cli || { echo "      leak-1 was not accepted"; badf=1; }
sleep 3
cap vrf-2-one-way-leak "h1:eth1 h3:eth1" 10s
ping3 && { echo "      h1 got replies with a one-way leak"; badf=1; }
done_cap
# 3: two-way leak: beta also learns h1's and h2's routes, and the ping works.
srl leak-2-beta-takes-alpha.cli || { echo "      leak-2 was not accepted"; badf=1; }
sleep 3
cap vrf-3-two-way-leak "h1:eth1 h3:eth1" 10s
ping3 || { echo "      h1 got no replies with a two-way leak"; badf=1; }
done_cap
srl leak-undo.cli || echo "      note: switching the leak off failed; redeploy the lab to start clean"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
