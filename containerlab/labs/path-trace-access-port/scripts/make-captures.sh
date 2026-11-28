#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes under a minute)
# It puts the faults of exercises 4 and 5 in place with scripts/fault.sh and undoes each one, so the lab is left as after
# a deploy (sw's eth3 in bridge vlan10, eth2 up).
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=path-trace-access-port; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ap-1-arp 'arp' 2
need ap-2-wrong-vlan 'arp or icmp or vlan' 1
need ap-3-port-down 'arp or icmp' 1
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
cap() {  # cap <file> <node:interface[,interface]> <seconds>: record in the background into a .tmp file
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & pids+=($!)
  files+=("captures/$1.pcapng")
}
started() { wait_started; }   # wait until each recording has actually started (pcapng header written)
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty and the checks passed
  local i f
  for i in "${!files[@]}"; do f=${files[$i]}
    if wait "${pids[$i]}" && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
    else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
      echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  done
  files=(); pids=(); badf=
}
restore() {  # sw's ports as at deploy
  docker exec $N-sw ip link set eth3 master vlan10 >>"$LOG" 2>&1
  docker exec $N-sw ip link set eth2 up >>"$LOG" 2>&1
}
fresh_ping() {  # fresh_ping <address>: r1 forgets the address's ARP entry, then pings it twice; true if a reply came
  docker exec $N-r1 ip neigh flush to "$1" >>"$LOG" 2>&1
  docker exec $N-r1 ping -c 2 -W 1 "$1" >/dev/null
}
# Start as after a deploy; then the lab must be up: r1 reaches host-a, host-b and host-c (waits up to 30 seconds).
restore; sleep 2
for i in $(seq 30); do fresh_ping 10.25.10.12 && break; sleep 1; done
for a in 10.25.10.11 10.25.10.12 10.25.20.13; do fresh_ping $a || { echo "r1 cannot reach $a. Is the lab deployed?"; exit 1; }; done
# 1: from IP to MAC (exercises 1 to 3), recorded on sw eth3 (host-b's access port): r1's ARP request for 10.25.10.12
#    (a broadcast, so every VLAN 10 port sees it), host-b's reply with 02:00:00:25:10:12, then two pings.
cap ap-1-arp sw:eth3 7s; started
fresh_ping 10.25.10.12 || { echo "      r1 got no reply from host-b"; badf=1; }
done_cap
# 2: the wrong VLAN (exercise 4), recorded on sw eth1 and eth5 (r1's VLAN 10 and VLAN 20 links): r1's ARP requests for
#    10.25.10.12 go out in VLAN 10 unanswered; host-b's own ARP requests for its gateway 10.25.10.1 come in on r1's
#    VLAN 20 link, and r1 does not answer them there.
bash scripts/fault.sh 1 >>"$LOG"
cap ap-2-wrong-vlan sw:eth1,eth5 9s; started
docker exec $N-host-b ip neigh flush dev eth1 >>"$LOG" 2>&1
docker exec $N-host-b ping -c 2 -W 1 10.25.10.1 >/dev/null && { echo "      host-b reached its gateway in the wrong VLAN"; badf=1; }
fresh_ping 10.25.10.12 && { echo "      r1 reached host-b in the wrong VLAN"; badf=1; }
done_cap; restore
# 3: a port that is down (exercise 5), recorded on sw eth1 (r1's VLAN 10 link): r1's ARP requests for 10.25.10.11
#    (host-a) are never answered.
bash scripts/fault.sh 2 >>"$LOG"
cap ap-3-port-down sw:eth1 7s; started
fresh_ping 10.25.10.11 && { echo "      r1 reached host-a through a port that is down"; badf=1; }
done_cap; restore; sleep 2
fresh_ping 10.25.10.11 || echo "      note: r1 does not reach host-a after the restore"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
