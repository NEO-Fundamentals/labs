#!/bin/sh
# keepalived notify: commit or flush conntrackd's cache when this firewall
# becomes active, standby or faulted.
C=/neo/configs/fw1-conntrackd.conf
[ -f /neo/configs/$(hostname | sed 's/.*-//')-conntrackd.conf ] && C=/neo/configs/$(hostname | sed 's/.*-//')-conntrackd.conf
# hostname is clab-firewall-ha-vrrp-fw1; prefer explicit files:
if [ -f /etc/neo/conntrackd.conf ]; then
  C=/etc/neo/conntrackd.conf
fi
bin=/usr/sbin/conntrackd
[ -x "$bin" ] || exit 0
case "$1" in
  primary)
    $bin -C "$C" -c >/dev/null 2>&1 || true
    $bin -C "$C" -f >/dev/null 2>&1 || true
    $bin -C "$C" -R >/dev/null 2>&1 || true
    ;;
  backup|fault)
    $bin -C "$C" -n >/dev/null 2>&1 || true
    ;;
esac
exit 0
