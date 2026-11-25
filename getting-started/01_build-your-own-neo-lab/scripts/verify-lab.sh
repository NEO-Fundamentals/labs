#!/usr/bin/env bash
# NEO Fundamentals check lab: two hosts and one router in Linux network namespaces.
#
#   host A  10.0.2.10/24 --- 10.0.2.1  [ R1 ]  172.16.100.1 --- 172.16.100.20/24  host B
#           (a-eth0)        (r1-eth0)          (r1-eth1)         (b-eth0)
#
# It captures at host A while A pings B three times and opens one TCP
# connection to B on port 8080 (handshake, the word "hello", clean close),
# then checks the capture and saves it for Wireshark.
#
#   sudo bash verify-lab.sh              # build, test and capture; the lab stays up to explore
#   sudo bash verify-lab.sh --teardown   # remove the lab (a reboot also removes it)
#
# Private lab addresses only (RFC 1918). Nothing leaves the VM.
set -euo pipefail

NS=(neo-a neo-r1 neo-b)
KEEP=1; TEARDOWN_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;          # default; kept for older notes
    --teardown) TEARDOWN_ONLY=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 2 ;;
  esac
done

say()  { printf '==> %s\n' "$*"; }
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }
inns() { local n="$1"; shift; ip netns exec "$n" "$@"; }

[ "$(id -u)" -eq 0 ] || fail "Run with sudo:  sudo bash $0 $*"
for cmd in ip tcpdump tshark nc ping; do command -v "$cmd" >/dev/null || fail "'$cmd' not found. Run the bootstrap script first."; done

ns_exists() { [ -e "/run/netns/$1" ]; }
teardown() {
  for n in "${NS[@]}"; do ns_exists "$n" && ip netns del "$n"; done
  return 0
}

if [ "$TEARDOWN_ONLY" -eq 1 ]; then teardown; say "Lab removed."; exit 0; fi

for n in "${NS[@]}"; do
  ns_exists "$n" && fail "The lab from an earlier run is still up (namespace $n). Remove it with:  sudo bash $0 --teardown   (or reboot), then run this again."
done

LAB_USER="${SUDO_USER:-root}"
HOME_DIR="$(getent passwd "$LAB_USER" | cut -d: -f6)"
OUT_DIR="$HOME_DIR/neo-lab/captures"
mkdir -p "$OUT_DIR"
PCAP="$OUT_DIR/neo-verify-$(date +%Y%m%d-%H%M%S).pcap"
WORK="$(mktemp -d /tmp/neo-verify.XXXXXX)"

TCPDUMP_PID=""; NC_PID=""
cleanup() {
  [ -n "$NC_PID" ] && kill "$NC_PID" 2>/dev/null || true
  [ -n "$TCPDUMP_PID" ] && kill "$TCPDUMP_PID" 2>/dev/null || true
  # On failure, remove the half-built lab so the next run starts clean.
  if [ "$KEEP" -eq 0 ] || [ "${LAB_OK:-0}" -ne 1 ]; then teardown; fi
}
trap cleanup EXIT

say "1/6 Creating three devices: neo-a, neo-r1, neo-b"
for n in "${NS[@]}"; do
  ip netns add "$n"
  inns "$n" ip link set lo up
  # IPv4-only lab: keeps the capture to ARP, ICMP and TCP.
  inns "$n" sysctl -q -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1
done

say "2/6 Cabling them with two virtual Ethernet links"
ip link add a-eth0 type veth peer name r1-eth0
ip link add b-eth0 type veth peer name r1-eth1
ip link set a-eth0 netns neo-a
ip link set r1-eth0 netns neo-r1
ip link set r1-eth1 netns neo-r1
ip link set b-eth0 netns neo-b

say "3/6 Addresses, fictional MACs, routes, forwarding on R1 only"
inns neo-a  ip link set a-eth0  address 02:00:00:00:00:0a
inns neo-r1 ip link set r1-eth0 address 02:00:00:00:01:01
inns neo-r1 ip link set r1-eth1 address 02:00:00:00:01:02
inns neo-b  ip link set b-eth0  address 02:00:00:00:00:0b
inns neo-a  ip address add 10.0.2.10/24     dev a-eth0
inns neo-r1 ip address add 10.0.2.1/24      dev r1-eth0
inns neo-r1 ip address add 172.16.100.1/24  dev r1-eth1
inns neo-b  ip address add 172.16.100.20/24 dev b-eth0
inns neo-a  ip link set a-eth0 up
inns neo-r1 ip link set r1-eth0 up
inns neo-r1 ip link set r1-eth1 up
inns neo-b  ip link set b-eth0 up
inns neo-a  ip route add default via 10.0.2.1
inns neo-b  ip route add default via 172.16.100.1
inns neo-r1 sysctl -q -w net.ipv4.ip_forward=1

