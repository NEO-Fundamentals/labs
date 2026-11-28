# Lab: Multi-vendor OSPF adjacency

**Folder:** `labs/multivendor-ospf/`  **Lab file:** `multivendor-ospf.clab.yml`  **Lesson:** NEO-38 Multi-vendor OSPF adjacency  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs one real FRR router (r1), one real Nokia SR Linux router (r2) and two Linux hosts. The two routers speak OSPF version 2 to each other in area 0. **There is no Arista EOS, Juniper Junos or Cisco device in this lab.** The lesson shows Junos and EOS commands as text only.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-ospf/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start OSPF. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 host-1 ------- r1 (FRR) ------------------- r2 (SR Linux) ------- host-2
 10.38.1.10   eth1     eth2  10.38.12.0/30  ethernet-1/1   ethernet-1/2   10.38.2.10
   10.38.1.0/24                                                10.38.2.0/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-1 | Linux host, 10.38.1.10/24, route to 10.0.0.0/8 via r1 (10.38.1.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router, router ID 10.38.255.1: eth1 10.38.1.1/24 (host-1, passive), eth2 10.38.12.1/30 (r2) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then type `vtysh` |
| r2 | SR Linux router, router ID 10.38.255.2: ethernet-1/1 10.38.12.2/30 (r1), ethernet-1/2 10.38.2.1/24 (host-2, passive) | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| host-2 | Linux host, 10.38.2.10/24, route to 10.0.0.0/8 via r2 (10.38.2.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

The r1 - r2 link is a point-to-point OSPF link with cost 10 at both ends. **The timers are the usual ones: hello 10 seconds, dead 40 seconds**, so a neighbour that stops agreeing can take up to 40 seconds to disappear. The host LANs are **passive**: OSPF advertises them but does not look for neighbours there.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r2 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `multivendor-ospf.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1 (FRR): addresses, `ip ospf area 0` on each interface, point-to-point on eth2, passive eth1, the router ID, `log-adjacency-changes`, and a log file `/tmp/frr.log` inside the container.
- `configs/r2-srl.cli` - r2 (SR Linux): addresses, the port and IP MTU (see Troubleshooting 3), and OSPF instance `main` in area 0.0.0.0 with ethernet-1/1.0 point-to-point and ethernet-1/2.0 passive.
- `changes/` - the exercise changes. On r1 with `docker exec -i ... vtysh < changes/<file>`: `r1-hello-5.vtysh` and `r1-hello-undo.vtysh`. On r2 with `docker exec -i ... sr_cli < changes/<file>`: `r2-ipmtu-1400.cli` and `r2-ipmtu-undo.cli`.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about four minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `multivendor-ospf.drawio` and `multivendor-ospf.png` - the prepared diagram.
- `captures/` - three sample captures, recorded from this lab: `mvospf-1-adjacency.pcapng`, `mvospf-2-hello-mismatch.pcapng`, `mvospf-3-mtu-mismatch.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-ospf` > right-click `multivendor-ospf.clab.yml` > **Deploy**. Wait for the green dots, then check r1's neighbour in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-ospf-r1 vtysh -c "show ip ospf neighbor"
  ```
  One line, `10.38.255.2 ... Full/-` on eth2. If the line is missing, SR Linux is still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-ospf
  ```
  ```
  containerlab redeploy -c -t multivendor-ospf.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (r1: `vtysh`) | SR Linux (r2: `sr_cli`) |
|---|---|---|
| Neighbours and their state | `show ip ospf neighbor` | `show network-instance default protocols ospf neighbor` |
| OSPF interface, type, timers, cost | `show ip ospf interface eth2` | `show network-instance default protocols ospf interface ethernet-1/1.0 detail` |
| Routes OSPF installed | `show ip route ospf` | `show network-instance default ipv4 route` (type `ospfv2`) |
| Why packets were dropped | the log: `docker exec clab-multivendor-ospf-r1 tail /tmp/frr.log` | the counters in the `detail` output (`Bad Hello Int.`, `Discards`) |
| Wireshark filter | `ospf` | `ospf` |

Junos and EOS are not part of this lab; the lesson shows their commands as text. On them the same ideas carry the same names: neighbour state, interface type point-to-point, hello and dead intervals, the MTU in Database Description packets.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name (on r1, type `vtysh` first).

**1. One adjacency, two vendors.**
```
docker exec clab-multivendor-ospf-r1 vtysh -c "show ip ospf neighbor"
```
```
Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
10.38.255.2       1 Full/-          13.308s           32.158s 10.38.12.2      eth2:10.38.12.1                      0     0     0
```
`Full` means the two routers have exchanged their whole link-state databases. The `/-` means no designated router: on a point-to-point link there is nothing to elect. **Dead Time** counts down from 40 seconds and starts again at every hello (one every 10 seconds). The same adjacency from the SR Linux side:
```
docker exec clab-multivendor-ospf-r2 sr_cli "show network-instance default protocols ospf neighbor"
```
One row: `ethernet-1/1.0  10.38.255.1  full`. The neighbour is named by its **router ID** on both systems; only the words on screen differ.

**2. What must match.** Compare the two interfaces:
```
docker exec clab-multivendor-ospf-r1 vtysh -c "show ip ospf interface eth2"
```
```
docker exec clab-multivendor-ospf-r2 sr_cli "show network-instance default protocols ospf interface ethernet-1/1.0 detail"
```
FRR: `Area 0.0.0.0`, `Network Type POINTOPOINT, Cost: 10`, `Hello 10s, Dead 40s`, `MTU 1500 bytes`. SR Linux: `Area Id : 0.0.0.0`, `IF Type : point-to-point`, `Hello Intrvl : 10 sec`, `Rtr Dead Intrvl : 40 sec`, `Oper MTU : 1500`. The area, the hello and dead intervals and the network type must agree for the hellos to be accepted; the MTU must agree for the database exchange to finish.

**3. The route.**
```
docker exec clab-multivendor-ospf-r1 vtysh -c "show ip route ospf"
```
`O>* 10.38.2.0/24 [110/20] via 10.38.12.2, eth2`: distance 110, cost 20 (10 to r2, 10 across r2's LAN). On r2, `show network-instance default ipv4 route` lists `10.38.1.0/24  ospfv2  20  10` via 10.38.12.1: the same cost, and SR Linux's own preference value 10 for OSPF. `docker exec clab-multivendor-ospf-host-1 traceroute -n -w 1 10.38.2.10` shows 10.38.1.1, 10.38.12.2, 10.38.2.10.

**4. Hello timers that do not match.** Change r1's hello interval on eth2 to 5 seconds (r2 keeps 10):
```
cd ~/labs-main/containerlab/labs/multivendor-ospf
```
```
docker exec -i clab-multivendor-ospf-r1 vtysh < changes/r1-hello-5.vtysh
```
```
docker exec clab-multivendor-ospf-r1 vtysh -c "show ip ospf interface eth2"
```
r1 now says `Hello 5s, Dead 20s`: you only set the hello, and FRR made the dead interval four times the hello. Each router now drops the other's hellos. Watch the neighbour on both sides for up to 40 seconds (run the two neighbour commands from exercise 1 again): SR Linux drops r1 when its 40-second dead timer runs out, and FRR drops r2 at about the same time. Then:
```
docker exec clab-multivendor-ospf-r1 tail -3 /tmp/frr.log
```
`RouterDeadInterval mismatch on eth2:10.38.12.1 (expected 20, but received 40)`: FRR checks the dead interval first and names it. (The log uses the container's clock, UTC.) SR Linux counts instead of logging: in the `detail` output from exercise 2, `Bad Hello Int.` goes up by one for every hello from r1. The cable is fine: `docker exec clab-multivendor-ospf-r1 ping -c 2 10.38.12.2` gets two replies. But the route is gone, and `docker exec clab-multivendor-ospf-host-1 ping -c 2 -W 1 10.38.2.10` fails. Fix it:
```
docker exec -i clab-multivendor-ospf-r1 vtysh < changes/r1-hello-undo.vtysh
```
Within about 10 seconds both sides show `Full` again.

**5. Hellos agree, but it never reaches Full (the lesson's practice).** Lower r2's IP MTU on the link to 1400 (r1 keeps 1500), then bounce r1's port so the two routers start again:
```
docker exec -i clab-multivendor-ospf-r2 sr_cli < changes/r2-ipmtu-1400.cli
```
```
docker exec clab-multivendor-ospf-r1 ip link set eth2 down
```
```
docker exec clab-multivendor-ospf-r1 ip link set eth2 up
```
Wait about 30 seconds and look at r2's neighbour again: the state is `exstart`, and it stays there. The hellos agree, so the routers are neighbours, but r2 rejects r1's Database Description packets because they say MTU 1500 and r2 can only take 1400. r1's view changes between Exchange and nothing. SR Linux counts the rejects:
```
docker exec clab-multivendor-ospf-r2 sr_cli "info from state network-instance default protocols ospf instance main area 0.0.0.0 interface ethernet-1/1.0" | grep -E "mtu|adjacency-state|bad-mtu"
```
`mtu 1400`, `adjacency-state exstart`, and `bad-mtu` going up. Put the MTU back:
```
docker exec -i clab-multivendor-ospf-r2 sr_cli < changes/r2-ipmtu-undo.cli
```
Within about 10 seconds both sides show `Full` again.

**6. Watch it on the wire.** In Ubuntu's Terminal app, capture r1's link to r2 for 40 seconds:
```
sudo containerlab capture --name multivendor-ospf --target r1:eth2 --duration 40s -w - > "$HOME/neo-mvospf.pcapng"
```
Within the 40 seconds, bounce r1's port in VS Code's terminal (`ip link set eth2 down`, then `up`, as in exercise 5). Open the file in Wireshark with the filter `ospf` and compare with the samples below. Click a Hello and open **Open Shortest Path First**: **Hello Interval** 10, **Router Dead Interval** 40, the area and the router ID. Click a DB Description: **Interface MTU** 1500.

## Sample captures

Open them in Wireshark with File > Open and filter on `ospf`. All three are recorded on r1:eth2.

| File | Frames | What it shows |
|---|---|---|
| `mvospf-1-adjacency.pcapng` | 37 | Hellos every 10 s from 10.38.12.1 (FRR) and 10.38.12.2 (SR Linux); r1's port goes down and up, then frames 16 to 30 rebuild the adjacency: Hellos, DB Description (both say MTU 1500), LS Request, LS Update and LS Acknowledge |
| `mvospf-2-hello-mismatch.pcapng` | 20 | r1 sends a hello every 5 s with dead 20, r2 every 10 s with dead 40; no DB Description follows, the adjacency stays down |
| `mvospf-3-mtu-mismatch.pcapng` | 37 | after the bounce, r2's DB Description says MTU 1400 and r1's says 1500 (from frame 20); the same pair repeats every 5 s and the exchange never finishes |

The other frames are background traffic (ARP, IPv6 and multicast group reports, and LLDP from r2); the filter `ospf` hides them.

## What this lab does not do

- One link and one area (area 0). No designated router election: the link is point-to-point.
- No authentication and no OSPFv3 (IPv6).
- No Junos or EOS device; the lesson shows their commands as text only.
- A veth pair carries the link; there is no real switch or cable.

## Troubleshooting

1. **r1 has no neighbour after Deploy.** SR Linux (r2) takes 1 to 2 minutes to start OSPF. Wait and run the check in **Start** again.
2. **A change command says `No such file or directory`, or it hangs and nothing changes.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-ospf`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`: without `-i`, `vtysh` never gets the file and just waits (press Ctrl+C), and `sr_cli` says `Input not from a terminal/file/pipe`.
3. **r2 never becomes a neighbour, and `docker exec clab-multivendor-ospf-r2 sr_cli "show interface ethernet-1/1"` says `down, reason ip-mtu-too-large`.** SR Linux needs its port MTU to be at least the IP MTU plus 14 bytes of Ethernet header. `configs/r2-srl.cli` sets the port to 1514 and the IP MTU to 1500 for that reason; if you edited it, put those lines back and redeploy.
4. **After exercise 4 or 5 the neighbour did not come back.** Run the matching undo (`r1-hello-undo.vtysh`, `r2-ipmtu-undo.cli`), or reset the lab with `containerlab redeploy -c -t multivendor-ospf.clab.yml`.
5. **`/tmp/frr.log` is empty or missing.** The file starts when r1 starts; redeploy if you deleted it.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-ospf
```
```
containerlab destroy --cleanup -t multivendor-ospf.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-ospf` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-ospf` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-ospf/clab-multivendor-ospf
```
Your capture files in your Home folder are not touched.
