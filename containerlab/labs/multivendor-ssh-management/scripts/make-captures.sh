#!/bin/bash
# Re-record this lab's sample captures from the admin-host cable. The lab must be deployed. If scripts/setup-keys.sh has not been run yet, this script runs it.
# Run from the lab folder:  sudo bash scripts/make-captures.sh   (about one minute)
# It uses its own known_hosts file on admin-host, so your own known_hosts is not changed. device gets its first host key back at the end.
cd "$(dirname "$0")/.." || exit 1
# It overwrites a sample in captures/ only when the new recording succeeds; a failed one prints FAIL and the old sample stays.
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
fails=0; LOG=/tmp/neo-$(basename "$PWD")-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need sshmgmt-1-unknown-host 'tcp.port == 22 or ssh or tcp' 1
need sshmgmt-2-login-ok 'tcp.port == 22 or ssh' 2
need sshmgmt-3-old-key 'tcp.port == 22 or ssh or tcp' 1
need sshmgmt-4-host-key-changed 'tcp.port == 22 or ssh or tcp' 1
need sshmgmt-5-refused 'tcp.port == 22 or tcp' 1
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
L=multivendor-ssh-management; N=clab-$L; IP=192.168.50.1; mkdir -p captures
KH=/root/.ssh/known_hosts_captures
S="ssh -o BatchMode=yes -o ConnectTimeout=5 -o UserKnownHostsFile=$KH"
if ! docker exec $N-admin-host test -f /root/.ssh/id_netops; then
  echo "No keys yet; running scripts/setup-keys.sh"
  bash scripts/setup-keys.sh || { echo "setup-keys.sh failed. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
fi
docker exec $N-admin-host rm -f $KH
cap() {  # cap <name> <seconds>: record in the background, then wait until the recording has actually started
  containerlab capture --name $L --target admin-host:eth1 --duration "$2" -w "captures/$1.pcapng.tmp" >>"$LOG" 2>&1 & cpid=$!; f="captures/$1.pcapng";
  wait_started
}
run() { echo "== $1"; docker exec $N-admin-host sh -c "$2" 2>&1 | tail -2; }
cap sshmgmt-1-unknown-host 6s;  run "unknown host key" "$S -i /root/.ssh/id_netops netops@$IP hostname"; done_cap
docker exec $N-admin-host sh -c "ssh-keyscan -t ed25519 $IP 2>/dev/null > $KH"
cap sshmgmt-2-login-ok 6s;      run "known host, right key" "$S -i /root/.ssh/id_netops netops@$IP hostname"; done_cap
cap sshmgmt-3-old-key 6s;       run "old key" "$S -i /root/.ssh/id_old netops@$IP hostname"; done_cap
bash scripts/device-sshd.sh rebuild >/dev/null
cap sshmgmt-4-host-key-changed 6s; run "rebuilt device" "$S -i /root/.ssh/id_netops netops@$IP hostname"; done_cap
bash scripts/device-sshd.sh restore >/dev/null; bash scripts/device-sshd.sh stop
cap sshmgmt-5-refused 6s;       run "sshd stopped" "$S -i /root/.ssh/id_netops netops@$IP hostname"; done_cap
bash scripts/device-sshd.sh start; docker exec $N-admin-host rm -f $KH
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
