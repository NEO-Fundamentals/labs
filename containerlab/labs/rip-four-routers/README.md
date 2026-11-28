# Lab: RIP, distance-vector routing and hop counts

**Folder:** `labs/rip-four-routers/`  **Lab file:** `rip-four-routers.clab.yml`  **Lesson:** NEO-47 RIP: Distance-Vector Routing, Hop Counts, and Why OSPF Replaced It  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs four real FRR routers speaking RIP version 2, two Linux hosts and one Linux bridge (`mid`) that stands in the middle of one cable so you can break that cable without either router noticing. All routers are FRR because SR Linux does not support RIP. **There is no Arista EOS, Juniper Junos or Cisco device in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/rip-four-routers/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes a few minutes (downloads); later Deploys take under a minute. **Then wait up to one more minute** for RIP to spread every route. Exercise 5 takes about four minutes of waiting, because that is how slow RIP is.

## What this lab builds

```
 host-a ------ r1 ---------------- r2
 10.10.0.10     |  172.16.12.0/30   |
  10.10.0.0/24  | 172.16.13.0/30    | 172.16.23.0/30
               mid (bridge)         |
                |                   |
                +------------------ r3 ------------- r4 ------ host-d
                                      172.16.34.0/30   10.40.0.0/24  10.40.0.10
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux host, 10.10.0.10/24, routes to 10.0.0.0/8 and 172.16.0.0/16 via r1 (10.10.0.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router: eth1 10.10.0.1/24 (host-a), eth2 172.16.12.1/30 (r2), eth3 172.16.13.1/30 (to r3, through mid) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then type `vtysh` |
| r2 | FRR router: eth1 172.16.12.2/30 (r1), eth2 172.16.23.1/30 (r3) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| mid | A plain Linux bridge (`br0`) joining its eth1 (r1's cable) and eth2 (r3's cable). It has no address and does not route; it is "the cable" between r1 and r3 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| r3 | FRR router: eth1 172.16.13.2/30 (to r1, through mid), eth2 172.16.23.2/30 (r2), eth3 172.16.34.1/30 (r4) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| r4 | FRR router: eth1 172.16.34.2/30 (r3), eth2 10.40.0.1/24 (host-d) | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| host-d | Linux host, 10.40.0.10/24, routes to 10.0.0.0/8 and 172.16.0.0/16 via r4 (10.40.0.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

r1 has two ways to host-d's LAN: r1 - r3 - r4 (3 hops) and r1 - r2 - r3 - r4 (4 hops). RIP counts hops and picks the smaller number. RIP's timers are the standard ones (an update every 30 seconds, a route times out after 180 seconds without news); nothing is shortened.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `rip-four-routers.clab.yml` - the lab drawing, including the bridge in `mid`.
- `configs/r1-frr.conf` to `configs/r4-frr.conf` - each router's addresses and `router rip` with `version 2` and the networks it runs RIP on. r2 and r3 list only `172.16.0.0/16` (their own links); r1 and r4 also list `10.0.0.0/8` for their host LAN.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it waits for RIP, then takes about eight minutes (the silent failure needs RIP's 180-second timeout), puts the lab back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `rip-four-routers.drawio` and `rip-four-routers.png` - the prepared diagram.
- `captures/` - three sample captures, recorded from this lab: `rip-1-steady.pcapng`, `rip-2-silent-failure.pcapng`, `rip-3-link-down-poison.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `rip-four-routers` > right-click `rip-four-routers.clab.yml` > **Deploy**. Wait for the green dots, then check r1's route to host-d's LAN in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-rip-four-routers-r1 vtysh -c "show ip route 10.40.0.0/24"
  ```
  It says `Known via "rip"`, `metric 3` and `* 172.16.13.2, via eth3`. If it says `% Network not in table`, RIP has not spread the route yet: wait 30 seconds and run it again.
- **Reset to the lesson start:**
  ```
  cd ~/labs-main/containerlab/labs/rip-four-routers
  ```
  ```
  containerlab redeploy -c -t rip-four-routers.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (`vtysh`) | Linux hosts |
|---|---|---|
| The RIP table (every route RIP knows, with its metric and age) | `show ip rip` | - |
| Timers, versions, who sent updates | `show ip rip status` | - |
| Routes RIP put in the routing table | `show ip route rip` | `ip route` |
| The path | - | `traceroute -n -w 1 10.40.0.10` |
| Wireshark filter | `rip` (or `ip.dst == 224.0.0.9`) | |

Junos and EOS are not part of this lab. On Cisco devices the commands are close to FRR's (`show ip rip database`, `show ip protocols`). RIP is rare in new networks; this lab is about how distance-vector routing behaves.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name (on the routers, type `vtysh` first).

