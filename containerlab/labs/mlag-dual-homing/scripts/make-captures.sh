#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about three minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=mlag-dual-homing; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need mlag-1-member-leaf1 'lacp' 2
need mlag-1-member-leaf2 'lacp' 2
need mlag-2-leaf2-member-down 'lacp' 2
need mlag-3-two-system-ids 'lacp' 2
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
ping_ok()   { docker exec $N-h1 ping -c 3 -W 1 "$1" >>"$LOG" 2>&1; }   # ping_ok <address>: from h1
expect_ok() { ping_ok "$1" || { echo "      h1 -> $1 should work and did not"; badf=1; }; }
is_srl() { docker exec $N-$1 sh -c 'command -v sr_cli' >/dev/null 2>&1; }
sr() {  # apply a change: SR Linux CLI in the full lab, or the matching .sh in the lighter lab
  if is_srl "$1"; then
    docker exec -i $N-$1 sr_cli <"changes/$2" >>"$LOG" 2>&1 || badf=1
  else
    bash "changes/${2%.cli}.sh" >>"$LOG" 2>&1 || badf=1
  fi
}
bgp_up() { docker exec $N-leaf1 sr_cli "show network-instance default protocols bgp neighbor" 2>>"$LOG" | grep -q established; }
# aggregator IDs of h1's two bond members (the kernel's 802.3ad state); the same ID twice = one bundle with both members
aggs() { docker exec $N-h1 awk '/^Slave Interface/{s=$3} /Aggregator ID/&&s{print s":"$3; s=""}' /proc/net/bonding/bond0 2>>"$LOG"; }
one_bundle() { a=$(aggs); [ "$(echo "$a" | wc -l)" = 2 ] && [ "$(echo "$a" | cut -d: -f2 | sort -u | wc -l)" = 1 ]; }
two_bundles() { a=$(aggs); [ "$(echo "$a" | cut -d: -f2 | sort -u | wc -l)" = 2 ]; }
wait_for() {  # wait_for <seconds> <command...>: retry the check every second; the loop ends on the clock
  local t0=$SECONDS max=$1; shift
  until "$@"; do [ $((SECONDS - t0)) -lt "$max" ] || return 1; sleep 1; done
}
# In the lighter lab, do not overwrite the sample captures (they were recorded on the full lab).
wait_for 60 docker exec $N-leaf2 true || { echo "leaf2 is not up. Is the lab deployed?"; exit 1; }
if ! is_srl leaf2; then
  echo "ok    lighter lab: sample captures were recorded on the full lab and were not overwritten"
  ls -l captures
  exit 0
fi
docker exec $N-h1 test -e /proc/net/bonding/bond0 || { echo "h1 has no bond0 (this computer's kernel has no bonding driver?)"; exit 1; }
# Full lab: wait for BGP EVPN, then the host bond.
wait_for 240 bgp_up || { echo "BGP between the leaves is not established after 240 seconds. Is the lab deployed?"; exit 1; }
wait_for 60 one_bundle || { echo "h1's bond0 does not have both members in one aggregator. See: docker exec $N-h1 cat /proc/net/bonding/bond0"; exit 1; }
wait_for 60 ping_ok 10.44.0.13 || { echo "h1 cannot reach h3. Is the lab deployed?"; exit 1; }
# 1: one bundle, two switches: LACPDUs on both of h1's members. Both leaves send the SAME actor system ID
#    (02:00:00:44:00:aa) and key (44), so h1 puts both links in one aggregator. h1 pings h2 (on leaf1) and h3 (on leaf2).
cap mlag-1-member-leaf1 h1:eth1 12s; cap mlag-1-member-leaf2 h1:eth2 12s; started
expect_ok 10.44.0.12; expect_ok 10.44.0.13; one_bundle || badf=1
done_cap
# 2: leaf2's member is disabled. h1 keeps one member (to leaf1); h3 (on leaf2) is still reached, through leaf1 and the link between the leaves (VXLAN in the full lab, a plain peer link in the lighter lab).
cap mlag-2-leaf2-member-down h1:eth1 14s; started
sr leaf2 leaf2-member-down.cli
sleep 4; expect_ok 10.44.0.13; expect_ok 10.44.0.12
done_cap
sr leaf2 leaf2-member-up.cli
wait_for 30 one_bundle || echo "      note: bond0 not back to one aggregator after 30 s"
# 3: the two leaves no longer share a system ID (leaf2 says 02:00:00:44:00:bb): h1 sees two different partners and
#    puts its members in two aggregators; only one of them carries traffic. Recorded on h1's member to leaf2. Then undone.
cap mlag-3-two-system-ids h1:eth2 14s; started
sr leaf2 leaf2-other-system-id.cli
wait_for 8 two_bundles || { echo "      h1's members did not split into two aggregators"; badf=1; }
done_cap
sr leaf2 leaf2-system-id-undo.cli
wait_for 30 one_bundle || echo "      note: bond0 not back to one aggregator after 30 s"
wait_for 20 ping_ok 10.44.0.13 || echo "      note: h1 -> h3 not back after 20 s"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
