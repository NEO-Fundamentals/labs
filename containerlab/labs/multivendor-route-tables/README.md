# Lab: one routing table read on three systems (FRR runs; Junos and EOS shown as text)

**Folder:** `labs/multivendor-route-tables/`  **Lab file:** `multivendor-route-tables.clab.yml`  **Lesson:** NEO-37 Multi-vendor route tables  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs three real FRR routers. **Junos and EOS appear only as command text for comparison (below). They are not run, and there is no Junos or EOS in this lab.** The routing table you read here is the same idea on every system: a prefix, a next hop, an exit interface and a rule that the longest match wins.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-route-tables/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 1 to 3 minutes (download); later Deploys take under a minute, plus 10 to 20 seconds for FRR to load its routes.

## What this lab builds

```
                        10.0.12.0/30        r2 (FRR)
                  +-------------------------- lo 10.100.0.10
 r1 (FRR) --------+
 three static     +-------------------------- lo 10.100.0.130
 routes                10.0.13.0/30        r3 (FRR)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| r1 | FRR router with three static routes: `10.100.0.0/24` via r2, the more specific `10.100.0.128/25` via r3, and the default route `0.0.0.0/0` via r2. eth1 10.0.12.1/30 (to r2), eth2 10.0.13.1/30 (to r3) | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| r2 | FRR router. eth1 10.0.12.2/30. Holds one destination address on its loopback: 10.100.0.10 | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell (opens `vtysh`) |
| r3 | FRR router. eth1 10.0.13.2/30. Holds one destination address on its loopback: 10.100.0.130 | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell (opens `vtysh`) |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `multivendor-route-tables.clab.yml` - the lab drawing.
- `configs/r1-frr.conf`, `configs/r2-frr.conf`, `configs/r3-frr.conf` - each router's addresses and routes.
- `changes/` - small command files you feed to r1: `r1-shutdown-eth2.txt` (shut the link to r3) and `r1-no-shutdown-eth2.txt`.
- `scripts/make-captures.sh` - re-records the sample captures (the lab must be running; it waits up to 90 seconds for r1's routes).
- `multivendor-route-tables.drawio` and `multivendor-route-tables.png` - the prepared diagram.
- `captures/` - two sample captures: `routes-longest-match-r3.pcapng` and `routes-eth2-down-unreachable.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-route-tables` > right-click `multivendor-route-tables.clab.yml` > **Deploy**. Wait for the three green dots, then 10 to 20 more seconds: FRR loads the static routes a little after the containers start. Check in VS Code's **Terminal > New Terminal** that r1 has the /25:
  ```
  docker exec clab-multivendor-route-tables-r1 ip route show 10.100.0.128/25
  ```
  It prints one line with `via 10.0.13.2`. If it prints nothing, wait 10 seconds and run it again.
- **Reset to the lesson start:**
  ```
  cd ~/labs-main/containerlab/labs/multivendor-route-tables
  ```
  ```
  containerlab redeploy -c -t multivendor-route-tables.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (runs in this lab) | Junos (text only, not run) | EOS (text only, not run) |
|---|---|---|---|
| Show the whole table | `show ip route` | `show route` | `show ip route` |
| Which route is chosen for one address | `show ip route 10.100.0.130` | `show route 10.100.0.130` | `show ip route 10.100.0.130` |
| Only the static routes | `show ip route static` | `show route protocol static` | `show ip route static` |
| Add a static route | `ip route 10.100.0.128/25 10.0.13.2` | `set routing-options static route 10.100.0.128/25 next-hop 10.0.13.2` | `ip route 10.100.0.128/25 10.0.13.2` |
| Default route | `ip route 0.0.0.0/0 10.0.12.2` | `set routing-options static route 0.0.0.0/0 next-hop 10.0.12.2` | `ip route 0.0.0.0/0 10.0.12.2` |
| The same table as the Linux kernel sees it | `ip route` (FRR runs on Linux) | not applicable | not applicable |