**1. The RIP table.**
```
docker exec clab-rip-four-routers-r1 vtysh -c "show ip rip"
```
```
     Network            Next Hop         Metric From            Tag Time
C(i) 10.10.0.0/24       0.0.0.0               1 self              0
R(n) 10.40.0.0/24       172.16.13.2           3 172.16.13.2       0 02:56
C(i) 172.16.12.0/30     0.0.0.0               1 self              0
C(i) 172.16.13.0/30     0.0.0.0               1 self              0
R(n) 172.16.23.0/30     172.16.12.2           2 172.16.12.2       0 02:59
R(n) 172.16.34.0/30     172.16.13.2           2 172.16.13.2       0 02:56
```
`C(i)` are r1's own networks (metric 1). `R(n)` are learned from a neighbour. host-d's LAN `10.40.0.0/24` has **metric 3** via r3: r4 has the LAN at metric 1, r3 adds one hop (2), r1 adds one more (3). **Time** counts down from 3:00 and starts again at every update from that neighbour; if it reaches zero, the route times out. r2 also offers 10.40.0.0/24, but at metric 3 from r2's view, which makes 4 for r1; RIP keeps only the best.

**2. From the table to the path.**
```
docker exec clab-rip-four-routers-r1 vtysh -c "show ip route rip"
```
`R>* 10.40.0.0/24 [120/3] via 172.16.13.2, eth3`: distance 120 (RIP), metric 3. Follow it:
```
docker exec clab-rip-four-routers-host-a traceroute -n -w 1 10.40.0.10
```
Four lines: 10.10.0.1 (r1), 172.16.13.2 (r3), 172.16.34.2 (r4), 10.40.0.10 (host-d). `mid` does not show up: a bridge forwards frames and does not count as a hop.

**3. The timers.**
```
docker exec clab-rip-four-routers-r1 vtysh -c "show ip rip status"
```
`Sending updates every 30 seconds with +/-50%` (the jitter keeps routers from sending at the same moment), `Timeout after 180 seconds, garbage collect after 120 seconds`, `send version 2, receive version 2`, and under **Routing Information Sources** the two neighbours r1 hears from, 172.16.12.2 (r2) and 172.16.13.2 (r3), with the time since their last update.

**4. Updates on the wire, and split horizon.** In Ubuntu's Terminal app, capture r1's link to r2 for 70 seconds:
```
sudo containerlab capture --name rip-four-routers --target r1:eth2 --duration 70s -w - > "$HOME/neo-rip.pcapng"
```
Open it in Wireshark with the filter `rip`, or open the sample `captures/rip-1-steady.pcapng` (4 frames). Each frame is a whole RIP table sent to 224.0.0.9 (UDP port 520), about every 30 seconds. Open **Routing Information Protocol** in frame 1 (from r2, 172.16.12.2): 10.40.0.0 metric 3, 172.16.13.0 metric 2, 172.16.23.0 metric 1, 172.16.34.0 metric 2. **10.10.0.0 is missing**: r2 learned it from r1, so it does not tell r1 about it. That is **split horizon**: never advertise a route back out of the interface you learned it on. Frame 2 (from r1) is the mirror image: no 172.16.23.0, which r1 learned from r2.

