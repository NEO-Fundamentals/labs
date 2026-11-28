# Lab: Structured troubleshooting capstone

**Folder:** `labs/troubleshooting-capstone/`  **Lab file:** `troubleshooting-capstone.clab.yml`  **Lesson:** NEO-26 Structured troubleshooting capstone  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** one topology that joins the routed path of NEO-24 and the access-port switch of NEO-25. host-a, host-b and host-c sit on a Linux switch (`sw`, one bridge per VLAN); r1 is their gateway; a Linux nftables firewall (`fw`) and a second router (`r2`) sit on the way to h2's web server. r1, fw and r2 are **Linux routers** (the NEO helper image `neo-tools`), not FRR: the method is the same as in NEO-24, and the lab stays small. You practise a fixed order of checks on three faults that `scripts/fault.sh` puts in place. No SR Linux in this lab. The Cisco-style commands from NEO-24 and NEO-25 are listed as text to compare.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: eight Linux containers, about 35 MB together (measured). No SR Linux and no FRR in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/troubleshooting-capstone/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes about 10 seconds. The lab is ready when the check in **Start** passes.
- **Do `path-trace-routed` and `path-trace-access-port` first** if you can: this lab uses the same ideas (entry point, hop by hop both ways, ARP, MAC address table, access port).

## What this lab builds

```
 host-a 10.26.10.11        host-b 10.26.10.12        host-c 10.26.20.13
        VLAN 10                   VLAN 10                   VLAN 20
           |                         |                         |
           +------------------------ sw -----------------------+
                                 r1 (gateway)
                           10.26.10.1 and 10.26.20.1
                                    |
                                   fw
                                    |
                                   r2
                                    |
                            h2 10.26.2.20 (web :80)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | 10.26.10.11/24, VLAN 10, MAC 02:00:00:26:10:11, gateway 10.26.10.1 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-b | 10.26.10.12/24, VLAN 10, MAC 02:00:00:26:10:12, gateway 10.26.10.1 | same | Attach Shell |
| host-c | 10.26.20.13/24, VLAN 20, MAC 02:00:00:26:20:13, gateway 10.26.20.1 | same | Attach Shell |
| sw | Linux switch, one bridge per VLAN: `vlan10` = eth1 (uplink to r1), eth2 (host-a), eth3 (host-b); `vlan20` = eth4 (host-c), eth5 (uplink to r1) | same | Attach Shell |
| r1 | Linux router, the gateway of both VLANs: eth1 10.26.10.1, eth2 10.26.20.1, eth3 10.26.12.1 (toward fw) | same | Attach Shell |
| fw | Linux router with nftables: eth1 10.26.12.2, eth2 10.26.23.2. Its rules (`configs/fw-rules.nft`) let ping, traceroute and web from the r1 side to h2's LAN through, and the replies back; everything else is dropped | same | Attach Shell |
| r2 | Linux router: eth1 10.26.23.3, eth2 10.26.2.1 (h2's gateway). Static routes back to VLAN 10, VLAN 20 and 10.26.12.0/24 via fw | same | Attach Shell |
| h2 | 10.26.2.20/24, default gateway 10.26.2.1; web server on port 80 | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. Each box also has a management interface, eth0 (172.20.20.x), which the lab traffic does not use.

**One bridge per VLAN.** As in NEO-25: a port's VLAN is the bridge it belongs to. There is no 802.1Q trunk.

## Files

- `troubleshooting-capstone.clab.yml` - the lab drawing. Addresses, routes, bridges and the web server are set by each node's `exec` lines.
- `configs/fw-rules.nft` - fw's rules; loading it again puts them back as at deploy.
- `changes/fw-change.nft` - the firewall change of exercise 5.
- `scripts/fault.sh` - puts the fault of an exercise in place: `bash scripts/fault.sh 1` (exercise 3), `2` (exercise 4), `3` (exercise 5). Try each exercise before you read how the fault is made.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, puts each fault in place and undoes it, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `troubleshooting-capstone.drawio` and `troubleshooting-capstone.png` - the prepared diagram.
- `captures/` - three sample captures: `ts-1-wrong-vlan.pcapng`, `ts-2-no-return.pcapng`, `ts-3-fw-drop.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `troubleshooting-capstone` > right-click `troubleshooting-capstone.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 http://10.26.2.20/
  ```
  It prints `hello from h2 (10.26.2.20)`.
