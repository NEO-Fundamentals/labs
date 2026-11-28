# Lab: DHCP, how a host gets its address (DORA, leases and a relay)

**Folder:** `labs/dhcp-dora-relay/`  **Lab file:** `dhcp-dora-relay.clab.yml`  **Lesson:** NEO-42 DHCP: how a host gets its address (DORA, leases and relay)  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs a real Nokia SR Linux router (r1) acting as a DHCP relay, a Linux DHCP server (dnsmasq) and two Linux clients (the ISC DHCP client, `dhclient`). **There is no Arista EOS, Juniper Junos or Cisco device in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/dhcp-dora-relay/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/neo-fundamentals/neo-tools:1.0.0` (about 260 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start its relay. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 client-1 ---------- srv ------------ r1 (SR Linux) ---------- client-2
 (DHCP)    LAN A     DHCP server      DHCP relay       LAN B   (DHCP)
       10.42.10.0/24        10.42.0.0/30        10.42.20.0/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| client-1 | Linux host on LAN A. It starts with **no address** and no default route; it asks DHCP | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| srv | DHCP server (dnsmasq): 10.42.10.1/24 on LAN A (eth1), 10.42.0.1/30 to r1 (eth2). Two address pools: 10.42.10.100-149 for LAN A and 10.42.20.100-149 for LAN B, each with a 2-minute lease | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| r1 | SR Linux router: 10.42.0.2/30 (ethernet-1/1), 10.42.20.1/24 (ethernet-1/2). DHCP relay on ethernet-1/2, sending to the server 10.42.0.1 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| client-2 | Linux host on LAN B, behind r1. It starts with no address and no default route; it asks DHCP | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r1 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

**Your addresses will differ from the ones below.** The server picks an address from the pool based on the client's hardware (MAC) address, and Containerlab gives the clients new MAC addresses at every Deploy. client-1 always gets one between 10.42.10.100 and 10.42.10.149, client-2 one between 10.42.20.100 and 10.42.20.149.

## Files

- `dhcp-dora-relay.clab.yml` - the lab drawing.
- `configs/srv/dnsmasq.conf` - the DHCP server: the two pools, the gateway each pool hands out, the 2-minute lease. Every line has a comment.
- `configs/r1-srl.cli` - r1 (SR Linux): interfaces, the DHCP relay on ethernet-1/2, and a static route back to LAN A.
- `scripts/make-captures.sh` - re-records the sample captures. Deploy (or redeploy) the lab first, so that neither client has an address yet. Run it with `sudo bash scripts/make-captures.sh` from the lab folder; it waits up to 4 minutes for r1's relay, takes about 3 minutes, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `dhcp-dora-relay.drawio` and `dhcp-dora-relay.png` - the prepared diagram.
- `captures/` - five sample captures, recorded from this lab: `dhcp-1-dora-direct.pcapng`, `dhcp-2-dora-relay.pcapng`, `dhcp-3-renew.pcapng`, `dhcp-4-release.pcapng`, `dhcp-5-no-server.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `dhcp-dora-relay` > right-click `dhcp-dora-relay.clab.yml` > **Deploy**. Wait for the green dots, then check r1's relay in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-dhcp-dora-relay-r1 sr_cli "info from state /interface ethernet-1/2 subinterface 0 ipv4 dhcp-relay oper-state"
  ```
  It prints `oper-state up`. If it prints an error or nothing, SR Linux is still starting: wait a minute and run it again.
- **Reset to the lesson start** (both clients without an address again):
  ```
  cd ~/labs-main/containerlab/labs/dhcp-dora-relay
  ```
  ```
  containerlab redeploy -c -t dhcp-dora-relay.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | Linux client (`dhclient`) | DHCP server (dnsmasq, on srv) | SR Linux relay (r1) |
