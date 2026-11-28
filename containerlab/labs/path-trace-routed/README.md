# Lab: Path trace: the entry point and the routed path, hop by hop

**Folder:** `labs/path-trace-routed/`  **Lab file:** `path-trace-routed.clab.yml`  **Lesson:** NEO-24 Path trace: finding the entry point and walking the routed path  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** five boxes in a line: h1, router r1, firewall fw, router r2 and h2 with a web server. r1 and r2 run **FRR** (free routing software with a Cisco-style command line) with static routes; fw is a Linux router with **nftables** (in the NEO helper image `neo-tools`). Everything you trace is real routing and real packets. You find where h1's traffic enters the network, walk the path to h2 and back one hop at a time, and then find two faults that `scripts/fault.sh` puts in place. No SR Linux in this lab.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: two FRR routers and three small Linux containers, about 180 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/path-trace-routed/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and `quay.io/frrouting/frr:containerlab-10.7.1`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes about 10 seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
   h1 ---------- r1 ------------- fw -------------- r2 ---------- h2
10.24.1.10   .1 eth1  eth2 .1  .2 eth1  eth2 .2  .3 eth1  eth2 .1   10.24.2.20 (web :80)
   10.24.1.0/24      10.24.12.0/24     10.24.23.0/24       10.24.2.0/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| h1 | 10.24.1.10/24, default gateway 10.24.1.1 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router: eth1 10.24.1.1/24 (h1's gateway), eth2 10.24.12.1/24. Static routes to 10.24.23.0/24 and 10.24.2.0/24 via fw (10.24.12.2). `configs/r1-frr.conf` | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| fw | Linux router with nftables: eth1 10.24.12.2/24, eth2 10.24.23.2/24; routes to 10.24.1.0/24 via r1 and to 10.24.2.0/24 via r2. Its rules (`configs/fw-rules.nft`) let ping, traceroute and web from the h1 side to h2's LAN through, and the replies back; everything else is dropped | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| r2 | FRR router: eth1 10.24.23.3/24, eth2 10.24.2.1/24 (h2's gateway). Static routes back to 10.24.12.0/24 and 10.24.1.0/24 via fw (10.24.23.2). `configs/r2-frr.conf` | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| h2 | 10.24.2.20/24, default gateway 10.24.2.1; web server on port 80 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. Each box also has a management interface, eth0 (172.20.20.x), which the lab traffic does not use.

## Files

- `path-trace-routed.clab.yml` - the lab drawing. Addresses and routes of h1, fw and h2 are set by their `exec` lines.
- `configs/r1-frr.conf`, `configs/r2-frr.conf` - the routers' setup. `configs/fw-rules.nft` - fw's rules; loading it again puts them back as at deploy.
- `changes/fw-change.nft` - the firewall change of exercise 5.
- `scripts/fault.sh` - puts the fault of an exercise in place: `bash scripts/fault.sh 1` (exercise 4), `2` (exercise 5). Try each exercise before you read how the fault is made.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes under a minute, puts each fault in place and undoes it, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `path-trace-routed.drawio` and `path-trace-routed.png` - the prepared diagram.
- `captures/` - three sample captures: `pt-1-path.pcapng`, `pt-2-no-return.pcapng`, `pt-3-fw-drop.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `path-trace-routed` > right-click `path-trace-routed.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-path-trace-routed-h1 curl -s -m 3 http://10.24.2.20/
  ```
  It prints `hello from h2 (10.24.2.20)`. If it prints nothing, wait 10 seconds (the routers are still starting) and try again.
- **Reset to the lesson start** (all routes and fw's rules as at deploy): do this whenever a fault is left over.
  ```
  cd ~/labs-main/containerlab/labs/path-trace-routed
  ```
  ```
  containerlab redeploy -c -t path-trace-routed.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Where | Command |
|---|---|---|
| Where does a host send traffic for other networks? | h1, h2 | `ip route` (the `default via` line is the gateway) |
| Which box owns that gateway address? | r1, r2 | `vtysh -c 'show interface brief'` |
| Which hops does the path take? | h1 | `traceroute -n 10.24.2.20` (`-T -p 80` for TCP to port 80) |
| Where does this router send a packet for X? | r1, r2 | `vtysh -c 'show ip route X'` |
| Where does fw send it, and may it pass? | fw | `ip route get X`, `nft list chain inet fw forward` |
| Did the packet arrive, and did an answer leave? | any Linux box | `tcpdump -ni eth1 ...` |

The method: start at the **entry point** (the first box that routes the traffic: the source's gateway), ask each hop "where does a packet for the destination go next?", follow the answer to the next box, and stop at the destination. Then do the same **from the destination back to the source**: the replies take their own path, and every hop must know the way back too.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/path-trace-routed`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The entry point: h1's gateway.**
```
docker exec clab-path-trace-routed-h1 ip route
```
```
docker exec clab-path-trace-routed-h1 sh -c 'ping -c 1 -W 1 10.24.1.1 >/dev/null; ip neigh show 10.24.1.1'
```
```
docker exec clab-path-trace-routed-r1 vtysh -c 'show interface brief'
```
```
docker exec clab-path-trace-routed-r1 ip -br link show eth1
```
h1 knows only its own subnet (`10.24.1.0/24 dev eth1`) and a **default route via 10.24.1.1**: every packet for another network goes to 10.24.1.1. h1 finds that address's MAC address with ARP (`10.24.1.1 dev eth1 lladdr aa:c1:ab:...`). r1's interface list shows that 10.24.1.1/24 is **r1's eth1**, and r1's eth1 has the same MAC address as h1's ARP entry. So r1, interface eth1, is where h1's traffic enters the routed network: the **entry point**. (The `eth0` lines are the management network, not part of the lab path.)

**2. Walk the path to h2, hop by hop.**
```
docker exec clab-path-trace-routed-h1 traceroute -n -w 1 -q 1 10.24.2.20
```
```
docker exec clab-path-trace-routed-r1 vtysh -c 'show ip route 10.24.2.20'
```
```
docker exec clab-path-trace-routed-fw ip route get 10.24.2.20
```
```
docker exec clab-path-trace-routed-fw nft list chain inet fw forward
```
```
docker exec clab-path-trace-routed-r2 vtysh -c 'show ip route 10.24.2.20'
```
The traceroute lists four hops: `10.24.1.1` (r1), `10.24.12.2` (fw), `10.24.23.3` (r2), `10.24.2.20` (h2). It works by sending probes with a time-to-live of 1, 2, 3, ...: each router that has to drop a probe answers "time exceeded" from the interface the probe came in on, and h2 answers the last one. The routing tables tell the same story, hop by hop: r1 sends 10.24.2.0/24 to `10.24.12.2, via eth2` (a static route); fw sends it `via 10.24.23.3 dev eth2`, and its rules allow it (`traceroute to h2's LAN` has counted your probes, `web to h2's LAN` the Start check); r2 has 10.24.2.0/24 **directly connected** on eth2, so it delivers to h2 itself. (Sample `pt-1-path.pcapng`, recorded on h1's eth1: the probes, the "time exceeded" answers from 10.24.1.1, 10.24.12.2 and 10.24.23.3, h2's "port unreachable", then a web request.)

**3. Walk the way back.** h2's answers start their own trip:
```
docker exec clab-path-trace-routed-h2 ip route
```
```
docker exec clab-path-trace-routed-r2 vtysh -c 'show ip route 10.24.1.10'
```
```
docker exec clab-path-trace-routed-fw ip route get 10.24.1.10
```
```
docker exec clab-path-trace-routed-r1 vtysh -c 'show ip route 10.24.1.10'
```
h2 sends everything not on its own subnet to its gateway 10.24.2.1 (r2: the entry point for the way back). r2 sends 10.24.1.0/24 `via 10.24.23.2` (fw), fw `via 10.24.12.1` (r1), and r1 has 10.24.1.0/24 directly connected. Here the way back mirrors the way there; in real networks it often does not, and a path is only proven when both directions are.

**4. The trace stops: where?** Put the fault in place:
```
bash scripts/fault.sh 1
```
```
docker exec clab-path-trace-routed-h1 ping -c 3 -W 1 10.24.2.20
```
```
docker exec clab-path-trace-routed-h1 traceroute -n -w 1 -q 1 -m 6 10.24.2.20
```
Every ping is lost, and the traceroute answers for hops 1 and 2 (r1, fw), then only `*`. It looks as if the packets stop after fw. Check whether they arrive at h2. In a second terminal (it stops by itself after 8 seconds):
```
docker exec clab-path-trace-routed-h2 timeout 8 tcpdump -l -ni eth1 icmp
```
In the first terminal:
```
docker exec clab-path-trace-routed-h1 ping -c 2 -W 1 10.24.2.20
```
h2 **does** get the pings (`10.24.1.10 > 10.24.2.20: ICMP echo request`) and **does** answer (`echo reply`); right after a reply r2 tells h2 `ICMP net 10.24.1.10 unreachable` (once or twice: routers limit how many of these messages they send per second). The requests get through; the **replies** die at r2. Walk the way back from exercise 3:
```
docker exec clab-path-trace-routed-r2 vtysh -c 'show ip route static'
```
r2 has a route back to 10.24.12.0/24 only: the route to **10.24.1.0/24 is missing**. That also explains the traceroute: r2 did receive the hop-3 probe, but its "time exceeded" answer to 10.24.1.10 had no route either. A traceroute shows where the **answers** stop coming back, which is not always where the packets stop. Put the route back (on a real router: in the configuration):
```
docker exec clab-path-trace-routed-r2 vtysh -c 'configure terminal' -c 'ip route 10.24.1.0/24 10.24.23.2'
```
```
docker exec clab-path-trace-routed-h1 ping -c 2 -W 1 10.24.2.20
```
2 of 2 again. (Sample `pt-2-no-return.pcapng`, recorded on h2's eth1: two requests, two replies, and after the replies the "network unreachable" from 10.24.2.1.)

**5. Ping works, the web page does not.**
```
bash scripts/fault.sh 2
```
```
docker exec clab-path-trace-routed-h1 ping -c 2 -W 1 10.24.2.20
```
```
docker exec clab-path-trace-routed-h1 curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.24.2.20/
```
```
docker exec clab-path-trace-routed-h1 traceroute -n -T -p 80 -w 1 -q 1 -m 5 10.24.2.20
```
The ping works (2 of 2), so every route is fine, but the web request gets nothing (`http 000 in 3.0 s`). A traceroute with TCP probes to port 80 (`-T -p 80`: the same kind of packet as the web request) answers for hop 1 (r1) and hop 2 (fw), then only `*`: TCP to port 80 does not get past fw. Look at both sides of fw. In a second terminal (it stops by itself after 8 seconds):
```
docker exec clab-path-trace-routed-fw timeout 8 tcpdump -l -ni any tcp port 80
```
In the first terminal:
```
docker exec clab-path-trace-routed-h1 curl -s -m 3 -o /dev/null -w 'http %{http_code}\n' http://10.24.2.20/
```
```
docker exec clab-path-trace-routed-fw nft list chain inet fw forward
```
tcpdump shows h1's SYNs coming **in** on eth1 (`eth1 In IP 10.24.1.10.xxxxx > 10.24.2.20.80: Flags [S]`, three times) and **nothing out** on eth2: fw dropped them. The rules show why: a new rule at the top, `ip daddr 10.24.2.0/24 tcp dport 80 counter packets ... drop comment "CHG-0042 block old web server"`. The change was meant for one old server, 10.24.2.200, but it was typed with the whole subnet, and because it is first it wins over the `web to h2's LAN` rule below it. Put fw's rules back as they were (the file replaces the whole table):
```
docker exec -i clab-path-trace-routed-fw nft -f - < configs/fw-rules.nft
```
```
docker exec clab-path-trace-routed-h1 curl -s -m 3 -o /dev/null -w 'http %{http_code}\n' http://10.24.2.20/
```
`http 200`. (Sample `pt-3-fw-drop.pcapng`, recorded on both fw ports: a ping that passes in both directions on both ports, then three SYNs on eth1 only.)

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `pt-1-path.pcapng` | h1:eth1 | 37 | a traceroute: UDP probes from 10.24.1.10, "Time-to-live exceeded" from 10.24.1.1, 10.24.12.2 and 10.24.23.3, then "Port unreachable" from 10.24.2.20; then one web request to h2 |
| `pt-2-no-return.pcapng` | h2:eth1 | 6 | exercise 4: each echo request arrives and h2 answers, then 10.24.2.1 (r2) sends h2 "Destination unreachable (Network unreachable)": the reply has no way back |
| `pt-3-fw-drop.pcapng` | fw:eth1 and fw:eth2 | 7 | exercise 5: one ping crosses fw both ways (seen on both ports), then h1's SYN to port 80 and two retransmissions, on eth1 only (Wireshark: View > Interface column, or the `frame.interface_name` field) |

## What this lab does not do

- Static routes only (no routing protocol); one path, no redundancy, IPv4 only.
- fw is a Linux router with nftables, not a commercial firewall; its rules are short on purpose.
- The faults are made by `scripts/fault.sh`, not by real outages. A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start prints nothing.** The FRR routers need a few seconds after the deploy to load their routes. Wait 10 seconds and try again; `docker exec clab-path-trace-routed-r1 vtysh -c 'show ip route static'` should list two routes.
2. **The traceroute shows `*` for every hop although nothing is broken.** A fault is still in place from an earlier exercise. Reset the lab.
3. **No `tcpdump` output in the second terminal.** Start the first-terminal command within 8 seconds of the second-terminal one, or run both again.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/path-trace-routed
```
```
containerlab destroy --cleanup -t path-trace-routed.clab.yml
```
`--cleanup` also removes the generated `clab-path-trace-routed` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-path-trace-routed` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/path-trace-routed/clab-path-trace-routed
```
Your capture files in your Home folder are not touched.

