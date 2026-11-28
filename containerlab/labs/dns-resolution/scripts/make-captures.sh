#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. It overwrites the samples in ../captures/ only when a new
# recording succeeds; a failed one prints FAIL and the old sample stays.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh   (asks for your password; takes about one minute)
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=dns-resolution; N=clab-$L; ALL=resolver:eth1,eth2,eth3,eth4; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need dns-1-recursion 'dns' 4
need dns-2-cached 'dns' 2
need dns-3-nxdomain 'dns' 2
need dns-4-servfail-lame 'dns' 4
need dns-5-servfail-down 'dns' 4
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
cap() {  # cap <file> <node:interfaces> <seconds>: record in the background into a .tmp file, then wait until the recording has actually started
  f=captures/$1.pcapng
  containerlab capture --name $L --target "$2" --duration "$3" -w "$f.tmp" >>"$LOG" 2>&1 & cpid=$!
  wait_started
}
done_cap() {  # wait for the recording; keep it only if containerlab succeeded, the file is not empty, and it has the expected frames
  if wait $cpid && [ -z "$badf" ] && _file_ok "$f"; then mv "$f.tmp" "$f"; echo "ok    $f"
  else mv -f "$f.tmp" "/tmp/neo-$(basename "$f").failed" 2>/dev/null
    echo "FAIL  $f (the old sample is kept; containerlab messages are in $LOG)"; fails=$((fails+1)); fi
  badf=
}
# Wait until the resolver answers (BIND starts in a few seconds). The loop ends after 60 seconds at most.
until docker exec $N-client dig +short +time=2 +tries=1 www.corp.internal 2>/dev/null | grep -q '^10\.6\.20\.80$'; do
  [ $SECONDS -lt 60 ] || { echo "No answer from the resolver after 60 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
  sleep 2
done
# 1: the full walk. Empty the resolver's cache first, so it must ask root, then the TLD server, then the authoritative server.
docker exec $N-resolver rndc flush
cap dns-1-recursion $ALL 8s; docker exec $N-client dig www.corp.internal; done_cap
# 2: the same question again: answered from the cache, nothing goes to the other servers.
cap dns-2-cached $ALL 8s; docker exec $N-client dig www.corp.internal; done_cap
# 3: a name that does not exist: the authoritative server says NXDOMAIN.
cap dns-3-nxdomain $ALL 8s; docker exec $N-client dig nothere.corp.internal; done_cap
# 4: a broken delegation: the server named for branch.internal. refuses, so the resolver answers SERVFAIL.
cap dns-4-servfail-lame $ALL 8s; docker exec $N-client dig www.branch.internal; done_cap
# 5: the authoritative server is down (paused): the resolver retries, then answers SERVFAIL after about 10 seconds.
# Start the recording first, then pause: the capture can take a while to start, and a paused node makes it slower.
cap dns-5-servfail-down $ALL 18s; docker pause $N-auth >/dev/null; docker exec $N-client dig +timeout=15 +tries=1 mail.corp.internal; done_cap
docker unpause $N-auth >/dev/null
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
