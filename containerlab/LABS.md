# NEO labs: index

Every lesson lab is its own folder under `labs/`. Open the folder in VS Code and everything for that lesson is inside it:

- `<lab>.clab.yml` - the lab itself (the file you right-click and **Deploy**)
- `<lab>.drawio` and `<lab>.png` - the prepared diagram
- `configs/` - startup configs for the routers and servers
- `captures/` - sample captures recorded from the lab, to open in Wireshark
- `scripts/` - helper scripts for the lab (for example `make-captures.sh`)
- `README.md` - the steps, checks, exercises, troubleshooting and cleanup for that lesson

Nothing lesson-specific lives anywhere else. The `tools/` folder is for lab authors (diagram and check tools); `tools/neo-tools` is an optional helper image for future labs that need a firewall, load balancer or DHCP server. None of the labs below uses it.

Run **one lab at a time** (the virtual machine has 8 GB of memory). Deploy: Containerlab panel > **Undeployed Local Labs** > `labs` > the lab > right-click the `.clab.yml` > **Deploy**. Every lab README starts with **Before you start** and ends with **Troubleshooting** and **Cleanup**.

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

More labs are added here as each lesson's lab is finished (one folder per lesson).