**5. A silent failure.** Switch the bridge in the r1 - r3 cable off. Both routers keep their ports up; frames just stop getting through, as with a faulty box in the middle:
```
docker exec clab-rip-four-routers-mid ip link set br0 down
```
Right away, `docker exec clab-rip-four-routers-host-a ping -c 2 -W 1 10.40.0.10` loses both packets, without any error message. r1 still believes the old route:
```
docker exec clab-rip-four-routers-r1 vtysh -c "show ip rip"
```
`10.40.0.0/24` is still metric 3 via 172.16.13.2, and its **Time** keeps counting down because no updates arrive. Run the command every 30 seconds or so. When the time runs out (180 seconds after the last update r3 got through), r1 marks the route metric 16 (unreachable), tells r2, and at r2's next update takes the 4-hop path: `10.40.0.0/24  172.16.12.2  4`. **On the box it took 170 to 185 seconds** from switching the bridge off until r1 used r2 (the lesson measured 189 seconds); your time will be about three minutes too, because it depends on when the last update got through and on the jitter. **The ping needs a little longer:** r3 has the same problem in the other direction and must time out its route back to host-a via r1 too, then take r2's offer. In one walk on the box r1 used r2 after 178 seconds and host-a's ping worked again after 215 seconds. Once it works:
```
docker exec clab-rip-four-routers-host-a traceroute -n -w 1 10.40.0.10
```
Five lines: 10.10.0.1, 172.16.12.2 (r2), 172.16.23.2 (r3), 172.16.34.2, 10.40.0.10. Three minutes without traffic is why RIP is not used where fast recovery matters. Switch the bridge back on:
```
docker exec clab-rip-four-routers-mid ip link set br0 up
```
Within about 30 seconds r1 is back on metric 3 via 172.16.13.2. The sample `captures/rip-2-silent-failure.pcapng` (r1's two links, 260 seconds) shows it from r1's side: r1 keeps sending its updates into the dead cable on eth3, nothing comes back, then frame 17 is r1's triggered update on eth2 with 10.40.0.0 at **metric 16**, frame 18 is r2's regular update, and in frame 19 r1 already offers 10.40.0.0 at metric 4 (via r2) on eth3.

**6. A cable that is unplugged.** This time both ends notice: take both ports of `mid` down, as if the cable was pulled out (r1's eth3 and r3's eth1 lose their link):
```
docker exec clab-rip-four-routers-mid sh -c "ip link set eth1 down; ip link set eth2 down"
```
```
docker exec clab-rip-four-routers-r1 vtysh -c "show ip rip"
```
At once `10.40.0.0/24` and `172.16.34.0/30` show **metric 16**, and so does r1's own `172.16.13.0/30`. r1 sends this to r2 straight away as a **triggered update** (it does not wait for the 30-second timer). Until r2's next regular update, r1 has no path, and a ping from host-a gets `Destination Net Unreachable` from 10.10.0.1. Within 30 seconds (18 seconds in the sample and in the lesson) r1 uses `10.40.0.0/24  172.16.12.2  4` and the ping works again. Plug the cable back in:
```
docker exec clab-rip-four-routers-mid sh -c "ip link set eth1 up; ip link set eth2 up"
```
The sample `captures/rip-3-link-down-poison.pcapng` (r1:eth2, 40 seconds, 6 frames): frame 2 is r1's triggered update with 10.40.0.0, 172.16.13.0 and 172.16.34.0 all at metric 16, and frame 5 is r2's update at 18 seconds that gives r1 the new path.

## Sample captures

Open them in Wireshark with File > Open and filter on `rip`. The interface name of each frame (for example `r1:eth3`) is in the frame details.

| File | Frames | Cables | What it shows |
|---|---|---|---|
| `rip-1-steady.pcapng` | 4 | r1:eth2 | 70 seconds of regular updates from r1 and r2 to 224.0.0.9; split horizon in both directions |
| `rip-2-silent-failure.pcapng` | 28 | r1:eth2 and r1:eth3 | The bridge is switched off near the start; r1 hears nothing from r3 for about 150 seconds, then poisons 10.40.0.0 (metric 16, frame 17) and offers it at metric 4 via r2 (frame 19) |
| `rip-3-link-down-poison.pcapng` | 6 | r1:eth2 | Cable unplugged: an immediate triggered update with metric 16, then r2's update gives the 4-hop path after 18 seconds |

The few other frames in `rip-2` are IPv6 background traffic; the filter `rip` hides them.

## What this lab does not do

- RIP version 2 only (no RIPng for IPv6), no authentication, no route filters or offsets.
- r1 and r4 also send RIP updates onto their host LANs (the `network 10.0.0.0/8` line covers them); the hosts ignore them. A real network would make those interfaces passive.
- No loop or count-to-infinity demonstration: split horizon, triggered updates and the metric-16 limit prevent it in this topology.
- A veth pair carries each link, and `mid` is a Linux bridge, not a real switch or cable.

## Troubleshooting

1. **`show ip route 10.40.0.0/24` says `% Network not in table` after Deploy.** RIP needs up to a minute to spread every route (each router passes it on at its next update). Wait and try again.
2. **After exercise 5 or 6 r1 never goes back to r3.** Check that the bridge and its ports are up: `docker exec clab-rip-four-routers-mid ip -br link` must show `br0`, `eth1` and `eth2` as `UP`. Run the matching "back on" command from the exercise, wait 30 seconds, or reset the lab with `containerlab redeploy -c -t rip-four-routers.clab.yml`.
3. **The ping in exercise 6 still fails after r1 shows the path via r2.** Wait for one more update (up to 30 seconds): r4 and r3 also have to learn the new way back to host-a.
4. **In exercise 5 r1 already uses r2, but the ping still fails.** r3 still sends the replies towards r1 through the dead cable until its own route times out. Wait up to one more minute.
5. **Your silent-failure time is not 170 to 185 seconds.** Anything from about 150 to 210 seconds is normal: it depends on when r3's last update got through before the bridge went off and on the random jitter of the updates.
6. **`make-captures.sh` says r1 has no route via r3 after 120 seconds.** The lab is not deployed, or the bridge is still off from exercise 5. Switch it on (or redeploy) and run the script again.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/rip-four-routers
```
```
containerlab destroy --cleanup -t rip-four-routers.clab.yml
```
`--cleanup` also removes the generated `clab-rip-four-routers` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-rip-four-routers` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/rip-four-routers/clab-rip-four-routers
```
Your capture files in your Home folder are not touched.
