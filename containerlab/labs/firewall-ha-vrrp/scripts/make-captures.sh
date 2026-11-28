#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about two minutes)
# It "unplugs" fw1 four times (inside, outside and HA links down, then up again) and leaves the pair as after a
# deploy: fw1 active, conntrackd running, strict TCP state on both firewalls.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=firewall-ha-vrrp; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ha-1-failover 'vrrp or icmp' 4
need ha-2-session-strict 'tcp or vrrp' 4
need ha-3-session-loose 'tcp or vrrp' 4
need ha-4-session-sync 'tcp or vrrp' 4
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
fw1_links() { docker exec $N-fw1 sh -c "ip link set eth1 $1; ip link set eth2 $1; ip link set eth3 $1" >>"$LOG" 2>&1; }   # fw1_links up|down
loose() { docker exec $N-$1 sysctl -q -w net.netfilter.nf_conntrack_tcp_loose=$2 >>"$LOG" 2>&1; }      # loose <fw> 0|1
fw1_active() {  # bring fw1 back and wait (up to 20 s) until it holds the inside virtual address again
  fw1_links up
  for i in $(seq 20); do docker exec $N-fw1 ip -4 addr show eth1 | grep -q 10.18.1.1/ && break; sleep 1; done
  docker exec $N-fw1 ip -4 addr show eth1 | grep -q 10.18.1.1/ || { echo "      fw1 did not become active again"; badf=1; }
  sleep 3
}
session() { docker exec $N-host-a python3 -u /neo/scripts/session.py 10.18.2.20 7000 "$1" >"/tmp/neo-$L-session.out" 2>&1; }
# Start as after a deploy: fw1 plugged in and active, strict TCP state on both. Then the lab must be up: host-a reaches
# host-b's web page through the active firewall. Waits up to 30 seconds.
loose fw1 0; loose fw2 0; fw1_active; badf=
for i in $(seq 30); do docker exec $N-host-a curl -s -m 2 -o /dev/null http://10.18.2.20/ && break; sleep 1; done
docker exec $N-host-a curl -s -m 2 -o /dev/null http://10.18.2.20/ || { echo "host-a cannot reach host-b. Is the lab deployed?"; exit 1; }
# 1: failover. Recorded on host-a eth1 (inside LAN): fw1's VRRP advertisements (from 10.18.1.2) every second and pings
#    every half second; fw1 is unplugged; a gap of about 3.5 s; fw2 sends gratuitous ARPs for 10.18.1.1 and its own
#    advertisements (from 10.18.1.3), and the pings come back.
cap ha-1-failover host-a:eth1 14s; started
docker exec $N-host-a ping -i 0.5 -c 20 -W 1 10.18.2.20 >"/tmp/neo-$L-ping.out" 2>&1 & pp=$!
sleep 3; fw1_links down; wait $pp
lost=$(awk '/packets transmitted/{print $1-$4}' "/tmp/neo-$L-ping.out")
[ -n "$lost" ] && [ "$lost" -ge 3 ] && [ "$lost" -le 14 ] || { echo "      expected a short gap in the pings, lost: ${lost:-?}"; badf=1; }
done_cap; fw1_active
# Stop session sync for captures 2 and 3 (they show a failover without a copied session table).
docker exec $N-fw1 sh -c 'kill $(pgrep conntrackd) || true' >>"$LOG" 2>&1
docker exec $N-fw2 sh -c 'kill $(pgrep conntrackd) || true' >>"$LOG" 2>&1
sleep 1
# 2: a session during failover, strict TCP state (no session sync). Recorded on host-a eth1: ticks and answers, fw1 is
#    unplugged, then only host-a's retransmissions: fw2 has never seen the session and drops them as invalid.
cap ha-2-session-strict host-a:eth1 20s; started
session 30 & sp=$!; sleep 3; fw1_links down; wait $sp
tail -n 1 "/tmp/neo-$L-session.out" | grep -q "no reply" || { echo "      the session should have stopped after the failover"; badf=1; }
done_cap; fw1_active
# 3: the same with loose TCP state on fw2 (it adopts a session from the middle). Recorded on host-a eth1: after the gap
#    the retransmitted ticks are answered and the session carries on.
loose fw2 1
cap ha-3-session-loose host-a:eth1 20s; started
session 30 & sp=$!; sleep 3; fw1_links down; wait $sp
tail -n 1 "/tmp/neo-$L-session.out" | grep -q ": ok " || { echo "      the session should have carried on after the failover"; badf=1; }
done_cap
loose fw2 0; fw1_active
# 4: session sync running. Restart conntrackd, wait for a copy of a new session to reach fw2, then unplug fw1; the
#    session should survive after the short VRRP gap. If conntrackd cannot start (no nf_conntrack_netlink in the
#    kernel), skip this capture and say so; the first three samples are still written.
docker exec $N-fw1 conntrackd -d -C /etc/neo/conntrackd.conf >>"$LOG" 2>&1
docker exec $N-fw2 conntrackd -d -C /etc/neo/conntrackd.conf >>"$LOG" 2>&1
sleep 1
if docker exec $N-fw1 pgrep -x conntrackd >/dev/null && docker exec $N-fw2 pgrep -x conntrackd >/dev/null; then
  cap ha-4-session-sync host-a:eth1 20s; started
  session 30 & sp=$!; sleep 3; fw1_links down; wait $sp
  tail -n 1 "/tmp/neo-$L-session.out" | grep -q ": ok " || { echo "      the session should have survived with session sync"; badf=1; }
  done_cap
  fw1_active
else
  echo "SKIP  captures/ha-4-session-sync.pcapng (conntrackd did not start; the kernel needs nf_conntrack_netlink)"
  docker exec $N-fw1 tail -n 5 /var/log/conntrackd.log >>"$LOG" 2>&1
fi
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
