#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about a minute)
# It loads the tunnel on both gateways (as in exercise 2) and leaves it loaded and up at the end.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=vpn-ipsec-site-to-site; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need vpn-1-ike-esp 'isakmp or esp' 4
need vpn-2-site-b-clear 'icmp or http or tcp' 4
need vpn-3-proposal-mismatch 'isakmp' 2
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
sw() { docker exec $N-$1 swanctl "${@:2}" >>"$LOG" 2>&1; }   # sw <gw-a|gw-b> <swanctl arguments>
pings() { docker exec $N-host-a ping -c "$1" -W 1 10.17.2.20 >>"$LOG" 2>&1; }  # pings <count>: exit 0 if any answer came
# The lab must be up: the two gateways reach each other across wan. Waits up to 30 seconds.
for i in $(seq 30); do docker exec $N-gw-a ping -c 1 -W 1 10.17.200.1 >/dev/null 2>&1 && break; sleep 1; done
docker exec $N-gw-a ping -c 1 -W 1 10.17.200.1 >/dev/null 2>&1 || { echo "gw-a cannot reach gw-b. Is the lab deployed?"; exit 1; }
# Start from the exercise 2 configuration with no tunnel up: load both gateways (gw-b's own file again, in case the
# exercise 4 break is still loaded) and end any IKE session.
sw gw-a --load-all; sw gw-b --load-all; sw gw-a --terminate --ike site-to-site; sw gw-b --terminate --ike site-to-site; sleep 1; badf=
# 1 and 2, recorded at the same time: the tunnel comes up and carries three pings and one web request.
#   On wan eth1 (the "Internet"): IKE_SA_INIT and IKE_AUTH (UDP 500), then only ESP between 10.17.100.1 and 10.17.200.1.
#   On gw-b eth1 (site B LAN): the same pings and the web request in clear text, between 10.17.1.10 and 10.17.2.20.
cap vpn-1-ike-esp wan:eth1 12s; cap vpn-2-site-b-clear gw-b:eth1 12s; started
sw gw-a --initiate --child lan-to-lan || { echo "      the tunnel did not come up"; badf=1; }
pings 3 || { echo "      no ping answer through the tunnel"; badf=1; }
docker exec $N-host-a curl -s -m 3 http://10.17.2.20/ | grep -q "hello from host-b" || { echo "      no web page through the tunnel"; badf=1; }
done_cap
# 3: proposal mismatch. Recorded on wan eth1: gw-b offers only AES-128-GCM for ESP; IKE_SA_INIT and IKE_AUTH run, gw-b's
#    IKE_AUTH answer carries NO_PROPOSAL_CHOSEN (inside the encrypted part), and no ESP follows.
sw gw-b --load-conns --file /neo/changes/gw-b-esp-aes128.conf; sw gw-a --terminate --ike site-to-site; sleep 1
cap vpn-3-proposal-mismatch wan:eth1 8s; started
docker exec $N-gw-a swanctl --initiate --child lan-to-lan 2>&1 | tee -a "$LOG" | grep -q NO_PROPOSAL_CHOSEN || { echo "      gw-a did not report NO_PROPOSAL_CHOSEN"; badf=1; }
done_cap
# Back to the working tunnel.
sw gw-b --load-conns; sw gw-a --terminate --ike site-to-site; sleep 1; sw gw-a --initiate --child lan-to-lan
pings 2 || echo "      note: the tunnel did not come back up; run swanctl --initiate --child lan-to-lan on gw-a"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