say "4/6 Starting the capture on host A (a-eth0)"
# Called directly (not through a function) so $! is tcpdump itself.
ip netns exec neo-a tcpdump -n -U -i a-eth0 -w "$WORK/cap.pcap" 2>"$WORK/tcpdump.log" &
TCPDUMP_PID=$!
for _ in $(seq 1 50); do grep -q "listening on" "$WORK/tcpdump.log" 2>/dev/null && break; sleep 0.1; done
grep -q "listening on" "$WORK/tcpdump.log" || fail "tcpdump did not start: $(cat "$WORK/tcpdump.log")"

say "5/6 Traffic: three pings, then one TCP connection to B port 8080"
inns neo-a ping -c 3 -i 0.3 -W 2 172.16.100.20 | tee "$WORK/ping.txt"
ip netns exec neo-b nc -l 8080 >"$WORK/received.txt" &
NC_PID=$!
for _ in $(seq 1 50); do L="$(inns neo-b ss -ltn 2>/dev/null || true)"; grep -q ':8080 ' <<<"$L" && break; sleep 0.1; done
printf 'hello\n' | inns neo-a nc -N -w 3 172.16.100.20 8080
wait "$NC_PID" 2>/dev/null || true; NC_PID=""
sleep 0.5
kill -TERM "$TCPDUMP_PID"; wait "$TCPDUMP_PID" 2>/dev/null || true; TCPDUMP_PID=""
cp "$WORK/cap.pcap" "$PCAP"
chown "$LAB_USER": "$PCAP" 2>/dev/null || true
chmod 0644 "$PCAP"

say "6/6 Checking the capture"
count() { tshark -n -r "$PCAP" -Y "$1" 2>/dev/null | wc -l; }
PASS=1
check() { # description, display filter, minimum count
  local c; c=$(count "$2")
  if [ "$c" -ge "$3" ]; then printf '  PASS  %-28s %s packet(s)\n' "$1" "$c"
  else printf '  FAIL  %-28s %s packet(s)   filter: %s\n' "$1" "$c" "$2"; PASS=0; fi
}
check "Echo requests A -> B"        "icmp.type == 8 && ip.dst == 172.16.100.20" 3
check "Echo replies B -> A"         "icmp.type == 0 && ip.src == 172.16.100.20" 3
check "SYN (A opens)"               "tcp.flags.syn == 1 && tcp.flags.ack == 0 && tcp.dstport == 8080" 1
check "SYN-ACK (B answers)"         "tcp.flags.syn == 1 && tcp.flags.ack == 1 && tcp.srcport == 8080" 1
check "ACK (handshake complete)"    "tcp.flags == 0x010 && tcp.dstport == 8080 && tcp.seq == 1 && tcp.ack == 1" 1
check "Data: hello"                 "tcp.payload && tcp.dstport == 8080" 1
check "FIN (clean close)"           "tcp.flags.fin == 1" 2
if [ "$(count 'tcp.flags.reset == 1')" -eq 0 ]; then echo "  PASS  No TCP resets"; else echo "  FAIL  a TCP reset was seen"; PASS=0; fi
grep -qx hello "$WORK/received.txt" && echo "  PASS  host B received: hello" || { echo "  FAIL  host B did not receive 'hello'"; PASS=0; }

echo
echo "Capture saved: $PCAP  ($(count 'frame') packets)"
echo "List it in the terminal with:  tshark -n -r $PCAP"
if [ "$PASS" -eq 1 ]; then
  LAB_OK=1
  echo "The lab is still up, so you can explore it. Try:  sudo ip netns exec neo-a ping -c 2 172.16.100.20"
  echo "Remove it when you are done:  sudo bash $0 --teardown   (a reboot also removes it)"
  echo; echo "RESULT: PASS. Your NEO lab works. Open the capture in Wireshark with the NEO_Diagnostics profile."
else
  fail "one or more checks failed, so the lab was removed. Re-run the bootstrap script, then this one."
fi
