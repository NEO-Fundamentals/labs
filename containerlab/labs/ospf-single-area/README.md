# Lab: OSPF in a single area

**Folder:** `labs/ospf-single-area/`  **Lab file:** `ospf-single-area.clab.yml`  **Lesson:** NEO-10 OSPF in a Single Area  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs two real FRR routers (r1, r2), one real Nokia SR Linux router (r3) and two Linux hosts. All three routers speak OSPF version 2 in area 0. **There is no Arista EOS, Juniper Junos or Cisco device in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/ospf-single-area/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start OSPF. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 host-1 ------- r1 (FRR) ------------------- r2 (FRR) ------- host-2
 10.10.1.10      \     10.10.12.0/30         /                10.10.2.10
   10.10.1.0/24   \                         /   10.10.2.0/24
     10.10.13.0/30 \                       / 10.10.23.0/30
                    +---- r3 (SR Linux) --+
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-1 | Linux host, 10.10.1.10/24, route to 10.0.0.0/8 via r1 (10.10.1.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router, router ID 10.10.255.1: eth1 10.10.1.1/24 (host-1), eth2 10.10.12.1/30 (r2), eth3 10.10.13.1/30 (r3) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then type `vtysh` |
| r2 | FRR router, router ID 10.10.255.2: eth1 10.10.2.1/24 (host-2), eth2 10.10.12.2/30 (r1), eth3 10.10.23.1/30 (r3) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| r3 | SR Linux router, router ID 10.10.255.3: ethernet-1/1 10.10.13.2/30 (r1), ethernet-1/2 10.10.23.2/30 (r2) | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| host-2 | Linux host, 10.10.2.10/24, route to 10.0.0.0/8 via r2 (10.10.2.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

Every router link is a point-to-point OSPF link with cost 10, so the direct path r1 - r2 costs 20 to host-2's LAN and the backup path r1 - r3 - r2 costs 30. **The hello and dead intervals are shortened to 1 and 4 seconds** (the usual values on these links are 10 and 40 seconds), so the lab reacts within seconds. The host LANs are **passive**: OSPF advertises them but does not look for neighbours there.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r3 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `ospf-single-area.clab.yml` - the lab drawing.
- `configs/r1-frr.conf`, `configs/r2-frr.conf` - the FRR routers: addresses, `ip ospf area 0` on each interface, point-to-point links with hello 1 and dead 4, passive host LANs, the router ID.
- `configs/r3-srl.cli` - r3 (SR Linux): addresses, the port and IP MTU (see Troubleshooting 3), and OSPF instance `main` in area 0.0.0.0 with the same timers and cost 10.
- `changes/` - small FRR changes for the exercises, applied to r1 with `docker exec -i ... vtysh < changes/<file>`: `r1-cost-100.vtysh` and `r1-cost-undo.vtysh`, `r1-hello-mismatch.vtysh` and `r1-hello-undo.vtysh`.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `ospf-single-area.drawio` and `ospf-single-area.png` - the prepared diagram.
- `captures/` - three sample captures, recorded from this lab: `ospf-1-adjacency.pcapng`, `ospf-2-cost-change.pcapng`, `ospf-3-hello-mismatch.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `ospf-single-area` > right-click `ospf-single-area.clab.yml` > **Deploy**. Wait for the green dots, then check r1's neighbours in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf neighbor"
  ```
  Two lines, both `Full/-`: 10.10.255.2 on eth2 and 10.10.255.3 on eth3. If the 10.10.255.3 line is missing, SR Linux is still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/ospf-single-area
  ```
  ```
  containerlab redeploy -c -t ospf-single-area.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (r1, r2: `vtysh`) | SR Linux (r3: `sr_cli`) |
|---|---|---|
| Neighbours | `show ip ospf neighbor` | `show network-instance default protocols ospf neighbor` |
| OSPF interfaces, timers, cost | `show ip ospf interface eth2` | `show network-instance default protocols ospf interface` |
| The map (link-state database) | `show ip ospf database` | `info from state network-instance default protocols ospf instance main area 0.0.0.0` (look for `lsa-totals`) |
| Routes OSPF installed | `show ip route ospf` | `show network-instance default ipv4 route` (type `ospfv2`) |
| Wireshark filter | `ospf` | `ospf` |

Junos and EOS are not part of this lab. On them and on Cisco devices the same ideas carry the same names: neighbours (adjacencies), the link-state database, interface cost, hello and dead intervals, passive interfaces.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name (on r1 and r2, type `vtysh` first).

**1. Neighbours.**
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf neighbor"
```
```
Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
10.10.255.3       1 Full/-          4m20s              3.684s 10.10.13.2      eth3:10.10.13.1                      0     0     0
10.10.255.2       1 Full/-          30.909s            3.106s 10.10.12.2      eth2:10.10.12.1                      0     0     0
```
`Full` means the two routers have exchanged their whole maps. The `/-` means no designated router: on a point-to-point link there is nothing to elect. **Dead Time** counts down from 4 seconds and starts again at every hello (one per second). The neighbour is named by its **router ID**, not by its address on the link. The same from the SR Linux side:
```
docker exec clab-ospf-single-area-r3 sr_cli "show network-instance default protocols ospf neighbor"
```
Two neighbours, 10.10.255.1 on `ethernet-1/1.0` and 10.10.255.2 on `ethernet-1/2.0`, both `full`. FRR and SR Linux build the same adjacency; only the words on screen differ.

**2. The map.**
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf database"
```
Three **router LSAs** (link-state advertisements), one from each router (`ADV Router` 10.10.255.1, .2 and .3). Every router in the area holds the same three. Look at the one r3 sent:
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf database router 10.10.255.3"
```
`Number of Links: 4`: for each of its two links, a point-to-point line to the neighbour's router ID and a **Stub Network** line for the /30 itself, each with `TOS 0 Metric: 10`. r3 told everybody what it is connected to and what each link costs; it did not send any routes.

**3. The route.** Each router runs the shortest-path calculation on the map:
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip route ospf"
```
```
O>* 10.10.2.0/24 [110/20] via 10.10.12.2, eth2, weight 1, 00:00:32
O>* 10.10.23.0/30 [110/20] via 10.10.12.2, eth2, weight 1, 00:00:32
  *                        via 10.10.13.2, eth3, weight 1, 00:00:32
```
`[110/20]`: distance 110 (OSPF), cost 20 (10 to r2, 10 across r2's LAN). host-2's LAN goes via r2; the path over r3 would cost 30. The r2 - r3 link 10.10.23.0/30 costs 20 either way, so r1 installs both next hops (equal-cost multipath). Check the path the packets take:
```
docker exec clab-ospf-single-area-host-1 traceroute -n -w 1 10.10.2.10
```
Three hops: 10.10.1.1 (r1), 10.10.12.2 (r2), 10.10.2.10 (host-2). On r3 the same routes show as type `ospfv2` with SR Linux's own preference value 10:
```
docker exec clab-ospf-single-area-r3 sr_cli "show network-instance default ipv4 route"
```
r3 lists one next hop for 10.10.12.0/30 even though both of its paths cost 20: SR Linux uses one path unless you allow more (`max-ecmp-paths 1` by default).

**4. Passive host LANs.**
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf interface eth1"
```
`No Hellos (Passive interface)` and `Neighbor Count is 0`: eth1 is in OSPF (so 10.10.1.0/24 is in r1's LSA and everybody learns it), but r1 sends no hellos to host-1. Compare `show ip ospf interface eth2`: `Network Type POINTOPOINT, Cost: 10`, `Hello 1s, Dead 4s`, `Neighbor Count is 1`.

**5. Change a cost.** Make r1's link to r2 expensive (cost 100 instead of 10):
```
cd ~/labs-main/containerlab/labs/ospf-single-area
```
```
docker exec -i clab-ospf-single-area-r1 vtysh < changes/r1-cost-100.vtysh
```
(`vtysh` echoes the four lines; `No changes found to be committed!` after `interface eth2` is normal.) A few seconds later:
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip route 10.10.2.0/24"
```
```
  Known via "ospf", distance 110, metric 30, best
  * 10.10.13.2, via eth3, weight 1
```
r1 now goes via r3 (10 + 10 + 10 = 30, cheaper than 100 + 10). Nothing was broken; the cost alone moved the path. `traceroute` from host-1 shows four hops: 10.10.1.1, 10.10.13.2 (r3), 10.10.12.2, 10.10.2.10. The third hop is r2, answering from the address of the interface it sends the reply out of (towards r1), which is why it shows 10.10.12.2 and not 10.10.23.1. Note also that only r1's outgoing cost changed: r2 still sends replies to host-1 straight over the r1 - r2 link. Put the cost back:
```
docker exec -i clab-ospf-single-area-r1 vtysh < changes/r1-cost-undo.vtysh
```
`show ip route 10.10.2.0/24` says `metric 20` via 10.10.12.2 again.

**6. A link fails.** Take r2's end of the r1 - r2 link down:
```
docker exec clab-ospf-single-area-r2 ip link set eth2 down
```
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf neighbor"
```
Only 10.10.255.3 is left. `show ip route 10.10.2.0/24` on r1 says `metric 30` via 10.10.13.2, and `docker exec clab-ospf-single-area-host-1 ping -c 2 10.10.2.10` still gets two replies: the remaining path took over (host-1, r1, r3, r2, host-2). Here r1 sees its port lose the link at once; if the link failed without that signal, r1 would wait for the dead interval (4 seconds in this lab). Bring it back:
```
docker exec clab-ospf-single-area-r2 ip link set eth2 up
```
A few seconds later r1 lists both neighbours `Full` again and goes back to r2.

**7. The ping works, OSPF does not.** Change r1's hello interval on eth2 to 2 seconds (r2 keeps 1):
```
docker exec -i clab-ospf-single-area-r1 vtysh < changes/r1-hello-mismatch.vtysh
```
Wait about 5 seconds, then:
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf neighbor"
```
```
docker exec clab-ospf-single-area-r1 ping -c 2 10.10.12.2
```
The neighbour 10.10.255.2 is gone, and it stays gone, but the ping on the same cable gets two replies. The cable is fine. Two routers only become neighbours when their hellos agree on the area, the hello and dead intervals and the network type (and on these links the MTU). Compare the timers:
```
docker exec clab-ospf-single-area-r1 vtysh -c "show ip ospf interface eth2"
```
```
docker exec clab-ospf-single-area-r2 vtysh -c "show ip ospf interface eth2"
```
r1 says `Hello 2s, Dead 4s`, r2 says `Hello 1s, Dead 4s`, and both say `Neighbor Count is 0`. Meanwhile host-1 still reaches host-2, over r3: `docker exec clab-ospf-single-area-host-1 traceroute -n -w 1 10.10.2.10` shows 10.10.1.1, 10.10.13.2, 10.10.23.1, 10.10.2.10 (this time r2 answers from 10.10.23.1, because without the adjacency its replies to host-1 also go via r3). Fix it:
```
docker exec -i clab-ospf-single-area-r1 vtysh < changes/r1-hello-undo.vtysh
```
Within a few seconds r1 lists 10.10.255.2 as `Full` again.

**8. Watch it on the wire.** In Ubuntu's Terminal app, capture r1's link to r2 for 25 seconds:
```
sudo containerlab capture --name ospf-single-area --target r1:eth2 --duration 25s -w - > "$HOME/neo-ospf.pcapng"
```
Within the 25 seconds, take r2's port down and up again in VS Code's terminal:
```
docker exec clab-ospf-single-area-r2 ip link set eth2 down
```
```
docker exec clab-ospf-single-area-r2 ip link set eth2 up
```
Open the file in Wireshark with the filter `ospf`. Compare with the sample `captures/ospf-1-adjacency.pcapng`: Hello packets from 10.10.12.1 and 10.10.12.2 to 224.0.0.5 once a second; after the bounce (about 7 seconds in) the two routers rebuild the adjacency: **DB Description** (frames 13 to 16 and 18, the list of LSAs each has), **LS Request** (frame 17), **LS Update** (frames 19 and 20, the LSAs themselves) and **LS Acknowledge** (frame 32). Click a Hello and open **Open Shortest Path First**: **Hello Interval** 1, **Router Dead Interval** 4, the area 0.0.0.0 and the router ID.

## Sample captures

Open them in Wireshark with File > Open and filter on `ospf`. The interface name of each frame (for example `r1:eth3`) is in the frame details.

| File | Frames | Cables | What it shows |
|---|---|---|---|
| `ospf-1-adjacency.pcapng` | 76 | r1:eth2 | Hellos once a second; r2's port goes down and up, then DB Description, LS Request, LS Update and LS Acknowledge rebuild the adjacency |
| `ospf-2-cost-change.pcapng` | 89 | r1:eth2 and r1:eth3 | r1's cost to r2 goes to 100 (frames 18 and 19: r1 floods its new router LSA on both links, acknowledged in frames 24 and 25) and back to 10 (frames 38 and 39) |
| `ospf-3-hello-mismatch.pcapng` | 32 | r1:eth2 | r1 switches to a hello every 2 seconds (from about 3.6 s), r2 keeps one per second; no DB Description follows, the adjacency stays down |

The other frames are background traffic (ARP, IPv6 and multicast group reports, and LLDP from r3); the filter `ospf` hides them.

## What this lab does not do

- One area only (area 0). No area border routers, no summarisation, no external routes.
- No designated router election: every router link is point-to-point. On a shared Ethernet segment OSPF elects one, and the neighbour state shows `DR` or `Backup`.
- No authentication and no OSPFv3 (IPv6).
- Timers are shortened (hello 1, dead 4) so the lab reacts quickly.
- A veth pair carries each link; there is no real switch or cable.

## Troubleshooting

1. **r1 has only one neighbour (10.10.255.2) after Deploy.** SR Linux (r3) takes 1 to 2 minutes to start OSPF. Wait and run the check in **Start** again.
2. **A change command says `No such file or directory`, or it hangs and nothing changes.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/ospf-single-area`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`: without `-i`, `vtysh` never gets the file and just waits (press Ctrl+C).
3. **r3 never becomes a neighbour, and `docker exec clab-ospf-single-area-r3 sr_cli "show interface ethernet-1/1"` says `down, reason ip-mtu-too-large`.** SR Linux needs its port MTU to be at least the IP MTU plus 14 bytes of Ethernet header. `configs/r3-srl.cli` sets the ports to 1514 and the IP MTU to 1500 for that reason; if you edited it, put those lines back and redeploy. OSPF also compares the MTU in its Database Description packets, so both ends of a link need the same IP MTU.
4. **After exercise 5, 6 or 7 a path or neighbour did not come back.** Run the matching undo (`r1-cost-undo.vtysh`, `ip link set eth2 up`, `r1-hello-undo.vtysh`), or reset the lab with `containerlab redeploy -c -t ospf-single-area.clab.yml`.
5. **`sr_cli` says a command is unknown.** SR Linux is picky about spaces; copy the command exactly, or open r3 with Attach Shell and press the question mark key for the options.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/ospf-single-area
```
```
containerlab destroy --cleanup -t ospf-single-area.clab.yml
```
`--cleanup` also removes the generated `clab-ospf-single-area` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-ospf-single-area` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/ospf-single-area/clab-ospf-single-area
```
Your capture files in your Home folder are not touched.
