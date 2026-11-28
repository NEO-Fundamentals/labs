#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed and neither client may have an address yet
# (deploy or redeploy the lab first). It overwrites the samples in ../captures/ only when a new recording succeeds;
# a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about 3 minutes)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=dhcp-dora-relay; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need dhcp-1-dora-direct 'dhcp' 4
need dhcp-2-dora-relay 'dhcp' 4
need dhcp-3-renew 'dhcp' 2
need dhcp-4-release 'dhcp.option.dhcp == 7' 1
need dhcp-5-no-server 'dhcp' 2
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
cap() {  # cap <file> <seconds> <node:interface> [<node:interface>]: record in the background into a .tmp file, then wait until the recording has actually started
  f=captures/$1.pcapng; d=$2; shift 2; t=(); for x in "$@"; do t+=(--target "$x"); done
  containerlab capture --name $L "${t[@]}" --duration "$d" -w "$f.tmp" >>"$LOG" 2>&1 & cpid=$!
  wait_started
}
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
# Wait until r1 (SR Linux, 1 to 2 minutes after deploy) has its relay up. The loop ends after 4 minutes at most.
until docker exec $N-r1 sr_cli "info from state /interface ethernet-1/2 subinterface 0 ipv4 dhcp-relay oper-state" 2>/dev/null | grep -q 'oper-state up'; do
  [ $SECONDS -lt 240 ] || { echo "r1's DHCP relay is not up after 4 minutes. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
  sleep 5
done
docker exec $N-client-1 ip -4 addr show eth1 | grep -q inet && { echo "client-1 already has an address. Redeploy the lab first."; exit 1; }
# 1: DORA on one cable: client-1 broadcasts, the server on the same cable answers.
cap dhcp-1-dora-direct 10s srv:eth1; docker exec $N-client-1 dhclient -v -1 eth1; done_cap
# 2: DORA through the relay: client-2's broadcast (its cable) and the relayed unicast (the server's cable to r1), in one file.
cap dhcp-2-dora-relay 10s client-2:eth1 srv:eth2; docker exec $N-client-2 dhclient -v -1 eth1; done_cap
# 3: the renewal: about one minute after the lease (half the 2-minute lease), client-2 renews with a unicast request to the server.
cap dhcp-3-renew 75s client-2:eth1 srv:eth2; done_cap
# 4: the release: client-2 gives its address back.
cap dhcp-4-release 8s client-2:eth1 srv:eth2; docker exec $N-client-2 dhclient -v -r eth1; done_cap
# 5: no server: dnsmasq is stopped, client-2 broadcasts DISCOVER, r1 relays it, nobody answers. Then the server is started again.
docker exec $N-srv pkill dnsmasq; sleep 1
cap dhcp-5-no-server 24s client-2:eth1 srv:eth2; docker exec $N-client-2 timeout 18 dhclient -v -1 eth1; done_cap
docker exec $N-srv dnsmasq --conf-file=/etc/neo/dnsmasq.conf
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 400 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
