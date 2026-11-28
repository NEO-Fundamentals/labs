#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It removes any NAT rules you added, records, and
# removes them again at the end. It overwrites the samples in ../captures/ only when a new recording succeeds;
# a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=private-public-nat; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need nat-1-private-dropped 'icmp' 2
need nat-2-snat 'icmp' 2
need nat-3-private-destination 'icmp' 2
need nat-4-port-forward 'tcp' 4
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
cap() {  # cap <file> <seconds> <node:interfaces>: record in the background into a .tmp file, then wait until the recording has actually started
  f=captures/$1.pcapng
  containerlab capture --name $L --target "$3" --duration "$2" -w "$f.tmp" >>"$LOG" 2>&1 & cpid=$!
  wait_started
}
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
nat_off() { docker exec $N-rtr-a nft delete table ip neo_snat 2>/dev/null; docker exec $N-rtr-b nft delete table ip neo_dnat 2>/dev/null; }
# Wait until the ISP (FRR loads its addresses 10 to 20 s after deploy) answers rtr-a. The loop ends after 90 seconds at most.
until docker exec $N-rtr-a ping -c 1 -W 1 192.168.200.1 >/dev/null 2>&1; do
  [ $SECONDS -lt 90 ] || { echo "rtr-a cannot reach the ISP after 90 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
  sleep 2
done
nat_off
# 1: no NAT. host-a's packets leave site A with the private source 10.46.1.10; the ISP drops them, nothing comes back.
cap nat-1-private-dropped 8s rtr-a:eth2; docker exec $N-host-a ping -c 3 -W 1 192.168.200.6; done_cap
# 2: source NAT on rtr-a. The same ping, seen on both of rtr-a's cables: private source inside, public source outside.
docker exec -i $N-rtr-a nft -f - < changes/rtr-a-snat-on.nft
cap nat-2-snat 8s rtr-a:eth1,eth2; docker exec $N-host-a ping -c 3 -W 1 192.168.200.6; done_cap
# 3: a private destination. The ISP has no route to 10.46.2.10 and says so (Destination Net Unreachable).
cap nat-3-private-destination 8s rtr-a:eth1,eth2; docker exec $N-host-a ping -c 2 -W 1 10.46.2.10; done_cap
# 4: a port forward on rtr-b. host-a asks rtr-b's public address for a web page; rtr-b passes it to host-b (10.46.2.10).
docker exec -i $N-rtr-b nft -f - < changes/rtr-b-port-forward-on.nft
cap nat-4-port-forward 8s rtr-b:eth1,eth2; docker exec $N-host-a curl -sS -m 3 http://192.168.200.6/; done_cap
nat_off
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