- **Reset to the lesson start** (ports, routes and fw's rules as at deploy): do this whenever a fault is left over.
  ```
  cd ~/labs-main/containerlab/labs/troubleshooting-capstone
  ```
  ```
  containerlab redeploy -c -t troubleshooting-capstone.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The method

When something is down, work in this order, and write down what still works. Skip a layer and you will chase the wrong box.

1. **State the ticket.** Who cannot reach what? What still works? (another host, ping but not the web page, one VLAN but not the other.)
2. **Layer 2 at the source.** Is the port up? Is it in the right VLAN? Does ARP resolve? Which switch port has that MAC address?
3. **The routed path, both ways.** Start at the entry point (the source's gateway). Ask each hop "where does a packet for the destination go next?", follow the answer, and do the same from the destination back: every hop must know the way back too.
4. **The service.** If the path is complete, is the port open, did a firewall drop it, does the application answer?
5. **Change one thing, verify that one thing, then re-check the original symptom.**

| Question | Where | Command | Cisco-style (text only) |
|---|---|---|---|
| Can this host reach the web server? | host-a, host-b, host-c | `curl -s -m 3 http://10.26.2.20/` | |
| Is the port up, and in which VLAN? | sw | `bridge link show dev eth3` | `show interfaces status`, `show vlan brief` |
| What is the host's MAC address, and which port has it? | the host; sw | `ip -br link show eth1`, `bridge fdb show \| grep <mac>` | `show mac address-table address ...` |
| Does the gateway have an ARP entry? | r1 | `ip neigh show` | `show ip arp` |
| Which hops does the path take? | a host | `traceroute -n 10.26.2.20` (`-T -p 80` for TCP to port 80) | `traceroute 10.26.2.20` |
| Where does this router send a packet for X? | r1, r2, fw | `ip route get X` | `show ip route X` |
| May fw pass this? | fw | `nft list chain inet fw forward` | `show security flow session` / policy hit counts |
| Did the packet arrive, and did an answer leave? | any Linux box | `tcpdump -lni eth1 ...` | |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/troubleshooting-capstone`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The healthy picture.** Before you look for faults, know what good looks like. host-a reaches the web server; so do host-b and host-c. The path has four hops. host-b's MAC address is on sw's port eth3, in VLAN 10.
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-b curl -s -m 3 http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-c curl -s -m 3 http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-a traceroute -n -w 1 -q 1 10.26.2.20
```
```
docker exec clab-troubleshooting-capstone-host-a sh -c 'ping -c 1 -W 1 10.26.10.1 >/dev/null; ip neigh show'
```
```
docker exec clab-troubleshooting-capstone-sw sh -c 'bridge fdb show | grep 02:00:00:26:10:12'
```
```
docker exec clab-troubleshooting-capstone-sw bridge link show dev eth3
```
Each curl prints `hello from h2 (10.26.2.20)`. The traceroute lists four hops: `10.26.10.1` (r1), `10.26.12.2` (fw), `10.26.23.3` (r2), `10.26.2.20` (h2). host-a's neighbour table has `10.26.10.1 ... 02:00:00:26:10:01`. The switch has `02:00:00:26:10:12 dev eth3 master vlan10`, and port eth3 is `master vlan10` and `state forwarding`.

**2. Use the method on a clear ticket, before anything is broken.** Ticket: "a user at 10.26.10.12 cannot load http://10.26.2.20/". On a healthy lab the answer is "that user can, and here is the path": host-b is on VLAN 10 port eth3, the gateway is 10.26.10.1, the four hops are the ones in exercise 1, and the way back is in each router's table. Keep that picture. The next three exercises each put one fault in place; work the method before you read how the fault is made.

**3. "host-b cannot reach the web server."** Put the fault in place:
```
bash scripts/fault.sh 1
```
```
docker exec clab-troubleshooting-capstone-host-b curl -s -m 3 -o /dev/null -w 'host-b http %{http_code}\n' http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 -o /dev/null -w 'host-a http %{http_code}\n' http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-b ping -c 2 -W 1 10.26.10.1
```
```
docker exec clab-troubleshooting-capstone-sw bridge link show dev eth3
```
```
docker exec clab-troubleshooting-capstone-sw sh -c 'bridge fdb show | grep 02:00:00:26:10:12'
```
host-b gets `http 000` and cannot ping its own gateway, but host-a still gets `http 200`. So the routed path and the web server are fine: the problem is at host-b's access port. eth3 is now `master vlan20`. host-b's MAC address is learned in VLAN 20 (or not yet, if it has been silent). host-b is still addressed in 10.26.10.0/24, which lives in VLAN 10, so ARP never completes.

The fix is to put the port back in VLAN 10 (Cisco-style: `switchport access vlan 10`). Then check the original symptom:
```
docker exec clab-troubleshooting-capstone-sw ip link set eth3 master vlan10
```
```
docker exec clab-troubleshooting-capstone-host-b sh -c 'ip neigh flush dev eth1; curl -s -m 3 http://10.26.2.20/'
```
It prints `hello from h2 (10.26.2.20)` again, or the first try can fail while host-b renews its ARP entry for the gateway; run it again and it is fine. (Sample `ts-1-wrong-vlan.pcapng`, recorded on r1's two uplinks at sw: host-b's "Who has 10.26.10.1?" on the **VLAN 20** link, and r1's "Who has 10.26.10.12?" on the VLAN 10 link; no answers.)

**4. "host-a cannot reach the web server, but host-c can."** Reset if a fault is still in place, then:
```
bash scripts/fault.sh 2
```
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 -o /dev/null -w 'host-a http %{http_code}\n' http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-c curl -s -m 3 -o /dev/null -w 'host-c http %{http_code}\n' http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-a ping -c 2 -W 1 10.26.2.20
```
```
docker exec clab-troubleshooting-capstone-host-a traceroute -n -w 1 -q 1 -m 6 10.26.2.20
```
host-a gets `http 000` and every ping is lost; host-c still gets `http 200`. The traceroute answers for hops 1 and 2 (r1, fw), then only `*` (it stops at hop 6). It looks as if the packets stop after fw. Layer 2 at host-a is fine (exercise 1's checks still hold). Check whether the packets arrive at h2. In a second terminal (it stops by itself after 8 seconds):
```
docker exec clab-troubleshooting-capstone-h2 timeout 8 tcpdump -l -ni eth1 icmp
```
In the first terminal:
```
docker exec clab-troubleshooting-capstone-host-a ping -c 2 -W 1 10.26.2.20
```
tcpdump shows the requests arriving and the replies leaving, and `ICMP net 10.26.10.11 unreachable` from r2 (10.26.2.1). Only one unreachable may appear (the kernel rate-limits them). r2 is h2's gateway, and it no longer has a route back to VLAN 10:
```
docker exec clab-troubleshooting-capstone-r2 ip route
```
```
docker exec clab-troubleshooting-capstone-r2 ip route get 10.26.10.11
```
The table still has 10.26.20.0/24 (that is why host-c works) and has no 10.26.10.0/24. `ip route get` prints `Network is unreachable` (these routers have no default route, only the lab routes, so a missing route does not leak onto the management interface). Put the route back and check the original symptom:
```
docker exec clab-troubleshooting-capstone-r2 ip route add 10.26.10.0/24 via 10.26.23.2
```
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 http://10.26.2.20/
```
It prints `hello from h2 (10.26.2.20)`. (Sample `ts-2-no-return.pcapng`, recorded on h2: the requests in, the replies out, and the unreachable.)

**5. "The web page is down, but ping works."** Reset if a fault is still in place, then:
```
bash scripts/fault.sh 3
```
```
docker exec clab-troubleshooting-capstone-host-a ping -c 2 -W 1 10.26.2.20
```
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.26.2.20/
```
```
docker exec clab-troubleshooting-capstone-host-a traceroute -n -T -p 80 -w 1 -q 1 -m 5 10.26.2.20
```
The ping works (2 of 2), so every route is fine, but the web request gets nothing (`http 000 in 3.0 s`). A traceroute with TCP probes to port 80 (`-T -p 80`) answers for hop 1 (r1) and hop 2 (fw), then only `*`. The path is complete for ping; the service is not. In a second terminal, watch fw (it stops by itself after 8 seconds):
```
docker exec clab-troubleshooting-capstone-fw timeout 8 tcpdump -l -ni any tcp port 80
```
In the first terminal:
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code}\n' http://10.26.2.20/
```
tcpdump shows host-a's SYNs coming **in** on eth1 (`eth1 In IP 10.26.10.11.xxxxx > 10.26.2.20.80: Flags [S]`, three times) and **nothing out** on eth2: fw dropped them. The rules show why: a new rule at the top, `ip daddr 10.26.2.0/24 tcp dport 80 counter packets ... drop comment "CHG-0042 block old web server"`. The change was meant for one old server, 10.26.2.200, but it was typed with the whole subnet. Load the lesson rules again and check the original symptom:
```
docker exec -i clab-troubleshooting-capstone-fw nft -f - < configs/fw-rules.nft
```
```
docker exec clab-troubleshooting-capstone-host-a curl -s -m 3 http://10.26.2.20/
```
It prints `hello from h2 (10.26.2.20)`. (Sample `ts-3-fw-drop.pcapng`, recorded on fw's two links: SYNs in on eth1, nothing out on eth2.)

## Sample captures

Open them in Wireshark with File > Open. The display filters `arp`, `icmp`, and `tcp.port == 80` each show one kind of frame.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `ts-1-wrong-vlan.pcapng` | sw:eth1 and sw:eth5 (r1's VLAN 10 and VLAN 20 links) | 6 | exercise 3: host-b's "Who has 10.26.10.1?" on the **VLAN 20** link (eth5), and r1's "Who has 10.26.10.12?" on the VLAN 10 link (eth1); no answers (Wireshark: the `frame.interface_name` field tells the two links apart) |
| `ts-2-no-return.pcapng` | h2:eth1 | 6 | exercise 4: host-a's echo requests arrive and the replies leave; r2 sends `ICMP net 10.26.10.11 unreachable` (only one may appear) |
| `ts-3-fw-drop.pcapng` | fw:eth1 and fw:eth2 | 7 | exercise 5: TCP SYNs to port 80 arrive on eth1 and do not leave on eth2 |

Frame counts move by a few frames from run to run (IPv6 router solicitations right after a fresh deploy, and ARP timing).

## What this lab does not do

- No FRR and no SR Linux: r1, fw and r2 are Linux routers, so the commands are `ip route` and `nft`, not `vtysh`. The method is the same as in NEO-24.
- No 802.1Q tags and no trunk: one bridge per VLAN, as in NEO-25.
- The faults are made by `scripts/fault.sh`, not by real outages. A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start prints nothing.** A fault is still in place, or the web server is still starting: wait 5 seconds and try again, or reset the lab.
2. **Exercise 3: r1's ARP entry for host-b is still `REACHABLE`.** Run `docker exec clab-troubleshooting-capstone-r1 ip neigh flush to 10.26.10.12` just before the ping, as the capture script does.
3. **No `tcpdump` output in the second terminal.** Start the first-terminal command within 8 seconds of the second-terminal one, or run both again. Use `tcpdump -l` (line-buffered) as listed.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/troubleshooting-capstone
```
```
containerlab destroy --cleanup -t troubleshooting-capstone.clab.yml
```
`--cleanup` also removes the generated `clab-troubleshooting-capstone` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-troubleshooting-capstone` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/troubleshooting-capstone/clab-troubleshooting-capstone
```
Your capture files in your Home folder are not touched.
