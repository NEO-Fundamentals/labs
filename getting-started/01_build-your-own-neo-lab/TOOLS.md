# Tools used by the NEO lesson packs

All are free and installed by `scripts/bootstrap-ubuntu-2404.sh` from Ubuntu 24.04's own archive.

| Tool (Ubuntu package) | What it does in the labs | Lesson packs that use it |
|---|---|---|
| `ip`, `ip netns`, veth, Linux bridge, VRF devices (iproute2, bridge-utils) | Builds each device as a network namespace, cables them, addresses, routes, VRFs, kernel bridges and STP | Almost every lab: TCP, subnetting, VLANs, Spanning Tree, routing tables, VRFs, path trace, capstone, IP address space |
| `tcpdump`, `tshark`, `dumpcap` (tcpdump, tshark) | Captures and lists packets from the terminal | TCP basics and troubleshooting, Wireshark, DNS, BGP, firewall troubleshooting, wire data, DHCP, port channels, MLAG, OSI, RIP |
| Wireshark (wireshark, with `--gui`) | Opens the capture files | Every lesson with a capture |
| `nc`, `curl`, `ping`, `traceroute`, `dig` (netcat-openbsd, curl, iputils-ping, traceroute, bind9-dnsutils) | Test traffic and quick checks | Most labs |
| FRR: `zebra`, `staticd`, `ospfd`, `bgpd`, `ripd`, `vtysh` (frr, frr-pythontools) | Routing daemons | OSPF, BGP, VRFs, multi-vendor eBGP/addressing/route tables/OSPF/VRFs, IP address space, RIP |
| `nft`, `conntrack` (nftables, conntrack) | Stateful firewall, NAT, session table | Firewall fundamentals, policy rules, NAT, firewall HA and troubleshooting, multi-vendor firewalls, IP address space |
| `dnsmasq`, `dhclient` (dnsmasq-base, isc-dhcp-client) | DNS server; DHCP server and client | DNS, DHCP |
| Open vSwitch (openvswitch-switch) | LACP bundles and bonding | Port channels, switch stacking and MLAG |
| OpenSSH client and server (openssh-client, openssh-server) | SSH sessions and failure cases | SSH, multi-vendor SSH |
| strongSwan `swanctl`, WireGuard `wg` (strongswan-swanctl, charon-systemd, wireguard-tools) | IPsec and WireGuard tunnels | VPNs |
| HAProxy (haproxy) | Open-source stand-in for a load balancer's virtual server and pool | Load-balancer virtual servers and troubleshooting |
| keepalived (keepalived) | VRRP-style shared address | Firewall high availability |
| `snmpd`, `snmpwalk` (snmpd, snmp) | Polling stand-in for monitoring tools | Monitoring and alerting |
| Python 3 (python3) | Small helper scripts and test servers | Subnetting, tools-of-the-trade stand-ins |

Concept-only lessons (Panorama and logical routers, firewall policy workflow, and multi-vendor access and trunk ports) have no hands-on lab. Vendor syntax (Junos, EOS, PAN-OS) is shown as text in those lessons and is not installed here.
