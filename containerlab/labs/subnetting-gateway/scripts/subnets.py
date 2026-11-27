#!/usr/bin/env python3
"""Subnet calculator for the lesson's address maths. Standard library only.
Usage:  python3 subnets.py 10.0.2.130/26            -> network, broadcast, usable range
        python3 subnets.py 10.0.2.130/26 10.0.2.190  -> also: is that address in the same subnet?
Run it on the VM:  python3 scripts/subnets.py 10.0.2.130/26 10.0.2.190
"""
import ipaddress, sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
iface = ipaddress.ip_interface(sys.argv[1])
net = iface.network
print(f"address        {iface.ip}")
print(f"prefix / mask  /{net.prefixlen}  {net.netmask}")
print(f"network        {net.network_address}")
print(f"broadcast      {net.broadcast_address}")
hosts = list(net.hosts())
if hosts:
    print(f"usable hosts   {hosts[0]} - {hosts[-1]}  ({len(hosts)})")
for other in sys.argv[2:]:
    ip = ipaddress.ip_address(other)
    print(f"{ip} is {'IN' if ip in net else 'NOT in'} {net}")
