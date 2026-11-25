#!/usr/bin/env bash
# NEO Fundamentals lab bootstrap for Ubuntu 24.04 LTS ("noble").
# Installs the free tools the NEO lab packs use, sets up packet-capture
# permissions, and installs the NEO_Diagnostics Wireshark profile.
#
# Run it ONLY inside a disposable virtual machine (or WSL2 distro) that you own.
#   sudo bash bootstrap-ubuntu-2404.sh            # tools only (good for a server VM)
#   sudo bash bootstrap-ubuntu-2404.sh --gui      # also installs the Wireshark desktop app
#
# Safe to run more than once. It changes nothing on your network: it only
# installs packages and writes files inside this VM.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WANT_GUI=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --gui)   WANT_GUI=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 2 ;;
  esac
done

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Run with sudo:  sudo bash $0 $*"

# Who will use the lab (the person who typed sudo)?
LAB_USER="${SUDO_USER:-}"
if [ -z "$LAB_USER" ] || [ "$LAB_USER" = "root" ]; then
  LAB_USER="$(logname 2>/dev/null || true)"
fi

say "Checking the operating system"
. /etc/os-release
echo "Found: ${PRETTY_NAME:-unknown}"
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  [ "$FORCE" -eq 1 ] || fail "This kit is tested on Ubuntu 24.04 LTS only. Use an Ubuntu 24.04 VM, or re-run with --force at your own risk."
  echo "WARNING: not Ubuntu 24.04; continuing because --force was given."
fi

HAS_SYSTEMD=0
[ -d /run/systemd/system ] && HAS_SYSTEMD=1

say "Pre-answering the Wireshark capture-permission question"
# 'true' lets members of the 'wireshark' group capture without running Wireshark as root.
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

say "Updating the package list"
apt-get update -q
POLICY="$(apt-cache policy tshark frr 2>/dev/null || true)"
if ! grep -q 'Candidate: [0-9]' <<<"$POLICY"; then
  fail "Ubuntu's 'universe' repository is not enabled. Run:  sudo add-apt-repository universe   then run this script again."
fi

# Every tool below is free and comes from Ubuntu's own archive.
PKGS=(
  # Core: namespaces, links, addressing, quick tests
  iproute2 iputils-ping traceroute netcat-openbsd curl bind9-dnsutils ethtool bridge-utils python3
  # Capture
  tcpdump tshark
  # Routing (OSPF, BGP, RIP, static, VRFs)
  frr frr-pythontools
  # Firewalls and NAT
  nftables conntrack
  # DNS and DHCP
  dnsmasq-base isc-dhcp-client
  # Switching: LACP and bonding labs
  openvswitch-switch
  # Remote access
  openssh-client openssh-server
  # VPN labs
  strongswan-swanctl charon-systemd wireguard-tools
  # Load-balancer, high-availability and monitoring stand-ins
  haproxy keepalived snmp snmpd
)
[ "$WANT_GUI" -eq 1 ] && PKGS+=(wireshark)

say "Installing ${#PKGS[@]} packages (this can take a few minutes)"
apt-get install -y -q --no-install-recommends "${PKGS[@]}"

# Make sure dumpcap really got the capture permission (re-runs the debconf step).
dpkg-reconfigure -f noninteractive wireshark-common >/dev/null 2>&1 || true

if [ "$HAS_SYSTEMD" -eq 1 ]; then
  say "Keeping lab-only services from running on the VM itself"
  # The labs start their own copies inside namespaces. These stay installed but idle.
  for svc in haproxy keepalived snmpd strongswan; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      systemctl disable --now "${svc}.service" >/dev/null 2>&1 || true
    fi
  done
  # Open vSwitch must stay running for the LACP / bonding labs.
  systemctl enable --now openvswitch-switch.service >/dev/null 2>&1 || true
else
  echo "No systemd found (normal in some WSL2 setups); services were left as installed."
fi

if [ -n "$LAB_USER" ] && id "$LAB_USER" >/dev/null 2>&1; then
  say "Letting '$LAB_USER' capture packets (wireshark group)"
  getent group wireshark >/dev/null || groupadd -r wireshark
  usermod -aG wireshark "$LAB_USER"

  say "Installing the NEO_Diagnostics Wireshark profile for '$LAB_USER'"
  HOME_DIR="$(getent passwd "$LAB_USER" | cut -d: -f6)"
  PROFILES="$HOME_DIR/.config/wireshark/profiles"
  if [ -d "$PROFILES/NEO_Diagnostics" ]; then
    echo "Profile already present; left unchanged."
  else
    sudo -u "$LAB_USER" mkdir -p "$PROFILES"
    python3 - "$KIT_DIR/wireshark/NEO_Diagnostics_profile.zip" "$PROFILES" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
    chown -R "$LAB_USER": "$HOME_DIR/.config/wireshark"
  fi
  sudo -u "$LAB_USER" mkdir -p "$HOME_DIR/neo-lab/captures"
else
  echo "Could not tell which user ran sudo; skipped the wireshark group and profile."
fi

say "Checking the tools"
missing=0
for cmd in ip ping traceroute nc curl dig tcpdump tshark dumpcap vtysh nft conntrack dnsmasq dhclient ovs-vsctl ssh sshd swanctl wg haproxy keepalived snmpwalk python3; do
  if command -v "$cmd" >/dev/null 2>&1 || [ -x "/usr/sbin/$cmd" ]; then
    printf '  ok       %s\n' "$cmd"
  else
    printf '  MISSING  %s\n' "$cmd"; missing=$((missing+1))
  fi
done
[ -x /usr/lib/frr/zebra ] && echo "  ok       FRR daemons (/usr/lib/frr)" || { echo "  MISSING  FRR daemons"; missing=$((missing+1)); }
printf '  tshark:  %s\n' "$(tshark --version 2>/dev/null | head -1)"
printf '  FRR:     %s\n' "$(dpkg-query -W -f='${Version}' frr 2>/dev/null || true)"

[ "$missing" -eq 0 ] || fail "$missing tool(s) missing. Re-run this script; if it still fails, check your internet connection inside the VM."

cat <<MSG

==> Bootstrap finished. All tools are installed.

Next:
  1. Log out and back in (or reboot the VM) so the wireshark group takes effect.
  2. Run the check lab:   sudo bash $KIT_DIR/scripts/verify-lab.sh
MSG
