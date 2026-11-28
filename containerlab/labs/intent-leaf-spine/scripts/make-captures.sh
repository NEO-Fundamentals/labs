#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. Intent v1 is deployed at the start of this script.
# Run it from the lab folder:  sudo bash scripts/make-captures.sh
cd "$(dirname "$0")/.." || exit 1
[ "$(id -u)" = 0 ] || { echo "Run it with sudo:  sudo bash scripts/make-captures.sh"; exit 1; }
L=intent-leaf-spine; N=clab-$L; mkdir -p captures; fails=0; LOG=/tmp/neo-$L-capture.log; : >"$LOG"
declare -A NEED_FILT NEED_MIN
need() { NEED_FILT[$1]=$2; NEED_MIN[$1]=$3; }
need ils-1-ecmp 'tcp.port == 80 or icmp' 2
need ils-2-drift 'tcp.port == 80 or icmp' 2
need ils-3-new-subnet 'tcp.port == 80 or icmp' 2

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
python3 scripts/fabric.py render configs/intent_v1.txt build >>"$LOG"
python3 scripts/fabric.py deploy build >>"$LOG"
ok=0
for i in $(seq 20); do
  docker exec $N-host-a curl -s -m 3 http://10.31.10.74/ | grep -q 'hello from host-b' && { ok=1; break; }
  sleep 1
done
[ $ok = 1 ] || { echo "host-a cannot reach host-b after deploying intent v1. Is the lab deployed?"; exit 1; }
# 1: healthy ECMP path, recorded on leaf-1's two spine links.
cap ils-1-ecmp leaf-1:to-spine-1,to-spine-2 8s; started
docker exec $N-host-a curl -s -m 3 http://10.31.10.74/ | grep -q 'hello from host-b' || { echo "      curl failed on the healthy path"; badf=1; }
done_cap
# 2: drift (one next hop), recorded on the same links: traffic still works.
bash scripts/fault.sh 1 >>"$LOG"
cap ils-2-drift leaf-1:to-spine-1,to-spine-2 8s; started
docker exec $N-host-a curl -s -m 3 http://10.31.10.74/ | grep -q 'hello from host-b' || { echo "      curl failed after the drift"; badf=1; }
done_cap
# Redeploy leaf-1, then deploy v2 and capture host-a to host-c.
python3 scripts/fabric.py deploy build leaf-1 >>"$LOG"
python3 scripts/fabric.py render configs/intent_v2.txt build2 >>"$LOG"
python3 scripts/fabric.py deploy build2 >>"$LOG"
ok=0
for i in $(seq 15); do
  docker exec $N-host-a curl -s -m 3 http://10.31.10.138/ | grep -q 'hello from host-c' && { ok=1; break; }
  sleep 1
done
[ $ok = 1 ] || { echo "      host-a cannot reach host-c after intent v2"; badf=1; }
cap ils-3-new-subnet leaf-1:to-spine-1,to-spine-2 8s; started
docker exec $N-host-a curl -s -m 3 http://10.31.10.138/ | grep -q 'hello from host-c' || { echo "      curl to host-c failed"; badf=1; }
done_cap
# Leave intent v1 deployed, no drift (as after the student finishes exercise 3's redeploy, before v2).
# Actually leave v2 in place? The script comment in other labs says left as after a deploy.
# Here deploy does not apply intent; students render it. Leave v1 deployed and clean.
python3 scripts/fabric.py deploy build >>"$LOG"
[ -n "$SUDO_UID" ] && chown "$SUDO_UID:$SUDO_GID" captures/*.pcapng
[ -n "$SUDO_UID" ] && chown -R "$SUDO_UID:$SUDO_GID" build build2 2>/dev/null || true
ls -l captures
[ $fails = 0 ] || { echo "$fails capture(s) FAILED"; exit 1; }
