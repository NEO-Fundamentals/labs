#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about a minute)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=firewall-troubleshooting; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need fwts-1-inside 'tcp or arp' 2
need fwts-1-outside 'arp' 1
need fwts-2-change 'tcp' 4
need fwts-3-beyond 'tcp' 1
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
policy() { docker exec -i $N-fw nft -f - <"changes/$1.nft" >>"$LOG" 2>&1 || badf=1; }   # policy <change file name>
web() { docker exec $N-$1 curl -s -m 3 -o /dev/null -w '%{http_code}' "$2" 2>>"$LOG"; }  # web <host> <url>: HTTP code, 000 = no answer
expect() { local got; got=$(web "$2" "$3"); [ "$got" = "$1" ] || { echo "      $2 -> $3 should give $1, gave $got"; badf=1; }; }
base() { docker exec $N-fw nft -f /neo/configs/fw-rules.nft >>"$LOG" 2>&1 || badf=1; }   # fw back to its deploy rules
# Start from the deploy rules (this also empties the drop record); then the lab must be up: host-a reaches host-b's web
# page on port 80. Waits up to 30 seconds.
base; badf=
for i in $(seq 30); do [ "$(web host-a http://10.19.2.80/)" = 200 ] && break; sleep 1; done
[ "$(web host-a http://10.19.2.80/)" = 200 ] || { echo "host-a cannot reach host-b's web page. Is the lab deployed?"; exit 1; }
# 1: the symptom, on both sides of fw at the same time. host-a asks for the app on 8443. Inside (fw eth1): the SYN and two
#    retries. Outside (fw eth2): nothing; the packets reached fw and did not leave it.
cap fwts-1-inside fw:eth1 10s; cap fwts-1-outside fw:eth2 10s; started
expect 000 host-a http://10.19.2.80:8443/
done_cap
# 2: after the change (one rule for 8443). Recorded on fw eth2 (outside): the whole connection to host-b:8443.
policy change-1-app-8443
cap fwts-2-change fw:eth2 8s; started
expect 200 host-a http://10.19.2.80:8443/
done_cap
# 3: beyond the firewall. Recorded on fw eth2 (outside): port 9000, the SYN leaves and host-b answers with a reset
#    (nothing listens); port 9100, the SYN leaves three times and nothing answers (host-b's own host firewall).
cap fwts-3-beyond fw:eth2 10s; started
expect 000 host-a http://10.19.2.80:9000/
expect 000 host-a http://10.19.2.80:9100/
done_cap
base
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
