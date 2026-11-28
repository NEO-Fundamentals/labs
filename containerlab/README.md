# NEO Fundamentals labs (Containerlab kit)

**Kit version:** 1.3.1  **Date:** 2026-11-27  **Status:** current

One download holds every lesson lab. Each video tells you which folder to open.
You run the labs from **VS Code** inside your Ubuntu 24.04 lab VM. New to this? Follow the beginner guide: **NEO-Containerlab-Beginner-Guide.pdf** (this folder). It goes step by step with screenshots, from an empty computer to a running lab.

**Beginner guide:** `NEO-Containerlab-Beginner-Guide.pdf` (this folder), guide version 1.3.5. Page 1 names kit 1.3.1 (the first-lab walkthrough was written for kit 1.2.3 and still applies). What you need matches the Memory section: 8 GB minimum with the lighter files, 12 GB comfortable, 16 GB headroom. 1.3.5 also adds Step 7.2 Restricted Mode case B and screenshot S-17a.

**All labs:** see [LABS.md](LABS.md) for the list with a one-line description of each, or the table below.

## Lesson index

| Lesson | Folder | What it builds | Images needed | Tested |
|---|---|---|---|---|
| NEO-48 Build Your Own NEO Lab | `labs/ebgp-two-sites/` | Two sites joined by eBGP: Nokia SR Linux (edge-a, AS 65201), FRR (edge-b, AS 65202), two Linux PCs | Free, downloaded automatically | Yes (Ubuntu 24.04, Containerlab 0.83.0, VS Code extension 0.28.0, Wireshark 4.2.2) |
| NEO-01 TCP Basics | `labs/tcp-basics/` | A client, an FRR router and a server: a TCP connection that works, one that is refused and one that is silently dropped | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-45 The OSI Model | `labs/osi-http-capture/` | A PC loads a web page by name through one router (DNS and HTTP); capture it and find each layer | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-11 BGP: What It Is, eBGP and iBGP, and Path Choice | `labs/bgp-ebgp-ibgp-path-choice/` | SR Linux (AS 65201) peers with two FRR routers (AS 65202) that also peer with each other; see why one path wins | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-32 Multi-vendor eBGP | `labs/multivendor-ebgp/` | The same eBGP session on SR Linux and FRR side by side (Arista EOS and Juniper Junos shown as text) | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-02 TCP Troubleshooting | `labs/tcp-troubleshooting/` | Six TCP faults you switch on and off: silent drop, refused, packet loss, zero window, MTU black hole, reset in the middle | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-03 Wireshark for troubleshooting | `labs/wireshark-practice/` | The same faults plus a DNS server, with a Wireshark color profile and a table of which filter finds which fault | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0); the color-profile import was not tested |
| NEO-05 IPv4 subnetting and CIDR | `labs/subnetting-gateway/` | Three hosts and an FRR router in two /26 subnets on one switch; same-subnet versus gateway delivery | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-34 Multi-vendor interface addressing and show commands | `labs/multivendor-interfaces/` | Two FRR routers on a /30: read address and state, then break it with a typo and a shutdown (Junos and EOS shown as text) | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-04 SSH: a secure session over TCP | `labs/ssh-sessions/` | An SSH client, an FRR router and an SSH server; six ways a login fails (refused, timeout, banner timeout, no matching key exchange, host key changed, wrong key) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-09 Routing tables, longest-prefix match, ARP, and the next hop | `labs/routing-table-next-hop/` | Two hosts, an FRR router and an SR Linux router; read the tables, follow the next hop, break one host with a wrong /32 route | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-33 Multi-vendor SSH management | `labs/multivendor-ssh-management/` | A management host with strict host-key checking and a device with sshd (Junos and EOS shown as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-37 Multi-vendor route tables | `labs/multivendor-route-tables/` | One FRR router with a /24, a more specific /25 and a default route (Junos and EOS shown as text) | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-06 DNS for network engineers | `labs/dns-resolution/` | A client, a recursive resolver and its own root, TLD and authoritative DNS servers (BIND 9.20); recursion, caching, NXDOMAIN and SERVFAIL | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-42 DHCP: how a host gets its address (DORA, leases and relay) | `labs/dhcp-dora-relay/` | A DHCP server (dnsmasq), two clients and an SR Linux DHCP relay; DORA, renew, release and no server | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-46 IP Address Space: Public, Private, and Reserved Ranges | `labs/private-public-nat/` | Two private sites, two Linux NAT routers (nftables) and an FRR stand-in provider; source NAT and a port forward | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-47 RIP: Distance-Vector Routing, Hop Counts, and Why OSPF Replaced It | `labs/rip-four-routers/` | Four FRR routers running RIP v2 and a bridge in one cable; hop counts, split horizon, a silent failure (about 3 minutes) and an unplugged cable (triggered update, metric 16) | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-10 OSPF in a Single Area | `labs/ospf-single-area/` | Two FRR routers and one SR Linux router in OSPF area 0; neighbours, the link-state database, a cost change, a failed link and a hello mismatch | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-12 VRFs: Separate Routing Tables on One Device | `labs/vrf-two-tables/` | One SR Linux router with two VRFs (network-instances alpha and beta) and three hosts; isolation, a one-way leak that fails, a two-way leak that works | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-38 Multi-vendor OSPF adjacency | `labs/multivendor-ospf/` | One FRR router and one SR Linux router become OSPF neighbours; a hello-timer mismatch and an MTU mismatch that sticks in ExStart (Junos and EOS shown as text) | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-39 Multi-vendor VRFs | `labs/multivendor-vrf/` | The same VRFs RED and BLUE on SR Linux (network-instances) and on FRR (Linux VRF devices), with repeated addresses kept apart; a route typed outside its VRF (Junos and EOS shown as text) | Free, downloaded automatically | Not yet on the VM (SR Linux half checked on a Linux test machine; the FRR half needs the VM's Linux VRF support) |
| NEO-07 VLANs and 802.1Q trunks | `labs/vlans-trunks/` | Two SR Linux switches, two VLANs and four hosts in one subnet; a trunk with a tagged VLAN and a native VLAN, a native-VLAN mismatch and a VLAN missing from the trunk | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-08 Spanning Tree | `labs/spanning-tree-triangle/` | Three Linux-bridge switches in a triangle with kernel 802.1D STP and three hosts; root election, a blocked port, a failed link, a 2-second loop without STP and a new root | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-43 Port Channels: bundling links with LACP | `labs/port-channel-lacp/` | Two SR Linux switches joined by a two-link LACP port channel (lag1) and two hosts; the bundle, LACPDUs, a member pulled, and LACP off at one end | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-44 Switch Stacking and MLAG | `labs/mlag-dual-homing/` | One host with a Linux LACP bond to two SR Linux leaves running ESI-LAG (EVPN multihoming, SR Linux's answer to MLAG) over VXLAN, and two single-homed hosts | Free, downloaded automatically | Not yet on the VM (configuration accepted by SR Linux on a Linux test machine; that machine cannot run the host bond or VXLAN, so the first full run is on the VM) |
| NEO-35 Multi-vendor access and trunk ports | `labs/multivendor-access-trunk/` | The same two VLANs on an SR Linux switch and on a Linux bridge with VLAN filtering, joined by an 802.1Q trunk, four hosts in one subnet; a VLAN missing from one end of the trunk, and one end access while the other is a trunk | Free, downloaded automatically | Not yet on the VM (SR Linux half checked on a Linux test machine; the Linux bridge needs the VM's VLAN filtering, so the first full run is on the VM) |
| NEO-36 Multi-vendor RSTP and MSTP status | `labs/multivendor-stp-status/` | Two SR Linux switches running Rapid STP and one Linux bridge running 802.1D in one tree; the same root and ports read in two status formats, 802.1D fallback, a slow 802.1D recovery and an instant Rapid STP alternate port (MSTP as text) | Free, downloaded automatically | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-13 Firewall fundamentals | `labs/firewall-zones/` | A Linux nftables firewall with connection tracking between inside, outside and dmz hosts; no firewall, default deny, a stateful zone policy, the session table, a packet trace and the stateless source-port mistake | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-14 Security policy rules | `labs/firewall-policy-order/` | The firewall-zones layout with a policy built from an object (a named set): a shadowed rule, rule order, adding a member to the object, a "temporary" any-any rule found and deleted by its handle, a drop record and log lines at the cleanup rule, and drop versus reject | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-15 NAT on firewalls | `labs/firewall-nat/` | A Linux nftables firewall doing source NAT and a port forward, with an outside server that has no route back: the translation in the session table, the filter rule that must use the real address after NAT, the order in a trace, and hairpin NAT for an inside client | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-19 Firewall troubleshooting | `labs/firewall-troubleshooting/` | Prove whether the firewall dropped it: captures on both sides, rule counters, a drop record, a packet trace, log lines, the session table and the server's own log; then a change, and two faults that are not the firewall (nothing listening, a host firewall) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-16 Next-generation firewall features | `labs/ngfw-inspection/` | An inline sensor with no IP address between a client and a server, running Suricata in AF_PACKET IPS mode: application identification, the HTTP Host and TLS server name, a URL filter in IDS then IPS mode, a threat signature that HTTPS hides, and the checksum-offload problem of inline sensors (no TLS decryption) | Free images, plus a local build of `neo-tools:1.1.0` from `tools/neo-tools` (not on the public registry yet) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-17 VPNs: IPsec site-to-site | `labs/vpn-ipsec-site-to-site/` | Two sites joined by an IKEv2/IPsec tunnel between two strongSwan gateways across an FRR router that plays the Internet: no route without the tunnel, the tunnel started by traffic, IKE then ESP on the wire and clear text inside, and an ESP proposal mismatch found in the logs (remote access and WireGuard as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-18 Firewall high availability | `labs/firewall-ha-vrrp/` | An active/passive pair of Linux nftables firewalls sharing gateway addresses with keepalived (VRRP) and conntrackd session sync over a dedicated HA link: advertisements, a failover test and its outage window, preemption, a session that dies without session sync, loose TCP pickup, and a session that survives with sync | Free images, plus a local build of `neo-tools:1.1.0` from `tools/neo-tools` (not on the public registry yet) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0; exercise 6 needs `nf_conntrack_netlink`) |
| NEO-40 Multi-vendor firewalls: Junos SRX | `labs/multivendor-firewall-zones/` | A Linux nftables firewall laid out the way a Junos SRX builds its policy: security zones, one policy list per zone pair, an address book, host-inbound traffic per zone and the flow session table; a new zone pair added (Junos syntax compared as text, no Junos image) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-41 Multi-vendor firewalls: Palo Alto | `labs/multivendor-firewall-policy/` | A Linux nftables firewall laid out the way PAN-OS builds its policy: zones as groups of interfaces, a named rulebase with hit counts, the intrazone and interzone default rules, a policy-match test by packet trace, and a change validated and committed as a whole (PAN-OS syntax compared as text, no PAN-OS image) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-22 F5 BIG-IP: virtual servers, pools, and SNAT | `labs/load-balancer-haproxy/` | HAProxy (a free load balancer standing in for a BIG-IP) in front of three web servers: a virtual server and its pool, round robin, a full proxy with SNAT and X-Forwarded-For, a health monitor taking a member down, ratio and disable at run time, and cookie persistence (BIG-IP tmsh syntax compared as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-23 F5 troubleshooting: when the VIP is up and the application is down | `labs/load-balancer-troubleshooting/` | The NEO-22 load balancer (HAProxy, standing in for a BIG-IP) with three faults to find from the outside in: the application down behind a virtual server that still answers, a member whose health check passes while its page fails (and a better monitor), and a change with the wrong monitor page (BIG-IP tmsh commands compared as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-24 Path trace: finding the entry point and walking the routed path | `labs/path-trace-routed/` | Five boxes in a line (host, FRR router, Linux nftables firewall, FRR router, web server): the entry point, a hop-by-hop walk both ways with traceroute and the routing tables, then a missing return route and a firewall change that drops web traffic | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-25 Path trace: ARP, MAC tables, and the access port | `labs/path-trace-access-port/` | A gateway router, a Linux switch with one bridge per VLAN and three hosts: from IP address to MAC address (ARP table) to switch port (MAC address table), then a port in the wrong VLAN and a port that was shut down (Cisco-style commands compared as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-26 Structured troubleshooting capstone | `labs/troubleshooting-capstone/` | The routed path of NEO-24 and the access-port switch of NEO-25 in one topology: a fixed method (state the problem, Layer 2, the path both ways, then the service) practised on a port in the wrong VLAN, a missing return route, and a firewall change that drops web traffic | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-27 Monitoring and alerting | `labs/monitoring-snmp-polling/` | A Linux poller asks a Linux router for interface counters and status over SNMPv2c (Net-SNMP), then raises an alert when a link goes down or when traffic in one interval crosses a threshold (not a commercial NMS; a commercial NMS and SR Linux SNMP commands as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-28 Wire data and network detection | `labs/wire-data-sensor/` | A passive sensor on a Linux bridge with MAC learning turned off (a hub / SPAN stand-in) inventories the hosts that talk and finds an unknown host asking for /admin (not a commercial wire-data product; SPAN and commercial wire-data commands as text) | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-29 Network maps and runbooks from configs | `labs/config-map-runbook/` | Our own config mapper and a read-only runbook on four Linux routers: map links from stored configs, a planted missing return route, a live fix, then drift until the stored file is updated | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-30 Cloud-managed campus networks | `labs/cloud-managed-campus/` | Our own stand-in cloud controller and device agents: claim serials, push a template, forwarding continues when the controller is cut off; plain HTTP, not TLS | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |
| NEO-31 Intent-based data-center fabrics | `labs/intent-leaf-spine/` | Our own intent-to-config tool on a two-spine, two-leaf Linux fabric (static ECMP, no FRR and no SR Linux): render, deploy, validate, drift, then one intent line becomes four device changes | Free, downloaded automatically (includes the NEO helper image `neo-tools`) | Not yet on the VM (checked on a Linux test machine, Containerlab 0.83.0) |

More lessons are added as new folders under `labs/`. [LABS.md](LABS.md) and the CHANGELOG below list every change. Each lab's README has **Before you start**, **Troubleshooting** and **Cleanup** sections.

## How to start a lesson (short version)

Type or paste commands **one line at a time**. If the terminal shows `>` and waits, press **Ctrl+C** and paste the single line again.

0. **Get the files:** on github.com/NEO-Fundamentals/labs click the green **Code** button > **Download ZIP** (not the older Getting Started ZIP linked lower on the front page). Extract `labs-main.zip` to your Home folder. This folder is then `~/labs-main/containerlab`.
1. **Check Docker first** (after the setup and one log out / log in). This must work without `sudo`; a header line with no rows is a pass:
   ```
   docker ps
   ```
2. In VS Code, open the kit folder (**File > Open Folder** > `labs-main` > `containerlab`). If `labs-main` holds another `labs-main`, go into that one: open the `containerlab` folder from the `labs-main` that directly contains it (and use `~/labs-main/labs-main/` in typed commands). Right after **Open**, VS Code asks whether you trust the authors: tick **Trust the authors of all files in the parent folder 'labs-main'** (never your Home folder) and click **Yes, I trust the authors**. Then check the bottom-left corner: the **Restricted Mode** badge must be gone. If it is still there, click it and click **Trust**. In Restricted Mode the Containerlab extension is off and the right-click menu has no **Deploy**.
3. Click the **Containerlab** icon on the left. Your lesson's `.clab.yml` file is under **Undeployed Local Labs** (for NEO-48: `labs/ebgp-two-sites/ebgp-two-sites.clab.yml`).
4. Right-click it > **Deploy**. The first deploy downloads the router images (about 3 GB) from the internet and can take 5 to 15 minutes. After that, lab traffic stays on the virtual links inside the VM. **Then wait about a minute** before you ping: green dots don't mean BGP is up yet. Checkpoint (in Ubuntu's Terminal): the line below must show `1` under State/PfxRcd for neighbor 10.0.12.1.
   ```
   docker exec clab-ebgp-two-sites-edge-b vtysh -c "show bgp summary"
   ```
5. Log in to a device: right-click it under **Running Labs** > **Access** > **Attach Shell**. (edge-a appears twice; the second one is an internal SR Linux helper, so ignore it.)
6. **After you edit a config file**, restart the lab with a clean redeploy in VS Code's terminal (**Terminal > New Terminal**), one line at a time:
   ```
   cd ~/labs-main/containerlab/labs/<lesson-folder>
   ```
   ```
   containerlab redeploy -c -t <lab-file>.clab.yml
   ```
   `-c` throws away the routers' saved configs so your edit is used. Don't use **Redeploy (Cleanup)** from the right-click menu; in our tests it closed VS Code.
7. **After a VM restart** (Ubuntu shows the login screen first), check that every device has a green dot before anything else. edge-b (FRR) is always the one left stopped. Run `containerlab redeploy -t <lab-file>.clab.yml` (no `-c`) in the lab folder; that keeps the saved configs. It prints two long red `ERRO container ... edge-b exited` blocks first. That's expected; it still succeeds. Wait about a minute for BGP, then re-check.
8. **Stop:** right-click the running lab > **Destroy**. Plain **Destroy** leaves the folder Containerlab generated for the lab (`clab-<lab-name>`, owned by root); **Destroy (Cleanup)** removes it. Your lab files and your capture files in Home stay either way.

**Wireshark capture (main method): record to a file, then open it.** In Ubuntu's Terminal app (not VS Code), for example:
```
sudo containerlab capture --name ebgp-two-sites --target edge-b:eth1 --duration 45s -w - > "$HOME/neo-wan-test.pcapng"
```
The terminal stays quiet for 45 seconds; that's normal. While it runs, ping from a second Terminal window. Then open Wireshark, **File > Open...** > Home > `neo-wan-test.pcapng`, and filter on `icmp`: the file holds about 14 frames (ARP, BGP keepalives, LLDP and IPv6 router solicitation too), and the filter shows exactly the 6 pings. Use a new file name each time, and keep captures in Home, never inside the generated `clab-*` folder. You need the `wireshark` group (`sudo usermod -aG wireshark $USER`, then log out and back in).
Optional shortcut: right-click an interface under a running device > **Capture With Wireshark**. On some systems the Wireshark window crashes at once (a GLib "antialiasing" error); if so, use the file method.

Diagram: `containerlab graph --drawio -t <lab-file>.clab.yml`, then `sudo chown $USER:$USER <lab-file>.clab.drawio`, then click the `.drawio` file to edit it in Draw.io Integration.


## Memory (virtual machine size)

Run one lab at a time.

- **8 GB** is the minimum, if you use the lighter topology file for every lab that would otherwise start two SR Linux switches. Those lighter files are named `<lab>-lite.clab.yml` in the lab folder (`vlans-trunks`, `port-channel-lacp`, `mlag-dual-homing`, `multivendor-stp-status`). Each one keeps a single SR Linux node (about 2 GB) and uses Linux for the other switch. Labs that already use only Linux or one SR Linux node fit in 8 GB as they are (`spanning-tree-triangle` is about 17 MB and has no SR Linux).
- **12 GB** is comfortable for the full two-SR-Linux labs (about 4 GB for the two switches) plus a desktop.
- **16 GB** leaves headroom if you want more than one heavy lab, or other programs, running at the same time.

On 8 GB, do not deploy the full `vlans-trunks`, `port-channel-lacp`, `mlag-dual-homing` or `multivendor-stp-status` files: two SR Linux switches left an 8 GB VM unresponsive. Use the `*-lite.clab.yml` file in that folder instead.

## Getting the latest labs

New labs are added over time. Compare the **Kit version** line at the top of this file with the one in the `containerlab` folder on GitHub (github.com/NEO-Fundamentals/labs). If GitHub's is newer:
- **Beginners:** rename your old `labs-main` folder if you want to keep your edits, then on the repository page click **Code > Download ZIP** and unzip `labs-main.zip` to your Home folder.
- **git users:** run `git pull` inside your clone.

## Rules for this kit

- Lab addresses are private only: IPv4 from RFC 1918 (such as 10.x and 192.168.x), management IPv6 from the private ULA range fd00::/8 (the lab uses fd00:172:20:20::/64), and AS numbers from the private ranges 64512-65534 and 4200000000-4294967294. The documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, 2001:db8::/32, 3fff::/20) are never used.
- No vendor software is stored here. Every lab uses only free public images (Nokia SR Linux, FRR, network-multitool, the ISC BIND 9 DNS server image and the NEO helper image neo-tools), which download from the vendors' public registries the first time you deploy. No vendor account is needed. Two labs (`ngfw-inspection` and `firewall-ha-vrrp`) also need `neo-tools:1.1.0`, which is built from `tools/neo-tools` and is not on the public registry yet (see [tools/README.md](tools/README.md)).
- Arista EOS and Juniper Junos are compared on screen in the videos only. This kit has no labs for them.

## Licences

The code in this folder (the `neo-tools` image, every script and tool, and the lab, config and change files) is under the **MIT** licence ([LICENSE-MIT](LICENSE-MIT)). The guide, the lessons, the READMEs, the diagrams and the sample captures are under **CC BY 4.0**. [LICENSES.md](LICENSES.md) lists which is which. The images the labs download come under their owners' own licences.

## CHANGELOG

### 1.3.1 (2026-11-27)

- Memory: this README and [LABS.md](LABS.md) now say how large a virtual machine you need (8 GB minimum with the lighter files, 12 GB comfortable, 16 GB headroom). Run one lab at a time.
- Lighter topologies (`<lab>-lite.clab.yml`) for the four labs that start two SR Linux switches: `vlans-trunks`, `port-channel-lacp`, `mlag-dual-homing` and `multivendor-stp-status`. The full file stays the default. Each lab README has an "If your VM has 8 GB" note. `spanning-tree-triangle` is already Linux-only and needs no lighter file. `tools/neo_lint.py` accepts a `<lab>-lite.clab.yml` file that keeps `name: <lab>`.
- Capture scripts wait until a recording has actually started and check that the file holds the expected frames. Connection-tracking labs try `conntrack -L` first and fall back to `/proc/net/nf_conntrack`. The DHCP relay lesson uses the address the client actually received. A few p3 configs that had dropped from later overlays are restored (`ssh-sessions`, `multivendor-ssh-management`, `routing-table-next-hop`, `multivendor-route-tables`).
- Beginner guide 1.3.5 (`NEO-Containerlab-Beginner-Guide.pdf`): page 1 names kit 1.3.1, and What you need matches the Memory section (8 GB minimum with the lighter files, 12 GB comfortable, 16 GB headroom). Step 7.2 Restricted Mode (case B) and screenshot S-17a are unchanged. Letter, tagged; built with the same pipeline as 1.3.4. The previous 1.3.4 PDF was moved out of this kit folder to the repository `superseded/` directory (`NEO-Containerlab-Beginner-Guide_1.3.4_SUPERSEDED_1801.pdf`).
- Recheck of kit 1.3.1: `make-captures.sh` in `vlans-trunks`, `port-channel-lacp` and `mlag-dual-homing` leaves the sample captures unchanged on the lighter topology (same early exit as `multivendor-stp-status`). [LABS.md](LABS.md) now lists the twenty-four labs that use `neo-tools` and points at 1.1.0 for `ngfw-inspection` and `firewall-ha-vrrp`. `tools/neo-tools/smoke-test.sh` requires `suricata` and `conntrackd` only when the image tag is 1.1.0 (the default stays 1.0.0). The capture scripts in `intent-leaf-spine`, `cloud-managed-campus` and `config-map-runbook` use the same start and frame checks as the other labs.

### 1.3.0 (2026-11-27)
- License wording: the nine labs that the 2026-11-27 LICENSE-CHECK listed as "needs change" (NEO-22, 23, 27, 28, 29, 30, 31, 40 and 41) now carry the exact trademark / non-affiliation lines, and the "-class" queue labels have been dropped from titles, the lesson index, [LABS.md](LABS.md), comments and reference text. On the kit side those nine labs are treated as public. The plan file was not edited; NEO-20 and NEO-21 stay text-only and PRIVATE ONLY, and are not in this kit.
- [LICENSES.md](LICENSES.md) now names HAProxy, Net-SNMP, Suricata and conntrackd as Debian packages inside `neo-tools`, not part of the MIT grant.
- Helper image `neo-tools:1.1.0` adds Suricata (from Debian bookworm-backports) and conntrackd (from bookworm). Everything else is the same as 1.0.0. It was built locally (about 298 MB; Debian 12.15; image id in [tools/README.md](tools/README.md)). It is not on the public registry; build it from `tools/neo-tools` or load a saved image before deploying the two labs that need it. Labs that do not need 1.1.0 stay on `neo-tools:1.0.0`.
- `ngfw-inspection` (NEO-16) now runs real Suricata in AF_PACKET IPS mode (the ids node uses 1.1.0; the client and server stay on 1.0.0). The small `/etc/neo/inspect.rules` policy language is unchanged. Walked and recaptured on a Linux test machine (about 90 MB).
- `firewall-ha-vrrp` (NEO-18) adds conntrackd session sync over a dedicated HA link (eth3, 10.18.3.0/24) and keepalived notify hooks. Exercises 4 (sync stopped, the session dies), 5 (loose TCP pickup) and 6 (sync running, the session survives) are in the README. The firewalls use 1.1.0; the hosts stay on 1.0.0. Exercises 1 to 5 ran on a Linux test machine (about 60 MB). Exercise 6 and sample `ha-4` could not: that machine's kernel has no `nf_conntrack_netlink` (`CONFIG_NF_CT_NETLINK` is not set). The NEO lab VM (Ubuntu 24.04) should have that module; `make-captures.sh` records ha-4 when both daemons stay up, and skips it with a clear message when they do not.

### 1.2.13 (2026-11-27)
- Three more labs, the last in the current plan that needed a lab: `config-map-runbook` (NEO-29), `cloud-managed-campus` (NEO-30) and `intent-leaf-spine` (NEO-31). Each is a self-contained folder with the lab file, diagram, configs, a README, `scripts/fault.sh` and `scripts/make-captures.sh`. All three use only the `neo-tools` image: no SR Linux and no FRR. The largest needs about 65 MB. Each ships our own small Python tool (a mapper and runbook, a stand-in cloud controller and agents, an intent-to-config fabric tool) and says it is not a vendor product.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- `tools/README.md`: the list of labs that use the `neo-tools` image now names all twenty-four.
- [LABS.md](LABS.md) and the lesson index list forty-six labs.

### 1.2.12 (2026-11-27)
- Three more labs: `troubleshooting-capstone` (NEO-26), `monitoring-snmp-polling` (NEO-27) and `wire-data-sensor` (NEO-28). Each is a self-contained folder with the lab file, diagram, configs, a README, `scripts/fault.sh` (puts each exercise's fault in place) and `scripts/make-captures.sh`. All three use only the `neo-tools` image: no SR Linux and no FRR. The largest needs about 35 MB.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- `troubleshooting-capstone` joins the topologies of NEO-24 and NEO-25 with Linux routers (the method is the same as in those labs). `monitoring-snmp-polling` runs Net-SNMP, not a commercial NMS, and says so at the top. `wire-data-sensor` uses a Linux bridge with MAC learning turned off as a hub / SPAN stand-in, and says so.
- `tools/README.md`: the list of labs that use the `neo-tools` image now names all twenty-one.
- [LABS.md](LABS.md) and the lesson index list forty-three labs.

### 1.2.11 (2026-11-27)
- Three more labs: `load-balancer-troubleshooting` (NEO-23), `path-trace-routed` (NEO-24) and `path-trace-access-port` (NEO-25). Each is a self-contained folder with the lab file, diagram, configs, a README, `scripts/fault.sh` (puts each exercise's fault in place) and `scripts/make-captures.sh`. All three use the `neo-tools` image; `load-balancer-troubleshooting` also uses `network-multitool` for its server switch, and `path-trace-routed` uses FRR for its two routers. None uses SR Linux; the largest needs about 180 MB.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- `load-balancer-troubleshooting` runs HAProxy, not an F5 BIG-IP, and says so at the top. `path-trace-access-port` uses one Linux bridge per VLAN (no 802.1Q trunk) and says so.
- `ngfw-inspection` (NEO-16): the server now waits for its SSH host keys before it starts the SSH server on port 8443 (one line added to the lab file, as in the other labs that run an SSH server). Nothing else in that lab changed.
- `tools/README.md`: the list of labs that use the `neo-tools` image now names all eighteen.
- [LABS.md](LABS.md) and the lesson index list forty labs.

### 1.2.10 (2026-11-27)
- Three more labs: `multivendor-firewall-zones` (NEO-40), `multivendor-firewall-policy` (NEO-41) and `load-balancer-haproxy` (NEO-22). Each is a self-contained folder with the lab file, diagram, configs, a README and `scripts/make-captures.sh`. All three use the `neo-tools` image; `load-balancer-haproxy` also uses `network-multitool` for its server switch.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- The two multi-vendor firewall labs run Linux nftables laid out the way a Junos SRX and PAN-OS build their policies; the vendor commands are in a text file in each lab, to compare. `load-balancer-haproxy` runs HAProxy, not an F5 BIG-IP, and says so at the top.
- `tools/README.md`: the list of labs that use the `neo-tools` image now names all fifteen.
- [LABS.md](LABS.md) and the lesson index list thirty-seven labs.

### 1.2.9 (2026-11-27)
- Three more labs: `ngfw-inspection` (NEO-16), `vpn-ipsec-site-to-site` (NEO-17) and `firewall-ha-vrrp` (NEO-18). Each is a self-contained folder with the lab file, diagram, configs, a README and `scripts/make-captures.sh`. All three use the `neo-tools` image; `vpn-ipsec-site-to-site` also uses FRR and `firewall-ha-vrrp` uses `network-multitool` for its two switches.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- `ngfw-inspection` does not use Suricata: Suricata is not in the `neo-tools` image 1.0.0. Its sensor runs `inspect.py`, a small inspection engine written for the lab, and the README says so at the top. `firewall-ha-vrrp` has no session sync (`conntrackd` is not in the image either); it shows what a failover does to sessions without it.
- `firewall-nat` README: "second window" and "first window" are "second terminal" and "first terminal" again (seven places), as in the other labs.
- `tools/README.md`: the list of labs that use the `neo-tools` image had not been updated since kit 1.2.6; it now names all twelve.
- [LABS.md](LABS.md) and the lesson index list thirty-four labs.

### 1.2.8 (2026-11-27)
- Three more labs: `firewall-policy-order` (NEO-14), `firewall-nat` (NEO-15) and `firewall-troubleshooting` (NEO-19). Each is a self-contained folder with the lab file, diagram, configs and change files, a README and `scripts/make-captures.sh`. All three use the `neo-tools` image (nftables and connection tracking); `firewall-nat` also uses `network-multitool` for its inside switch.
- All three were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM.
- `firewall-policy-order` and `firewall-troubleshooting` show the firewall's kernel log lines in an optional step. Linux hides those lines from containers unless the VM setting `net.netfilter.nf_log_all_netns` is 1; the READMEs switch it on for the step and back off after it. Everything else works without it.
- [LABS.md](LABS.md) and the lesson index list thirty-one labs.

### 1.2.7 (2026-11-27)
- Three more labs: `multivendor-access-trunk` (NEO-35), `multivendor-stp-status` (NEO-36) and `firewall-zones` (NEO-13). Each is a self-contained folder with the lab file, diagram, configs or change files, a README and `scripts/make-captures.sh`. `firewall-zones` uses the `neo-tools` image (nftables and connection tracking); the other two do not.
- `multivendor-stp-status` and `firewall-zones` were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM. In `multivendor-stp-status` SR Linux runs Rapid STP and the Linux bridge classic 802.1D; MSTP is shown as text only.
- `multivendor-access-trunk` could only be checked in part: the SR Linux half ran (both VLANs tagged on the trunk), but the test machine's kernel has no bridge VLAN filtering, so the Linux bridge could not be built there and the lab has no sample captures yet. Its README says so at the top; the first full run, and the captures, are on the VM. NEO-35 had no hands-on lab before; it now has one.
- [LABS.md](LABS.md) and the lesson index list twenty-eight labs. LABS.md's closing line, which still said twenty-two labs in kit 1.2.5, is corrected.

### 1.2.6 (2026-11-27)
- Three more labs: `spanning-tree-triangle` (NEO-08), `port-channel-lacp` (NEO-43) and `mlag-dual-homing` (NEO-44). Each is a self-contained folder with the lab file, diagram, configs or change files, a README and `scripts/make-captures.sh`. None of them needs the `neo-tools` image.
- `spanning-tree-triangle` and `port-channel-lacp` were checked on a Linux test machine (Containerlab 0.83.0), with sample captures; they have not yet been run on the VirtualBox VM. `spanning-tree-triangle` uses the Linux kernel's own STP: classic 802.1D only (no RSTP), timers shortened for the lab.
- `mlag-dual-homing` could only be checked in part: SR Linux accepted both leaf configurations, but the test machine's kernel has no bonding driver and no `dummy` device (SR Linux's `system0`, needed for VXLAN), so the lab has no sample captures yet. Its README says so at the top; the first full run, and the captures, are on the VM. SR Linux has no MLAG: the lab uses ESI-LAG (EVPN multihoming), the standards-based way to give a host one bundle over two switches.
- `tools/neo_diagram.py`: a LAG whose members run from one node to two others (a host bundle to two switches) now gets one oval near that node instead of one per link. Other diagrams are unchanged (the sample diagram renders identically).
- [LABS.md](LABS.md) and the lesson index list twenty-five labs.

### 1.2.5 (2026-11-27)
- Three more labs: `multivendor-ospf` (NEO-38), `multivendor-vrf` (NEO-39) and `vlans-trunks` (NEO-07). Each is a self-contained folder with the lab file, diagram, configs, change files, a README and (except `multivendor-vrf`, whose lesson is about route tables) sample captures and `scripts/make-captures.sh`. They were checked on a Linux test machine (Containerlab 0.83.0); they have not yet been run on the VirtualBox VM. The test machine has no Linux VRF support, so only the SR Linux half of `multivendor-vrf` was checked there. None of them needs the `neo-tools` image.
- `vlans-trunks` uses real 802.1Q tags made by two SR Linux switches (about 4 GB of memory together), not the user-space teaching switch of the lesson's original recording.
- Licences: new [LICENSES.md](LICENSES.md) and [LICENSE-MIT](LICENSE-MIT). Code (the `neo-tools` image, scripts, tools, lab, config and change files) is MIT, which matches the image's existing `licenses="MIT"` label; the guide, lessons, READMEs, diagrams and sample captures are CC BY 4.0.
- [LABS.md](LABS.md) and the lesson index list twenty-two labs.

### 1.2.4 (2026-11-27)
- Three more labs: `rip-four-routers` (NEO-47), `ospf-single-area` (NEO-10) and `vrf-two-tables` (NEO-12). Each is a self-contained folder with the lab file, diagram, configs, change files or scripts, sample captures and a README. They were checked on a Linux test machine (Containerlab 0.83.0) with real sample captures; they have not yet been run on the VirtualBox VM. None of them needs the `neo-tools` image.
- `vrf-two-tables` uses real VRFs (SR Linux network-instances of type `ip-vrf`), not the policy-routing stand-in of the lesson's original recording.
- `tools/neo_lint.py` also accepts 224.0.0.5 (the OSPF multicast group) in lab text, as it already did 224.0.0.9 (RIP).
- [LABS.md](LABS.md) and the lesson index list nineteen labs.

### 1.2.3 (2026-11-27)
- Three more labs: `dns-resolution` (NEO-06), `dhcp-dora-relay` (NEO-42) and `private-public-nat` (NEO-46). Each is a self-contained folder with the lab file, diagram, configs, scripts, sample captures and a README. They were checked on a Linux test machine (Containerlab 0.83.0) with real sample captures; they have not yet been run on the VirtualBox VM. All three use the NEO helper image `neo-tools:1.0.0`.
- Every `scripts/make-captures.sh` now runs with `sudo`, records to a temporary file and replaces a sample only when the recording succeeds (a failed one prints `FAIL`, keeps the old sample and the script exits with an error). The wait loops end on the clock, so the stated times are the real limits. In `tcp-troubleshooting` and `wireshark-practice` a fault that does not switch on now marks its capture `FAIL`, and the MTU fault is switched off only after its capture ends.
- `tcp-troubleshooting` and `wireshark-practice`: the zero-window and mid-transfer reset samples were re-recorded so each holds only its own connection; wording fixes (SYN retry timing, how Wireshark labels zero-window probes, which fault acts on which port); the port-exhaustion result is quoted. The Wireshark profile's README names `dns-rcode.pcapng`.
- Smaller README fixes in the other labs (see each README's Lab version line), a note in seven labs that their 10.0.2.x addresses share a range with the VM's own VirtualBox network, and `network-multitool` pinned to `v0.10.0` (the same image as before) in twelve lab files.
- Diagrams re-rendered for `routing-table-next-hop` (badge on the sink cable) and `multivendor-ssh-management` (the device is drawn as a server).
- `tools/`: `neo_lint.py` and `tools/README.md` say exactly which AS numbers are checked; `tools/neo-tools/PACKAGES-1.0.0.txt` lists the packages in the published helper image, and `tools/README.md` gives its digest.
- Opening the kit in VS Code: step 2 above and the beginner guide (now 1.3.4, Step 7.2) say to trust the `labs-main` folder and to check that the **Restricted Mode** badge at the bottom left is gone (in Restricted Mode the Containerlab extension is off and there is no **Deploy**). Both also cover a ZIP that unpacks to `labs-main` inside `labs-main`.
- [LABS.md](LABS.md) and the lesson index list sixteen labs.

### 1.2.2 (2026-11-27)
- Four more labs: `ssh-sessions` (NEO-04), `routing-table-next-hop` (NEO-09), `multivendor-ssh-management` (NEO-33) and `multivendor-route-tables` (NEO-37). Each is a self-contained folder with the lab file, diagram, configs, scripts, sample captures and a README. They were tested on a VirtualBox VM with real sample captures.
- The two SSH labs use the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` for the SSH server; it downloads automatically on Deploy, like the other images.
- [LABS.md](LABS.md) and the lesson index list thirteen labs, and LABS.md has a lesson map by lesson number. The beginner guide is unchanged (1.3.3).

### 1.2.1 (2026-11-26)
- Four more labs: `tcp-troubleshooting` (NEO-02), `wireshark-practice` (NEO-03), `subnetting-gateway` (NEO-05) and `multivendor-interfaces` (NEO-34). They were tested on a VirtualBox VM with real sample captures. The Wireshark color-profile import (`wireshark-practice/wireshark/NEO_Diagnostics_profile.zip`) was not tested in the Wireshark window.
- [LABS.md](LABS.md) and the lesson index list nine labs. The beginner guide is unchanged (1.3.3).

### 1.2.0 (2026-11-26)
- Four new labs, each a self-contained folder under `labs/` (lab file, diagram, configs, scripts, sample captures and README): `tcp-basics` (NEO-01), `osi-http-capture` (NEO-45), `bgp-ebgp-ibgp-path-choice` (NEO-11) and `multivendor-ebgp` (NEO-32). [LABS.md](LABS.md) lists them.
- `labs/ebgp-two-sites` 1.1.4: diagram labels were added to the lab file so hosts draw as hosts and the diagram files are prepared. Nodes, addresses, links and configs unchanged. 1.1.5: README only. The BGP keepalive in exercise E4 is now "about every 30 s" (hold time 90 s, keepalive one third of it); the old text said about 60 s. A sample capture, `captures/ebgp-keepalive.pcapng`, shows it.
- Every lab README now has **Before you start**, **Troubleshooting** (lab-specific failures and fixes) and **Cleanup** (`containerlab destroy --cleanup`). Each lab has a prepared `.drawio` and `.png` diagram; port labels now show the full interface name (for example `ethernet-1/1`) at 11 px or larger, and no label or link sits on top of another.
- New `tools/` folder for lab authors: `neo_diagram.py` (makes the diagram), `neo_lint.py` (checks a lab: Containerlab schema, private IPv4 only, private AS numbers, `fd00::/8` management IPv6, documentation ranges rejected), a sample, and the optional helper image `neo-tools`.
- Beginner guide 1.3.3: the keepalive text in the optional exercises ("about every 30 seconds") is corrected. Nothing else in the guide changed.
- AS numbers accepted in the kit rules now include 4200000000-4294967294; documentation address ranges are named as not allowed.

### 1.1.3 (2026-11-26)
- Beginner guide 1.3.2 (`NEO-Containerlab-Beginner-Guide.pdf`), after a full beginner walkthrough on VirtualBox 7.2.22 with Containerlab 0.83.0, extension 0.28.0 and Wireshark 4.2.2:
  - Wireshark: the main method now records to a file in Home (`containerlab capture ... --duration ... -w - > file`) and opens it in Wireshark. The right-click **Capture With Wireshark** is an optional shortcut (it can crash the viewer).
  - New checks: `docker ps` without sudo before VS Code; all four devices after a VM restart, with `redeploy` without `-c` for recovery.
  - Exact download steps (green Code > Download ZIP, `~/labs-main/containerlab`), trust only the lab folder, Destroy vs Destroy (Cleanup), one command per line.
- Checked again step by step on a real VirtualBox VM: wait about a minute after Deploy (BGP checkpoint `1`); after a VM restart edge-b is always the stopped device and the recovery redeploy's red `ERRO` blocks are expected; plain Destroy leaves the root-owned `clab-<lab-name>` folder, Destroy (Cleanup) removes it; start the wrong-AS capture right after the clean redeploy (75 seconds is long enough to catch a retry). OPEN and NOTIFICATION lines repeat while the routers keep retrying; your count and times will differ.
- This README and `labs/ebgp-two-sites/README.md` updated to match. Lab file and router configs unchanged.

### 1.1.2 (2026-11-26)
- Added the beginner guide PDF: `NEO-Containerlab-Beginner-Guide.pdf` (this folder).

### 1.1.1 (2026-11-26)
- READMEs now mention the management IPv6 ULA prefix (`fd00:172:20:20::/64`) next to the RFC 1918 IPv4 addresses.

### 1.1.0 (2026-11-26)
- Renamed lab: `labs/neo-48-ebgp/` is now `labs/ebgp-two-sites/` (folder, lab file `ebgp-two-sites.clab.yml` and its `name:`). Containers are now called `clab-ebgp-two-sites-*`. If you have the old lab running, destroy it before you download this version.
- The lab file now sets its management network (`mgmt:`): IPv4 172.20.20.0/24 and IPv6 fd00:172:20:20::/64 (private ULA range), instead of Containerlab's default IPv6 range.
- One FRR check command everywhere: `show bgp summary`.
- Status line no longer says "in review".

### 1.0.0 (2026-11-26)
- Download is the repository ZIP (Code > Download ZIP): `labs-main.zip` unpacks to `labs-main/containerlab/`.
- Kit runs from VS Code with the Containerlab extension (deploy, Attach Shell, Capture With Wireshark, Destroy).
- Editing a config: restart with `containerlab redeploy -c` in VS Code's terminal (the extension's Redeploy (Cleanup) is not recommended).
- Added the draw.io diagram steps (`containerlab graph --drawio` + `chown`).
- `labs/neo-48-ebgp/README.md`: login steps corrected (Attach Shell opens `vtysh` / `sr_cli` directly), duplicate edge-a explained.
- Arista add-on lab removed from the kit (needs a vendor account per viewer).

### 1.0.0-draft (2026-11-25)
- First Containerlab kit. Added `labs/neo-48-ebgp/` (SR Linux + FRR eBGP lab, four exercises).
