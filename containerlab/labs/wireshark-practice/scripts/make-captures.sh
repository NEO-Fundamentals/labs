#!/bin/bash
# Re-record this lab's sample captures from host-a's cable. The lab must be deployed. Run from the lab folder:
#   sudo bash scripts/make-captures.sh        (asks for your password; takes about two minutes)
cd "$(dirname "$0")/.." || exit 1
# It overwrites a sample in captures/ only when the new recording succeeds; a failed one prints FAIL and the old sample stays.
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
fails=0; LOG=/tmp/neo-$(basename "$PWD")-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need tcp-lab-run1-normal 'tcp' 4
need tcp-fault-drop 'tcp' 2
need tcp-fault-reject 'tcp' 2
need tcp-fault-loss 'tcp' 4
need tcp-fault-zerowin 'tcp' 4
need tcp-fault-mtu 'tcp' 4
need tcp-fault-midrst 'tcp.flags.reset == 1' 1
need dns-rcode 'dns' 4
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
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
L=wireshark-practice; N=clab-$L; A=$N-host-a; IP=172.16.100.20; mkdir -p captures
restart_noread() {  # the zero-window test leaves a stuck connection; restart that server so later captures stay clean
  docker exec $N-host-b pkill -f 'tcp-server.py noread'; sleep 1
  docker exec -d $N-host-b python3 /neo/scripts/tcp-server.py noread 8082; sleep 2
}
fault() {  # fault <drop|loss|mtu> <on|off>: a fault that does not switch on makes the running capture FAIL
  bash scripts/faults.sh "$1" "$2" || { echo "      faults.sh $1 $2 did not work"; badf=1; }
}
cap() {  # cap <name> <seconds>: record in the background, then wait until the recording has actually started
  containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & cpid=$!; f="captures/$1.pcapng";
  wait_started
}
cap tcp-lab-run1-normal 6s;  docker exec $A sh -c "nc -w 5 $IP 8080 | wc -c"; done_cap
cap tcp-fault-drop 14s;   fault drop on;  docker exec $A sh -c "nc -w 10 $IP 8080 | wc -c";  fault drop off; done_cap
cap tcp-fault-reject 6s;  docker exec $A nc -w 3 $IP 8081; done_cap
cap tcp-fault-loss 14s;   fault loss on;  docker exec $A sh -c "nc -w 10 $IP 8080 | wc -c"; fault loss off; done_cap
restart_noread   # start from a fresh no-read server, so the sample holds only this test
cap tcp-fault-zerowin 14s; docker exec $A sh -c "head -c 3000000 /dev/zero | nc -w 8 $IP 8082"; done_cap
restart_noread
cap tcp-fault-mtu 16s;    fault mtu on;   docker exec $A sh -c "head -c 100000 /dev/zero | nc -w 10 $IP 8085"; done_cap
# switch the MTU fault off only after the capture has ended, then give the stuck connection 15 s to finish, so it does not spill into the next sample
bash scripts/faults.sh mtu off; sleep 15
cap tcp-fault-midrst 8s;  docker exec $A sh -c "nc -w 5 $IP 8083 | wc -c"; done_cap
cap dns-rcode 8s;         docker exec $A dig +tries=1 +time=2 @$IP www.lab.example; docker exec $A dig +tries=1 +time=2 @$IP nosuch.lab.example; docker exec $A dig +tries=1 +time=2 @$IP www.example.org; done_cap
# trim each packet to 200 bytes (the payload is filler) so the files stay small
for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
