#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about a minute)
# It loads ids's deploy policy at the start and again at the end.
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=ngfw-inspection; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ngfw-1-app-id 'http or tls' 2
need ngfw-2-sni-block-client-side 'tcp or tls' 2
need ngfw-2-sni-block-server-side 'tcp' 1
need ngfw-3-threat-client-side 'http or tcp' 2
need ngfw-3-threat-server-side 'http or tcp' 2
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
policy() { docker exec -i $N-ids sh -c 'cat > /etc/neo/inspect.rules' <"$1" 2>>"$LOG" || badf=1; sleep 2; }   # policy <rules file>; ids re-reads it within a second
web() { docker exec $N-client curl -s -k -m 3 -o /dev/null -w '%{http_code} %{size_download}' "$1" 2>>"$LOG"; }  # web <url>: "code bytes"
expect() { local got; got=$(web "$2"); [ "$got" = "$1" ] || { echo "      $2 should give $1, gave $got"; badf=1; }; }
# Start from the deploy policy (visibility only); then the lab must be up: client reaches the web page through ids.
# Waits up to 30 seconds.
policy configs/inspect-start.rules; badf=
for i in $(seq 30); do [ "$(web http://news.lab.test/)" = "200 43" ] && break; sleep 1; done
[ "$(web http://news.lab.test/)" = "200 43" ] || { echo "client cannot reach the web server. Is the lab deployed?"; exit 1; }
# 1: application identification. Recorded on ids eth1 (client side): HTTP to news.lab.test (Host header), HTTPS to
#    news.lab.test (the server name in the TLS ClientHello), and an SSH banner from port 8443.
cap ngfw-1-app-id ids:eth1 10s; started
expect "200 43" http://news.lab.test/
expect "200 43" https://news.lab.test/
docker exec $N-client sh -c 'timeout 2 nc 10.16.1.20 8443 </dev/null' 2>>"$LOG" | grep -q "^SSH-" || { echo "      no SSH banner from 10.16.1.20:8443"; badf=1; }
done_cap
# 2: URL filter in IPS mode, HTTPS to games.lab.test, recorded on both sides of ids at the same time. Client side: the
#    handshake and the ClientHello naming games.lab.test, retransmitted, never answered. Server side: the handshake only;
#    the ClientHello never arrives.
policy changes/url-filter-ips.rules
cap ngfw-2-sni-block-client-side ids:eth1 10s; cap ngfw-2-sni-block-server-side ids:eth2 10s; started
expect "000 0" https://games.lab.test/
done_cap
# The blocked connection keeps retrying in the background; end it on client so that it does not show up in the next
# recordings.
docker exec $N-client ss -K dst 10.16.1.20 dport = 443 >>"$LOG" 2>&1; sleep 1
# 3: threat signature in IPS mode, HTTP download of the test file, recorded on both sides at the same time. Server side:
#    the answer's body (with NEO-TEST-THREAT) leaves the server and is retransmitted. Client side: only the headers.
policy changes/threat.rules
cap ngfw-3-threat-client-side ids:eth1 10s; cap ngfw-3-threat-server-side ids:eth2 10s; started
expect "200 0" http://news.lab.test/download/update.txt
done_cap
expect "200 64" https://news.lab.test/download/update.txt   # the same file over HTTPS passes: the engine cannot see inside TLS
[ -n "$badf" ] && { echo "      note: the HTTPS download should pass"; badf=; }
policy configs/inspect-start.rules
docker exec $N-client ss -K dst 10.16.1.20 >>"$LOG" 2>&1   # end the blocked download that is still retrying
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