|---|---|---|---|
| Get an address | `dhclient -v -1 eth1` | - | - |
| Give the address back | `dhclient -v -r eth1` | - | - |
| See what was handed out | `cat /var/lib/dhcp/dhclient.leases` and `ip -4 addr show eth1` | `cat /var/lib/misc/dnsmasq.leases` | - |
| Read the conversation | - | `grep DHCP /var/log/dnsmasq.log` | `info from state /interface ethernet-1/2 subinterface 0 ipv4 dhcp-relay statistics` |
| Wireshark filter | `dhcp` (older Wireshark versions: `bootp`) | `dhcp.ip.relay == 10.42.20.1` (relayed packets only) | |

Junos and EOS are not part of this lab. On those systems and on Cisco devices the relay setting is called a "DHCP relay" or "helper address" on the client-facing interface; the idea is the same as r1's `dhcp-relay` with `server 10.42.0.1`.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name.

**1. A host with no address.**
```
docker exec clab-dhcp-dora-relay-client-1 ip -4 addr show eth1
```
It prints nothing: eth1 is up but has no IPv4 address. `ip route` on client-1 lists only the management network `172.20.20.0/24` on eth0 (ignore eth0 in this lab; it is how Containerlab reaches the container). There is no default route either.

**2. DORA on one cable.** In Ubuntu's Terminal app start the capture first (10 seconds), on the server's LAN A cable:
```
sudo containerlab capture --name dhcp-dora-relay --target srv:eth1 --duration 10s -w - > "$HOME/neo-dora.pcapng"
```
Then, within the 10 seconds, in VS Code's terminal:
```
docker exec clab-dhcp-dora-relay-client-1 dhclient -v -1 eth1
```
`dhclient` prints the four steps, **D**iscover, **O**ffer, **R**equest, **A**ck:
```
DHCPDISCOVER on eth1 to 255.255.255.255 port 67 interval 5
DHCPOFFER of 10.42.10.118 from 10.42.10.1
DHCPREQUEST for 10.42.10.118 on eth1 to 255.255.255.255 port 67
DHCPACK of 10.42.10.118 from 10.42.10.1
bound to 10.42.10.118 -- renewal in 48 seconds.
```
(your address, the interval and the renewal time will differ). Open the capture in Wireshark with the filter `dhcp`. The sample `captures/dhcp-1-dora-direct.pcapng` shows it: frame 1 is the Discover from `0.0.0.0` to `255.255.255.255` (the client has no address yet, so it broadcasts). Frames 2 to 5 are the server checking that the address is free before it offers it: three ARP questions and one ping, none answered. Frame 6 is the Offer about 3 seconds later, frame 7 the Request (still a broadcast) and frame 8 the Ack. Click the Offer and open **Dynamic Host Configuration Protocol**: **Your (client) IP address** is the offered address, and the options include **Subnet Mask**, **Router** 10.42.10.1 and **IP Address Lease Time** (2 minutes).

**3. What the client learned.**
```
docker exec clab-dhcp-dora-relay-client-1 ip -4 addr show eth1
```
```
docker exec clab-dhcp-dora-relay-client-1 ip route
```
```
docker exec clab-dhcp-dora-relay-client-1 cat /var/lib/dhcp/dhclient.leases
```
eth1 now has its address with `dynamic` (it came from DHCP, and `valid_lft` counts down from 120 seconds). The table now has `default via 10.42.10.1 dev eth1`: the gateway also came from DHCP. The lease file lists everything the server sent, including `option dhcp-lease-time 120`, `option dhcp-renewal-time 60` (renew after half the lease) and `option dhcp-rebinding-time 105`.

**4. The server's side.**
```
docker exec clab-dhcp-dora-relay-srv cat /var/lib/misc/dnsmasq.leases
```
```
docker exec clab-dhcp-dora-relay-srv grep -E "DHCP(DISCOVER|OFFER|REQUEST|ACK)" /var/log/dnsmasq.log
```
The lease line holds the expiry time (in seconds since 1970), the client's MAC address, its IP address and its name. The log shows the same four steps, each with `(eth1)`: the interface the request arrived on.

