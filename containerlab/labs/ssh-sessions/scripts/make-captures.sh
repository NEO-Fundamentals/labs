#!/bin/bash
# Re-record this lab's sample captures from host-a's cable. The lab must be deployed and
# If scripts/setup-keys.sh has not been run yet, this script runs it. Run from the lab folder:  sudo bash scripts/make-captures.sh   (about two minutes)
# It uses its own known_hosts file on host-a, so your own known_hosts is not changed. Every fault is put back.
cd "$(dirname "$0")/.." || exit 1
# It overwrites a sample in captures/ only when the new recording succeeds; a failed one prints FAIL and the old sample stays.
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
fails=0; LOG=/tmp/neo-$(basename "$PWD")-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ssh-1-ok 'tcp.port == 22 or ssh' 2
need ssh-2-refused 'tcp.port == 22 or tcp' 1
need ssh-3-timeout 'tcp.port == 22 or tcp' 1
need ssh-4-banner-timeout 'tcp.port == 22 or tcp' 1
need ssh-5-kex-mismatch 'tcp.port == 22 or ssh or tcp' 1
need ssh-6-hostkey-changed 'tcp.port == 22 or ssh or tcp' 1
need ssh-7-permission-denied 'tcp.port == 22 or ssh or tcp' 1
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
L=ssh-sessions; N=clab-$L; IP=172.16.100.20; mkdir -p captures
KH=/root/.ssh/known_hosts_captures
S="ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o UserKnownHostsFile=$KH"
docker exec $N-host-a rm -f $KH
# r1 (FRR) loads its addresses 10-20 s after deploy: wait until host-a can reach host-b
SECONDS=0   # the wait below ends after 90 seconds at most (it checks the clock, not a number of tries)
until docker exec $N-host-a ping -c 1 -W 1 $IP >/dev/null 2>&1; do
  [ $SECONDS -lt 90 ] || { echo "host-a cannot reach host-b after 90 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
  sleep 2
done
if ! docker exec $N-host-a test -f /root/.ssh/id_lab; then
  echo "No keys yet; running scripts/setup-keys.sh"
  bash scripts/setup-keys.sh || { echo "setup-keys.sh failed. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
fi
cap() {  # cap <name> <seconds>: record in the background, then wait until the recording has actually started
  containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & cpid=$!; f="captures/$1.pcapng";
  wait_started
}
run() { echo "== $1"; docker exec $N-host-a sh -c "$2" 2>&1 | tail -2; }
cap ssh-1-ok 8s;               run "works" "$S -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh refused on
cap ssh-2-refused 6s;          run "refused" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh refused off; bash scripts/faults.sh drop on
cap ssh-3-timeout 10s;         run "timed out" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh drop off; bash scripts/faults.sh banner on
cap ssh-4-banner-timeout 10s;  run "banner timeout" "$S -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh banner off
cap ssh-5-kex-mismatch 6s;     run "kex mismatch" "$S -o KexAlgorithms=diffie-hellman-group1-sha1 -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh hostkey on
cap ssh-6-hostkey-changed 6s;  run "host key changed" "$S -o StrictHostKeyChecking=yes -i /root/.ssh/id_lab labuser@$IP hostname"; done_cap
bash scripts/faults.sh hostkey off
cap ssh-7-permission-denied 6s; run "permission denied" "$S -i /root/.ssh/id_other labuser@$IP hostname"; done_cap
docker exec $N-host-a rm -f $KH
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
