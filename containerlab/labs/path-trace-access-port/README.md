# Lab: Path trace: ARP, the MAC address table and the access port

**Folder:** `labs/path-trace-access-port/`  **Lab file:** `path-trace-access-port.clab.yml`  **Lesson:** NEO-25 Path trace: ARP, MAC tables, and the access port  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the last part of a path: from the gateway router to the switch port a host is plugged into. r1 is a Linux router, the gateway of two VLANs; sw is a Linux switch with **one Linux bridge per VLAN** (bridge `vlan10` and bridge `vlan20`), both in the NEO helper image `neo-tools`. ARP, MAC address learning and the ports are real Linux networking. You go from a host's IP address to its MAC address (r1's ARP table), from the MAC address to a switch port (sw's MAC address table), and check that port. Then you find two faults that `scripts/fault.sh` puts in place. A Cisco-style switch's commands for the same questions are listed as text to compare. No SR Linux in this lab.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** very small: five small Linux containers, about 5 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/path-trace-access-port/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
                         r1  (gateway: eth1 10.25.10.1 in VLAN 10, eth2 10.25.20.1 in VLAN 20)
                      eth1 |         | eth2
                      eth1 |         | eth5
                   sw  [ bridge vlan10: eth1 eth2 eth3 ]   [ bridge vlan20: eth4 eth5 ]
                         eth2 |      eth3 |                     eth4 |
                        host-a       host-b                     host-c
                     10.25.10.11   10.25.10.12                10.25.20.13
                 02:00:00:25:10:11  02:00:00:25:10:12      02:00:00:25:20:13
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| r1 | Linux router, the gateway of both VLANs: eth1 = **10.25.10.1/24** (VLAN 10, MAC 02:00:00:25:10:01), eth2 = **10.25.20.1/24** (VLAN 20, MAC 02:00:00:25:20:01) | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| sw | Linux switch. Bridge `vlan10`: ports eth1 (uplink to r1), eth2, eth3. Bridge `vlan20`: ports eth4, eth5 (uplink to r1). eth2, eth3 and eth4 are **access ports**: each belongs to one VLAN, and a host is plugged into it | same | Attach Shell |
| host-a, host-b | 10.25.10.11 and 10.25.10.12 in VLAN 10, gateway 10.25.10.1 | same | Attach Shell |
| host-c | 10.25.20.13 in VLAN 20, gateway 10.25.20.1 | same | Attach Shell |

Every lab MAC address is set by hand (`02:00:00:25:...`, a locally administered address), so the tables are easy to read. All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**One bridge per VLAN.** A switch keeps a VLAN number on each port and one MAC address table with a VLAN column. This Linux switch does the same job with one bridge per VLAN: a port's VLAN is the bridge it belongs to (`master vlan10`), and each bridge has its own MAC address table. r1 has one link per VLAN; one link that carries both VLANs (a trunk) is the subject of the VLAN lesson (NEO-07).

## Files

- `path-trace-access-port.clab.yml` - the lab drawing. Addresses, MAC addresses, the bridges and their ports are set by each node's `exec` lines.
- `scripts/fault.sh` - puts the fault of an exercise in place: `bash scripts/fault.sh 1` (exercise 4), `2` (exercise 5). Try each exercise before you read how the fault is made.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes under a minute, puts each fault in place and undoes it, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `path-trace-access-port.drawio` and `path-trace-access-port.png` - the prepared diagram.
- `captures/` - three sample captures: `ap-1-arp.pcapng`, `ap-2-wrong-vlan.pcapng`, `ap-3-port-down.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `path-trace-access-port` > right-click `path-trace-access-port.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-path-trace-access-port-r1 sh -c 'for a in 10.25.10.11 10.25.10.12 10.25.20.13; do ping -c 1 -W 1 $a | grep -o "1 received"; done'
  ```
  It prints `1 received` three times: r1 reaches all three hosts.
- **Reset to the lesson start** (sw's ports as at deploy): do this whenever a fault is left over.
  ```
  cd ~/labs-main/containerlab/labs/path-trace-access-port
  ```
  ```
  containerlab redeploy -c -t path-trace-access-port.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Cisco-style switch or router (text only) | Here |
|---|---|---|
| Which MAC address has this IP address? (ARP table) | `show ip arp 10.25.10.12` | `docker exec clab-path-trace-access-port-r1 ip neigh show 10.25.10.12` |
| Forget an ARP entry, to ask again | `clear arp-cache` | `docker exec clab-path-trace-access-port-r1 ip neigh flush to 10.25.10.12` |
| Which port has this MAC address? (MAC address table) | `show mac address-table address 0200.0025.1012` | `docker exec clab-path-trace-access-port-sw sh -c 'bridge fdb show \| grep 02:00:00:25:10:12'` |
| Which VLAN is a port in, and does it forward? | `show interfaces Gi1/0/3 switchport`, `show interfaces status` | `docker exec clab-path-trace-access-port-sw bridge link show dev eth3` |
| Is the port up? | `show interfaces Gi1/0/3` | `docker exec clab-path-trace-access-port-sw ip -br link show eth3` |

The method: **IP address -> MAC address -> switch port**. The gateway's ARP table turns the IP address into a MAC address; the switch's MAC address table turns the MAC address into a port; the port's settings say whether the host can be reached through it.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/path-trace-access-port`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. From IP address to MAC address: r1's ARP table.** A user at 10.25.10.12 calls. Which device is it, physically? Start at the gateway:
```
docker exec clab-path-trace-access-port-r1 ping -c 1 -W 1 10.25.10.12
```
```
docker exec clab-path-trace-access-port-r1 ip neigh show 10.25.10.12
```
r1 knows the address: `10.25.10.12 dev eth1 lladdr 02:00:00:25:10:12 REACHABLE` (or `DELAY`; both mean a fresh entry). To send the ping, r1 asked "who has 10.25.10.12?" as a broadcast on eth1 (VLAN 10), and the host answered with its MAC address. Now you know the device's MAC address, 02:00:00:25:10:12, and that it is behind r1's eth1, in VLAN 10. (Sample `ap-1-arp.pcapng`, recorded on host-b's switch port: r1's ARP request to all, the host's answer, then the pings.)

**2. From MAC address to switch port: sw's MAC address table.**
```
docker exec clab-path-trace-access-port-sw sh -c 'bridge fdb show | grep 02:00:00:25:10:12'
```
```
docker exec clab-path-trace-access-port-sw sh -c 'bridge fdb show br vlan10 | grep -v permanent'
```
The first line answers the question: `02:00:00:25:10:12 dev eth3 master vlan10`: the switch has seen that MAC address as the source of frames arriving on **port eth3**, in VLAN 10. The whole VLAN 10 table (the second command) also lists r1's MAC address `02:00:00:25:10:01` on eth1 (the uplink toward the gateway) and any other host that sent something recently: a switch learns an address from the frames it receives and forgets it after 5 minutes without one (here host-a may be missing until it sends something). The `permanent` lines are the switch's own addresses.

**3. The access port.**
```
docker exec clab-path-trace-access-port-sw bridge link show dev eth3
```
```
docker exec clab-path-trace-access-port-sw ip -br link show eth3
```
```
docker exec clab-path-trace-access-port-host-b ip -br link show eth1
```
Port eth3 is `master vlan10` (an access port in VLAN 10) and `state forwarding`; the link is `UP`. On the other end of that cable is host-b, with MAC address `02:00:00:25:10:12`. The path is complete: 10.25.10.12 -> 02:00:00:25:10:12 -> sw port eth3, VLAN 10, up and forwarding -> host-b. On a real network this is where you would read the port's description or follow the cable to a wall socket.

**4. "host-b cannot reach anything."** Put the fault in place:
```
bash scripts/fault.sh 1
```
```
docker exec clab-path-trace-access-port-host-b ping -c 2 -W 1 10.25.10.1
```
```
docker exec clab-path-trace-access-port-r1 ip neigh flush to 10.25.10.12
```
```
docker exec clab-path-trace-access-port-r1 ping -c 2 -W 1 10.25.10.12
```
```
docker exec clab-path-trace-access-port-r1 ip neigh show 10.25.10.12
```
```
docker exec clab-path-trace-access-port-sw sh -c 'bridge fdb show | grep 02:00:00:25:10:12'
```
```
docker exec clab-path-trace-access-port-sw bridge link show dev eth3
```
host-b cannot ping its gateway, and r1 cannot ping host-b. Once r1 has forgotten its old entry (`flush`; an ARP table can show an old answer for a while), its question "who has 10.25.10.12?" gets no answer: the entry is `INCOMPLETE` (or `FAILED`). The switch still knows host-b's MAC address on port eth3, but now with `master vlan20`: the port was moved to **VLAN 20**. host-b is plugged in, the link is up, and its frames reach the switch, but in the wrong VLAN, where neither its gateway nor its neighbours are. Put the port back into VLAN 10 (Cisco-style: `switchport access vlan 10`):
```
docker exec clab-path-trace-access-port-sw ip link set eth3 master vlan10
```
```
docker exec clab-path-trace-access-port-host-b ping -c 2 -W 1 10.25.10.1
```
2 of 2 again, or 1 of 2: the first ping can be lost while host-b renews its ARP entry for the gateway, which had failed; run it again and it is 2 of 2. (Sample `ap-2-wrong-vlan.pcapng`, recorded on both of r1's links at sw: r1's requests for 10.25.10.12 go out in VLAN 10 unanswered, and host-b's requests for its gateway 10.25.10.1 arrive on r1's **VLAN 20** link, where r1 does not answer for an address of VLAN 10.)

**5. "host-a is gone."**
```
bash scripts/fault.sh 2
```
```
docker exec clab-path-trace-access-port-r1 ip neigh flush to 10.25.10.11
```
```
docker exec clab-path-trace-access-port-r1 ping -c 2 -W 1 10.25.10.11
```
```
docker exec clab-path-trace-access-port-sw sh -c 'bridge fdb show | grep 02:00:00:25:10:11; echo "found: $?"'
```
```
docker exec clab-path-trace-access-port-sw bridge link show dev eth2
```
```
docker exec clab-path-trace-access-port-host-a ip -br link show eth1
```
r1's ARP question gets no answer, and this time the switch has **no** entry for host-a's MAC address at all (`found: 1`): a port that goes down loses the addresses learned on it. Without the MAC address in the table, find the port from your records (here: eth2, host-a's port) and look at it: `state disabled`, and its flags lack `UP`: the port was **shut down** on the switch (Cisco-style: `shutdown`). host-a's own side says `DOWN` with `NO-CARRIER`: from the host it looks exactly like an unplugged cable. Bring the port up again (Cisco-style: `no shutdown`), wait 2 seconds, and ping:
```
docker exec clab-path-trace-access-port-sw ip link set eth2 up
```
```
docker exec clab-path-trace-access-port-r1 ping -c 2 -W 1 10.25.10.11
```
2 of 2. (Sample `ap-3-port-down.pcapng`, recorded on r1's VLAN 10 link at sw: three ARP requests for 10.25.10.11, none answered.)

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open. The display filter `arp` shows only the ARP requests and answers.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `ap-1-arp.pcapng` | sw:eth3 (host-b's port) | 6 | r1 (02:00:00:25:10:01) asks "Who has 10.25.10.12?" to all (Broadcast), host-b answers "10.25.10.12 is at 02:00:00:25:10:12", then two pings and their replies |
| `ap-2-wrong-vlan.pcapng` | sw:eth1 and sw:eth5 (r1's VLAN 10 and VLAN 20 links) | 6 | exercise 4: host-b's "Who has 10.25.10.1?" on the **VLAN 20** link (eth5), and r1's "Who has 10.25.10.12?" on the VLAN 10 link (eth1); no answers (Wireshark: the `frame.interface_name` field tells the two links apart) |
| `ap-3-port-down.pcapng` | sw:eth1 (r1's VLAN 10 link) | 3 | exercise 5: three "Who has 10.25.10.11?" requests from r1, no answer |

## What this lab does not do

- No 802.1Q tags and no trunk: one bridge per VLAN and one router link per VLAN (trunks are in NEO-07 `vlans-trunks` and NEO-35 `multivendor-access-trunk`). A real switch shows the VLAN as a column of one MAC address table; here it is the bridge name.
- No Cisco or other vendor switch: the Cisco-style commands are text to compare.
- The faults are made by `scripts/fault.sh`, not by real outages. A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start prints fewer than three `1 received`.** A fault is still in place: reset the lab.
2. **Exercise 2 shows no line for 02:00:00:25:10:12.** The switch forgets an address after 5 minutes of silence. Run exercise 1's ping again, then exercise 2.
3. **Exercise 4: r1's entry is still `REACHABLE`.** Run the `flush` command just before the ping, as listed.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/path-trace-access-port
```
```
containerlab destroy --cleanup -t path-trace-access-port.clab.yml
```
`--cleanup` also removes the generated `clab-path-trace-access-port` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-path-trace-access-port` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/path-trace-access-port/clab-path-trace-access-port
```
Your capture files in your Home folder are not touched.