**5. Through a relay.** client-2's broadcast cannot cross r1: routers do not forward broadcasts. r1's DHCP relay picks the broadcast up and sends it to the server as a normal unicast packet. Capture both cables at once (client-2's cable and the server's cable to r1) for 10 seconds:
```
sudo containerlab capture --name dhcp-dora-relay --target client-2:eth1 --target srv:eth2 --duration 10s -w - > "$HOME/neo-relay.pcapng"
```
```
docker exec clab-dhcp-dora-relay-client-2 dhclient -v -1 eth1
```
`dhclient` says `DHCPOFFER of 10.42.20.x from 10.42.20.1`: to the client, the answer comes from r1. In the sample `captures/dhcp-2-dora-relay.pcapng` (filter `dhcp`), each message appears twice. On `client-2:eth1` the Discover (frame 1) is a broadcast from `0.0.0.0`. On `srv:eth2` the same Discover (frame 2) goes from 10.42.20.1 to 10.42.0.1, and in the DHCP details **Relay agent IP address** is `10.42.20.1`. That is how the server knows to use the LAN B pool. The Offer and the Ack come back the same way (frames 8 and 9, 12 and 13). Frame 14 is r1 telling the server that the ping it used for the address check (frame 3) could not be delivered, because client-2 had no address yet. Count what r1 relayed:
```
docker exec clab-dhcp-dora-relay-r1 sr_cli "info from state /interface ethernet-1/2 subinterface 0 ipv4 dhcp-relay statistics"
```
`client-packets-relayed 2` (Discover and Request) and `server-packets-relayed 2` (Offer and Ack). Now check that the addresses really work: client-2 pings client-1 across r1 and srv. Do not use a printed sample address (the 10.42.10.118 in exercise 2 is only an example; yours will differ). Read the address client-1 actually received on eth1, the lab interface (ignore eth0):
```
docker exec clab-dhcp-dora-relay-client-1 ip -4 -br addr show eth1
```
The line looks like `eth1   UP  10.42.10.145/24` (the last part of the address will differ). Ping that address from client-2, either by typing it, or by letting the shell copy it for you:
```
ADDR=$(docker exec clab-dhcp-dora-relay-client-1 ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1)
echo "client-1 is $ADDR"
docker exec clab-dhcp-dora-relay-client-2 ping -c 2 "$ADDR"
```
Two replies: DHCP gave both clients an address and a gateway, so they reach each other through r1 and srv.

**6. The renewal.** A lease does not last for ever. After half of it (here about one minute; `dhclient` printed `renewal in ... seconds`) the client asks the same server to extend it. Start this capture right after exercise 5 and wait (75 seconds):
```
sudo containerlab capture --name dhcp-dora-relay --target client-2:eth1 --target srv:eth2 --duration 75s -w - > "$HOME/neo-renew.pcapng"
```
In the sample `captures/dhcp-3-renew.pcapng` (filter `dhcp`) there are only a Request and an Ack, about 52 seconds in (frames 11 to 14). This time the Request goes from client-2's own address straight to the server 10.42.0.1 as a normal unicast packet, and **Relay agent IP address** is `0.0.0.0`: the client now has an address and a route, so it needs neither a broadcast nor the relay. r1 only routes it. The other frames are background traffic (LLDP from r1, IPv6 router solicitations, ARP); filter `dhcp` hides them.

**7. Giving the address back.**
```
docker exec clab-dhcp-dora-relay-client-2 dhclient -v -r eth1
```
It prints `DHCPRELEASE of 10.42.20.x on eth1 to 10.42.0.1 port 67`, and `ip -4 addr show eth1` on client-2 is empty again. The server's lease file (exercise 4) no longer lists client-2. The sample `captures/dhcp-4-release.pcapng` shows the one Release, unicast to the server (frames 2 and 3; frame 1 is a router solicitation).