Not affiliated with or endorsed by Juniper, Arista or the FRRouting project. Junos and EOS syntax is shown for comparison only.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec`; you can also right-click a router > **Access** > **Attach Shell** and type the part after `vtysh -c`.

**1. Read r1's table.**
```
docker exec clab-multivendor-route-tables-r1 vtysh -c "show ip route"
```
Find the three `S>*` lines (static, selected, installed in the forwarding table): the /24 and the default route go through `10.0.12.2` (r2), the /25 goes through `10.0.13.2` (r3). The `C>*` lines are the two connected links. Then read the same table the way Linux keeps it:
```
docker exec clab-multivendor-route-tables-r1 ip route
```

**2. The longest match wins.** Ask r1 which route it uses for three destinations:
```
docker exec clab-multivendor-route-tables-r1 vtysh -c "show ip route 10.100.0.10"
```
```
docker exec clab-multivendor-route-tables-r1 vtysh -c "show ip route 10.100.0.130"
```
```
docker exec clab-multivendor-route-tables-r1 vtysh -c "show ip route 10.200.1.1"
```
10.100.0.10 is inside the /24 but not the /25 (the /25 starts at .128), so it uses the /24 through r2. 10.100.0.130 is inside both; the /25 is longer, so it wins and uses r3. 10.200.1.1 matches nothing but the default route, which goes to r2. A /25 holds 128 addresses (.128 to .255), a /24 holds 256.

**3. Prove it with a capture.** In Ubuntu's Terminal app start the capture first (8 seconds), then in VS Code's terminal make r1 forget its neighbours and ping:
```
sudo containerlab capture --name multivendor-route-tables --target r1:eth2 --duration 8s -w - > "$HOME/neo-routes-r3.pcapng"
```
```
docker exec clab-multivendor-route-tables-r1 ip neigh flush all
```
```
docker exec clab-multivendor-route-tables-r1 ping -c 3 10.100.0.130
```
The packets leave on eth2, the cable to r3, and r3 answers from its loopback. The sample `captures/routes-longest-match-r3.pcapng` shows r1's ARP for 10.0.13.2, then three pings and three replies. Pinging 10.100.0.10 would leave on eth1 instead.

**4. Take the better route away.** Shut down r1's link to r3:
```
docker exec -i clab-multivendor-route-tables-r1 vtysh < changes/r1-shutdown-eth2.txt
```
```
docker exec clab-multivendor-route-tables-r1 vtysh -c "show ip route 10.100.0.130"
```
vtysh still shows the `10.100.0.128/25` entry as `Installed`, but its next hop has changed: the line `10.0.13.2 (recursive)` means r1 now has to look up how to reach 10.0.13.2, and the answer is the default route through `10.0.12.2, via eth1`, which is the line marked `*`. eth2 is down, so r1 can no longer reach r3 directly, and the traffic for 10.100.0.130 goes to r2. (vtysh may also print `No changes found to be committed!` while it applies the file. It is harmless.) Ping it:
```
docker exec clab-multivendor-route-tables-r1 ping -c 3 -W 1 10.100.0.130
```
**On FRR, ping prints nothing about why it failed**: you see only the summary with 100% packet loss. The reason is in the capture. Start the capture on r1's cable to r2 and run the ping again:
```
sudo containerlab capture --name multivendor-route-tables --target r1:eth1 --duration 8s -w - > "$HOME/neo-routes-down.pcapng"
```
Open it in Wireshark and filter on `icmp`: r1 sends each echo request to r2, and r2 answers every one with **Destination unreachable (Network unreachable)**. r2 has no route to 10.100.0.130, so it tells r1 so. The sample `captures/routes-eth2-down-unreachable.pcapng` shows exactly this: 3 requests and 3 unreachable messages. The router that sent the message (10.0.12.2, r2) is the router that is missing the route, which is where you look next. (This is not the same as the local `Network unreachable` you may see on a host with no default route; that comes from the host itself and prints on screen.)

**5. Put it back.**
```
docker exec -i clab-multivendor-route-tables-r1 vtysh < changes/r1-no-shutdown-eth2.txt
```
Wait about 5 seconds and run `show ip route 10.100.0.130` again: the /25 shows `10.0.13.2, via eth2` again, with no `(recursive)` line, and the ping from step 3 answers again.

## Sample captures

Both are recorded on r1's cables and cut to 200 bytes per packet. Open them in Wireshark with File > Open.

| File | Frames | Cable | What it shows |
|---|---|---|---|
| `routes-longest-match-r3.pcapng` | 8 | r1:eth2 | ARP for r3, then three pings and three replies (the /25 wins) |
| `routes-eth2-down-unreachable.pcapng` | 8 | r1:eth1 | ARP for r2, then three pings, each answered by r2 with Destination unreachable (Network unreachable) |

## Troubleshooting

1. **`show ip route` shows only the connected routes (no `S>*` lines).** FRR loads the static routes 10 to 20 seconds after the containers start. Wait, then check again.
2. **A file in `changes/` seems to do nothing.** Feed it to vtysh with `-i` so Docker passes the file in: `docker exec -i clab-multivendor-route-tables-r1 vtysh < changes/r1-shutdown-eth2.txt`. Without `-i` the file is ignored. Run the command from the lab folder.
3. **The ping in step 4 prints no error.** That is how the FRR container's ping behaves: it prints only the summary. Use the capture to see the ICMP message (step 4).
4. **The /25 does not come back after step 5.** Run `docker exec clab-multivendor-route-tables-r1 vtysh -c "show interface brief"` and check that eth2 is up. If it is not, run `changes/r1-no-shutdown-eth2.txt` again, or reset with `containerlab redeploy -c -t multivendor-route-tables.clab.yml`.
5. **The capture is empty.** Start the capture first and wait a few seconds, then run the ping. A capture on the wrong cable shows nothing: the cable to r2 is `r1:eth1`, the cable to r3 is `r1:eth2`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-route-tables
```
```
containerlab destroy --cleanup -t multivendor-route-tables.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-route-tables` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-route-tables` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-route-tables/clab-multivendor-route-tables
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- No Junos or EOS device runs here; the table above is text.
- Static routes only: there is no routing protocol, so nothing reroutes by itself. A veth pair carries each link, so shutting r1's port also drops the far end's carrier.
