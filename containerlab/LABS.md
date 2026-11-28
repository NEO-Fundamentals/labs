# NEO labs: index

Every lesson lab is its own folder under `labs/`. Open the folder in VS Code and everything for that lesson is inside it:

- `<lab>.clab.yml` - the lab itself (the file you right-click and **Deploy**)
- `<lab>.drawio` and `<lab>.png` - the prepared diagram
- `configs/` - startup configs for the routers and servers
- `captures/` - sample captures recorded from the lab, to open in Wireshark
- `scripts/` - helper scripts for the lab (for example `make-captures.sh`)
- `README.md` - the steps, checks, exercises, troubleshooting and cleanup for that lesson

Nothing lesson-specific lives anywhere else. The `tools/` folder is for lab authors (diagram and check tools); `tools/neo-tools` is the NEO helper image (a Debian image with an SSH server, firewall, load balancer and DHCP tools). It is built and published for you as `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and downloads by itself on Deploy. Twenty-four labs use it (`ssh-sessions`, `multivendor-ssh-management`, `dns-resolution`, `dhcp-dora-relay`, `private-public-nat`, `firewall-zones`, `firewall-policy-order`, `firewall-nat`, `firewall-troubleshooting`, `ngfw-inspection`, `vpn-ipsec-site-to-site`, `firewall-ha-vrrp`, `multivendor-firewall-zones`, `multivendor-firewall-policy`, `load-balancer-haproxy`, `load-balancer-troubleshooting`, `path-trace-routed`, `path-trace-access-port`, `troubleshooting-capstone`, `monitoring-snmp-polling`, `wire-data-sensor`, `config-map-runbook`, `cloud-managed-campus` and `intent-leaf-spine`). Two of those, `ngfw-inspection` and `firewall-ha-vrrp`, also need a local build of `neo-tools:1.1.0` (see the kit README and [tools/README.md](tools/README.md)).

Run **one lab at a time** (the virtual machine has 8 GB of memory). Deploy: Containerlab panel > **Undeployed Local Labs** > `labs` > the lab > right-click the `.clab.yml` > **Deploy**. Every lab README starts with **Before you start** and ends with **Troubleshooting** and **Cleanup**. If the right-click menu has no **Deploy**, VS Code has opened the kit in **Restricted Mode** (a badge at the bottom left): click the badge, then **Trust**, and check that the badge is gone (the kit README, step 2, and the beginner guide, Step 7.2).

| Lab folder | Lesson | What it does |
|---|---|---|
| [`labs/ebgp-two-sites/`](labs/ebgp-two-sites/README.md) | NEO-48 Build Your Own NEO Lab | Two sites joined by one eBGP session (SR Linux and FRR); the first lab you run and capture |
| [`labs/osi-http-capture/`](labs/osi-http-capture/README.md) | NEO-45 The OSI Model | A PC loads a web page by name through one router; capture it and find each layer, then break DNS and the web server |
| [`labs/tcp-basics/`](labs/tcp-basics/README.md) | NEO-01 TCP Basics | Open a TCP connection three ways (works, refused, silently dropped) and read the handshake, sequence numbers and retries |
| [`labs/bgp-ebgp-ibgp-path-choice/`](labs/bgp-ebgp-ibgp-path-choice/README.md) | NEO-11 BGP: What It Is, eBGP and iBGP, and Path Choice | SR Linux in AS 65201 peers with two FRR routers in AS 65202 (which also peer with each other); see why one path wins and change it |
| [`labs/multivendor-ebgp/`](labs/multivendor-ebgp/README.md) | NEO-32 Multi-vendor eBGP | The same eBGP session on SR Linux and FRR side by side, with Arista EOS and Juniper Junos shown as text |
| [`labs/tcp-troubleshooting/`](labs/tcp-troubleshooting/README.md) | NEO-02 TCP Troubleshooting | The client, router and server of the TCP lab with six faults you switch on and off (silent drop, refused, packet loss, zero window, MTU black hole, reset mid-session) and a port-exhaustion exercise |
| [`labs/wireshark-practice/`](labs/wireshark-practice/README.md) | NEO-03 Wireshark for troubleshooting | The same faults plus a small DNS server, with the diagnostic color profile and a table of which filter finds which fault |
| [`labs/subnetting-gateway/`](labs/subnetting-gateway/README.md) | NEO-05 IPv4 subnetting and CIDR | Three hosts and a router split into two /26 subnets on one switch; check same-subnet versus gateway delivery with `ip route get`, ARP and a capture |
| [`labs/multivendor-interfaces/`](labs/multivendor-interfaces/README.md) | NEO-34 Multi-vendor interface addressing and show commands | Two FRR routers on a /30: read address and state, break it with a wrong-subnet typo and a shutdown; Junos and EOS shown as text |
| [`labs/ssh-sessions/`](labs/ssh-sessions/README.md) | NEO-04 SSH: a secure session over TCP | An SSH client, an FRR router and an SSH server; make a login fail six ways (refused, timeout, banner timeout, no matching key exchange, host key changed, wrong key) and see which checkpoint stopped it |
| [`labs/routing-table-next-hop/`](labs/routing-table-next-hop/README.md) | NEO-09 Routing tables, longest-prefix match, ARP, and the next hop | Two hosts, an FRR router and an SR Linux router: read each table, follow the ARP and TTL hop by hop, and break one host with a wrong /32 route |
| [`labs/multivendor-ssh-management/`](labs/multivendor-ssh-management/README.md) | NEO-33 Multi-vendor SSH management | A management host with strict host-key checking and a device with sshd: unknown host, old key, changed host key and a stopped service; Junos and EOS shown as text |
| [`labs/multivendor-route-tables/`](labs/multivendor-route-tables/README.md) | NEO-37 Multi-vendor route tables | One FRR router with a /24, a more specific /25 and a default route: read the table, watch the longest match win, then take the /25 away; Junos and EOS shown as text |
| [`labs/dns-resolution/`](labs/dns-resolution/README.md) | NEO-06 DNS for network engineers | A client, a recursive resolver and its own root, TLD and authoritative servers (BIND): follow one lookup down the tree, see the cache answer, then NXDOMAIN and two kinds of SERVFAIL |
| [`labs/dhcp-dora-relay/`](labs/dhcp-dora-relay/README.md) | NEO-42 DHCP: how a host gets its address (DORA, leases and relay) | A DHCP server, a client on its own LAN and a client behind an SR Linux relay: watch DORA, renew and release a lease, and see what a client does when no server answers |
| [`labs/private-public-nat/`](labs/private-public-nat/README.md) | NEO-46 IP Address Space: Public, Private, and Reserved Ranges | Two private sites joined through a stand-in provider (FRR) that drops private source addresses: switch on source NAT, then a port forward, and read the translations |
| [`labs/rip-four-routers/`](labs/rip-four-routers/README.md) | NEO-47 RIP: Distance-Vector Routing, Hop Counts, and Why OSPF Replaced It | Four FRR routers running RIP: read hop counts and split horizon, then break one link silently (about 3 minutes to recover) and by unplugging it (seconds) |
| [`labs/ospf-single-area/`](labs/ospf-single-area/README.md) | NEO-10 OSPF in a Single Area | Two FRR routers and one SR Linux router in area 0: neighbours, the shared map, the shortest path, then a cost change, a failed link and a hello mismatch where ping works but OSPF does not |
| [`labs/vrf-two-tables/`](labs/vrf-two-tables/README.md) | NEO-12 VRFs: Separate Routing Tables on One Device | One SR Linux router with two VRFs and three hosts: see the isolation, leak a route one way (it fails) and both ways (it works) |
| [`labs/multivendor-ospf/`](labs/multivendor-ospf/README.md) | NEO-38 Multi-vendor OSPF adjacency | One FRR router and one SR Linux router as OSPF neighbours: compare the two views, then break it with a hello-timer mismatch and an MTU mismatch (stuck in ExStart) |
| [`labs/multivendor-vrf/`](labs/multivendor-vrf/README.md) | NEO-39 Multi-vendor VRFs | VRFs RED and BLUE on SR Linux and on FRR (Linux VRF devices) with the same addresses in both: name the VRF in every show and ping, then fix a route typed outside its VRF |
| [`labs/vlans-trunks/`](labs/vlans-trunks/README.md) | NEO-07 VLANs and 802.1Q trunks | Two SR Linux switches, two VLANs, four hosts in one subnet: see the tags on the trunk, then a native-VLAN mismatch and a VLAN missing from the trunk. On an 8 GB VM use `vlans-trunks-lite.clab.yml`. |
| [`labs/spanning-tree-triangle/`](labs/spanning-tree-triangle/README.md) | NEO-08 Spanning Tree | Three Linux-bridge switches in a triangle with kernel 802.1D STP: find the root and the blocked port, cut a link, see a loop without STP, elect a new root |
| [`labs/port-channel-lacp/`](labs/port-channel-lacp/README.md) | NEO-43 Port Channels: bundling links with LACP | Two SR Linux switches with a two-link LACP port channel: the bundle and its LACPDUs, a member pulled, LACP off at one end. On an 8 GB VM use `port-channel-lacp-lite.clab.yml`. |
| [`labs/mlag-dual-homing/`](labs/mlag-dual-homing/README.md) | NEO-44 Switch Stacking and MLAG | A host with one LACP bond to two SR Linux leaves (ESI-LAG over EVPN/VXLAN, SR Linux's answer to MLAG); not yet run end to end (see its README). On an 8 GB VM use `mlag-dual-homing-lite.clab.yml` (no ESI/EVPN/VXLAN in the lighter file). |
| [`labs/multivendor-access-trunk/`](labs/multivendor-access-trunk/README.md) | NEO-35 Multi-vendor access and trunk ports | One SR Linux switch and one Linux bridge with the same two VLANs and a trunk: read both dialects, see the tags, then a VLAN missing from one end and an access-versus-trunk mismatch; not yet run end to end (see its README) |
| [`labs/multivendor-stp-status/`](labs/multivendor-stp-status/README.md) | NEO-36 Multi-vendor RSTP and MSTP status | Two SR Linux switches (Rapid STP) and a Linux bridge (802.1D) in one tree: read the root and port roles in two formats, see 802.1D fallback, compare a slow and a fast recovery. On an 8 GB VM use `multivendor-stp-status-lite.clab.yml`. |
| [`labs/firewall-zones/`](labs/firewall-zones/README.md) | NEO-13 Firewall fundamentals | A Linux nftables firewall between inside, outside and dmz: default deny, a stateful zone policy, the session table, a packet trace and the stateless source-port mistake |
| [`labs/firewall-policy-order/`](labs/firewall-policy-order/README.md) | NEO-14 Security policy rules | Rule order and a shadowed rule, objects (named sets), a "temporary" any-any rule, a drop record and log lines at the cleanup rule, drop versus reject |
| [`labs/firewall-nat/`](labs/firewall-nat/README.md) | NEO-15 NAT on firewalls | Source NAT, a port forward, the translation in the session table, filter rules after NAT, the order in a trace, and hairpin NAT |
| [`labs/firewall-troubleshooting/`](labs/firewall-troubleshooting/README.md) | NEO-19 Firewall troubleshooting | Prove whether the firewall dropped it: both-side captures, counters, a drop record, a trace, log lines, the session table and the server's log; then faults beyond the firewall |
| [`labs/ngfw-inspection/`](labs/ngfw-inspection/README.md) | NEO-16 Next-generation firewall features | An inline sensor running Suricata: application identification, HTTP Host and TLS server name, a URL filter in IDS then IPS mode, a threat signature that HTTPS hides, checksum offload |
| [`labs/vpn-ipsec-site-to-site/`](labs/vpn-ipsec-site-to-site/README.md) | NEO-17 VPNs: IPsec site-to-site | Two strongSwan gateways and an FRR "Internet": the tunnel started by traffic, IKE then ESP on the wire, clear text inside, and an ESP proposal mismatch |
| [`labs/firewall-ha-vrrp/`](labs/firewall-ha-vrrp/README.md) | NEO-18 Firewall high availability | Two nftables firewalls with keepalived (VRRP) and conntrackd session sync: a failover test and its outage window, preemption, a session lost without session sync, loose TCP pickup, a session that survives with sync |
| [`labs/multivendor-firewall-zones/`](labs/multivendor-firewall-zones/README.md) | NEO-40 Multi-vendor firewalls: Junos SRX | Linux nftables laid out like a Junos SRX: security zones, zone-pair policies, an address book, host-inbound traffic, the flow session table; Junos syntax as text |
| [`labs/multivendor-firewall-policy/`](labs/multivendor-firewall-policy/README.md) | NEO-41 Multi-vendor firewalls: Palo Alto | Linux nftables laid out like PAN-OS: zones as interface groups, a named rulebase with hit counts, intrazone and interzone defaults, a policy-match trace, validate and commit; PAN-OS syntax as text |
| [`labs/load-balancer-haproxy/`](labs/load-balancer-haproxy/README.md) | NEO-22 F5 BIG-IP: virtual servers, pools, and SNAT | HAProxy standing in for a BIG-IP: virtual server and pool, round robin, full proxy and SNAT, a health monitor, ratio and disable, cookie persistence; tmsh syntax as text |
| [`labs/load-balancer-troubleshooting/`](labs/load-balancer-troubleshooting/README.md) | NEO-23 F5 troubleshooting: when the VIP is up and the application is down | The NEO-22 HAProxy load balancer with three faults: application down behind a live virtual server, a health check that passes while the page fails, a change with the wrong monitor; tmsh syntax as text |
| [`labs/path-trace-routed/`](labs/path-trace-routed/README.md) | NEO-24 Path trace: finding the entry point and walking the routed path | Host, FRR router, nftables firewall, FRR router, web server: the entry point, a hop-by-hop walk both ways, a missing return route and a firewall change that drops web traffic |
| [`labs/path-trace-access-port/`](labs/path-trace-access-port/README.md) | NEO-25 Path trace: ARP, MAC tables, and the access port | Gateway router, Linux switch (one bridge per VLAN), three hosts: IP to MAC to switch port, then a port in the wrong VLAN and a port shut down; Cisco-style commands as text |
| [`labs/troubleshooting-capstone/`](labs/troubleshooting-capstone/README.md) | NEO-26 Structured troubleshooting capstone | The path of NEO-24 and the access switch of NEO-25 in one topology; a fixed method on three faults (wrong VLAN, missing return route, firewall drop) |
| [`labs/monitoring-snmp-polling/`](labs/monitoring-snmp-polling/README.md) | NEO-27 Monitoring and alerting | A Linux poller and Net-SNMP on a Linux router: interface inventory, counters, an alert when a link goes down, a traffic threshold; a commercial NMS and SR Linux SNMP as text |
| [`labs/wire-data-sensor/`](labs/wire-data-sensor/README.md) | NEO-28 Wire data and network detection | A passive sensor on a Linux-bridge hub stand-in: inventory the hosts that talk, find an unknown host asking for /admin; a commercial wire-data tool and SPAN commands as text |
| [`labs/config-map-runbook/`](labs/config-map-runbook/README.md) | NEO-29 Network maps and runbooks from configs | Our own mapper and read-only runbook: links from stored configs, a planted missing return route, a live fix, then drift until the record is updated |
| [`labs/cloud-managed-campus/`](labs/cloud-managed-campus/README.md) | NEO-30 Cloud-managed campus networks | Our own stand-in controller and agents: claim serials, a template change, forwarding continues when the controller is cut off; plain HTTP |
| [`labs/intent-leaf-spine/`](labs/intent-leaf-spine/README.md) | NEO-31 Intent-based data-center fabrics | Our own intent-to-config tool on a two-spine, two-leaf Linux fabric (static ECMP): render, deploy, validate, drift, then a one-line intent change |


## Memory (virtual machine size)

Run one lab at a time. **8 GB** is the minimum if you use the lighter topology file (`<lab>-lite.clab.yml`) for every lab that would otherwise start two SR Linux switches (`vlans-trunks`, `port-channel-lacp`, `mlag-dual-homing`, `multivendor-stp-status`). **12 GB** is comfortable for the full two-SR-Linux labs. **16 GB** leaves headroom. On 8 GB, do not deploy those four full files; use the lighter file in the same folder. Labs that already use only Linux or one SR Linux node fit in 8 GB as they are.

## Lesson map

Find your lesson by its number, then open that folder.

| Lesson | Folder |
|---|---|
| NEO-01 | `labs/tcp-basics/` |
| NEO-02 | `labs/tcp-troubleshooting/` |
| NEO-03 | `labs/wireshark-practice/` |
| NEO-04 | `labs/ssh-sessions/` |
| NEO-05 | `labs/subnetting-gateway/` |
| NEO-06 | `labs/dns-resolution/` |
| NEO-07 | `labs/vlans-trunks/` |
| NEO-08 | `labs/spanning-tree-triangle/` |
| NEO-09 | `labs/routing-table-next-hop/` |
| NEO-10 | `labs/ospf-single-area/` |
| NEO-11 | `labs/bgp-ebgp-ibgp-path-choice/` |
| NEO-12 | `labs/vrf-two-tables/` |
| NEO-13 | `labs/firewall-zones/` |
| NEO-14 | `labs/firewall-policy-order/` |
| NEO-15 | `labs/firewall-nat/` |
| NEO-16 | `labs/ngfw-inspection/` |
| NEO-17 | `labs/vpn-ipsec-site-to-site/` |
| NEO-18 | `labs/firewall-ha-vrrp/` |
| NEO-19 | `labs/firewall-troubleshooting/` |
| NEO-22 | `labs/load-balancer-haproxy/` |
| NEO-23 | `labs/load-balancer-troubleshooting/` |
| NEO-24 | `labs/path-trace-routed/` |
| NEO-25 | `labs/path-trace-access-port/` |
| NEO-26 | `labs/troubleshooting-capstone/` |
| NEO-27 | `labs/monitoring-snmp-polling/` |
| NEO-28 | `labs/wire-data-sensor/` |
| NEO-29 | `labs/config-map-runbook/` |
| NEO-30 | `labs/cloud-managed-campus/` |
| NEO-31 | `labs/intent-leaf-spine/` |
| NEO-32 | `labs/multivendor-ebgp/` |
| NEO-33 | `labs/multivendor-ssh-management/` |
| NEO-34 | `labs/multivendor-interfaces/` |
| NEO-35 | `labs/multivendor-access-trunk/` |
| NEO-36 | `labs/multivendor-stp-status/` |
| NEO-37 | `labs/multivendor-route-tables/` |
| NEO-38 | `labs/multivendor-ospf/` |
| NEO-39 | `labs/multivendor-vrf/` |
| NEO-40 | `labs/multivendor-firewall-zones/` |
| NEO-41 | `labs/multivendor-firewall-policy/` |
| NEO-42 | `labs/dhcp-dora-relay/` |
| NEO-43 | `labs/port-channel-lacp/` |
| NEO-44 | `labs/mlag-dual-homing/` |
| NEO-45 | `labs/osi-http-capture/` |
| NEO-46 | `labs/private-public-nat/` |
| NEO-47 | `labs/rip-four-routers/` |
| NEO-48 | `labs/ebgp-two-sites/` |

More labs are added here as each lesson's lab is finished (one folder per lesson). Forty-six labs are in kit 1.3.1. Licences: see [LICENSES.md](LICENSES.md).