**8. No server.** Stop the DHCP server, then let client-2 try for 18 seconds:
```
docker exec clab-dhcp-dora-relay-srv pkill dnsmasq
```
```
docker exec clab-dhcp-dora-relay-client-2 timeout 18 dhclient -v -1 eth1
```
It prints `DHCPDISCOVER on eth1 to 255.255.255.255 port 67 interval 3` and more Discover lines with growing intervals, and no Offer. After 18 seconds `timeout` stops it and client-2 still has no address. In the sample `captures/dhcp-5-no-server.pcapng`, r1 relays each Discover to 10.42.0.1 (frames 2, 9 and 12), and srv answers each with an ICMP **Port unreachable** (frames 3, 10 and 13): the machine is there, but nothing listens on DHCP's port 67. A host that keeps sending Discover and never gets an Offer is the classic sign of a DHCP server or relay problem. Start the server again and ask once more:
```
docker exec clab-dhcp-dora-relay-srv dnsmasq --conf-file=/etc/neo/dnsmasq.conf
```
```
docker exec clab-dhcp-dora-relay-client-2 dhclient -v -1 eth1
```
client-2 is bound again.

## Sample captures

All are cut to 400 bytes per packet (enough for the whole DHCP message). Open them in Wireshark with File > Open and filter on `dhcp`. The interface name of each frame (for example `srv:eth2`) is in the frame details.

| File | Frames | Cables | What it shows |
|---|---|---|---|
| `dhcp-1-dora-direct.pcapng` | 8 | srv:eth1 | Discover, the server's address check (3 ARP, 1 ping), Offer, Request, Ack |
| `dhcp-2-dora-relay.pcapng` | 16 | client-2:eth1 and srv:eth2 | The same DORA through r1: broadcasts on client-2's cable, unicasts with relay agent 10.42.20.1 on the server's cable |
| `dhcp-3-renew.pcapng` | 20 | client-2:eth1 and srv:eth2 | 75 seconds of a bound client: one unicast Request and Ack at about 52 s, without the relay; the rest is background traffic |
| `dhcp-4-release.pcapng` | 3 | client-2:eth1 and srv:eth2 | The Release, unicast to the server |
| `dhcp-5-no-server.pcapng` | 13 | client-2:eth1 and srv:eth2 | Server stopped: three relayed Discovers, each answered by ICMP Port unreachable, no Offer |

## What this lab does not do

- No DHCPv6 or IPv6 addresses; DHCP for IPv4 only.
- No reservations (a fixed address for one MAC), no DHCP options beyond the netmask, gateway, broadcast address and lease times, and no DNS server handed out.
- One relay and one server. Real networks often list two servers in the relay for redundancy.
- Leases last 2 minutes so you can watch a renewal; real networks use hours or days.
- A veth pair carries each link, so there is no real switch on LAN A or LAN B.

## Troubleshooting

1. **client-2 keeps sending DHCPDISCOVER and gets no Offer.** r1 may still be starting: run the check in **Start** until it prints `oper-state up`. If the server was stopped in exercise 8, start it again (`docker exec clab-dhcp-dora-relay-srv dnsmasq --conf-file=/etc/neo/dnsmasq.conf`), but only once (see 3).
2. **`dhclient` runs for about a minute, then prints `No DHCPOFFERS received.` and `Unable to obtain a lease on first try.  Exiting.`** Same as 1: no server answered. Press Ctrl+C if you do not want to wait, then fix the cause.
3. **You see two Offers for one Discover.** The server was started twice, and both copies may answer. Check with `docker exec clab-dhcp-dora-relay-srv pgrep -a dnsmasq`: there must be one line. If there are two, run `docker exec clab-dhcp-dora-relay-srv pkill dnsmasq` and start it once.
4. **A client has an address and you want to start again.** Run `docker exec clab-dhcp-dora-relay-client-1 dhclient -v -r eth1` (or client-2), or reset the whole lab with `containerlab redeploy -c -t dhcp-dora-relay.clab.yml`.
5. **Your capture shows no renewal.** Start it right after the client got its address; the renewal comes after about half the lease (one minute). If the client was released (exercise 7), there is nothing to renew.
6. **`sr_cli` says a command is unknown.** SR Linux is picky about spaces; copy the command exactly, or open r1 with Attach Shell and press the question mark key for the options.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/dhcp-dora-relay
```
```
containerlab destroy --cleanup -t dhcp-dora-relay.clab.yml
```
`--cleanup` also removes the generated `clab-dhcp-dora-relay` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-dhcp-dora-relay` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/dhcp-dora-relay/clab-dhcp-dora-relay
```
Your capture files in your Home folder are not touched.
