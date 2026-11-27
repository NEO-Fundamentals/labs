# Lab: routing tables, the longest match and the next hop (FRR and SR Linux)

**Folder:** `labs/routing-table-next-hop/`  **Lab file:** `routing-table-next-hop.clab.yml`  **Lesson:** NEO-09 Routing tables, longest-prefix match, ARP, and the next hop  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs a real FRR router (r1), a real Nokia SR Linux router (r2) and three Linux hosts. **There is no Arista EOS or Juniper Junos in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/routing-table-next-hop/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about 2 minutes. **Then wait 1 to 2 more minutes:** FRR loads its routes 10 to 20 seconds after the containers start, and SR Linux needs one to two minutes. Do not trust the ping until the check in **Start** passes.

## What this lab builds

```
 host-1 --- r1 (FRR) ------ r2 (SR Linux) --- host-2
 10.1.1.10   |  10.0.12.0/30                  10.2.2.10
             |
             +--- sink (does not forward)
                  10.0.99.0/30
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-1 | Linux host 10.1.1.10/24, gateway r1 (10.1.1.1) | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router: 10.1.1.1/24 (eth1), 10.0.12.1/30 (eth2), 10.0.99.1/30 (eth3). Static routes: 10.2.2.0/24 via r2 and the wider 10.2.0.0/16 via sink | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell (opens `vtysh`) |
| r2 | SR Linux router: 10.0.12.2/30 (ethernet-1/1), 10.2.2.1/24 (ethernet-1/2). Static routes back to 10.1.1.0/24 and 10.0.99.0/30 via r1 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| host-2 | Linux host 10.2.2.10/24, gateway r2 (10.2.2.1) | `ghcr.io/srl-labs/network-multitool` | Attach Shell |
| sink | Linux host 10.0.99.2/30 that does not forward packets: a dead end for a wrong route | `ghcr.io/srl-labs/network-multitool` | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r2 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `routing-table-next-hop.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` (FRR: interfaces and static routes), `configs/r2-srl.cli` (SR Linux: interfaces and static routes).
- `changes/` - small command files you feed to r1: `r1-add-host-route.txt` (the wrong /32 route) and `r1-remove-host-route.txt`.
- `scripts/make-captures.sh` - re-records the sample captures (the lab must be running; it waits up to 6 minutes for the path to work).
- `routing-table-next-hop.drawio` and `routing-table-next-hop.png` - the prepared diagram.
- `captures/` - three sample captures: `nexthop-hop1-host1.pcapng`, `nexthop-hop2-transit.pcapng`, `nexthop-hostroute-sink.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `routing-table-next-hop` > right-click `routing-table-next-hop.clab.yml` > **Deploy**. Wait for the green dots, then check the whole path in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-routing-table-next-hop-host-1 ping -c 2 10.2.2.10
  ```
  Two replies means r1 and r2 both have their routes. If it says 100% packet loss, wait a minute and run it again.
- **Reset to the lesson start:**
  ```
  cd ~/labs-main/containerlab/labs/routing-table-next-hop
  ```
  ```
  containerlab redeploy -c -t routing-table-next-hop.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (r1, runs in this lab) | SR Linux (r2, runs in this lab) | Linux (hosts) |
|---|---|---|---|
| Show the routing table | `show ip route` | `show network-instance default ipv4 route` | `ip route` |
| Which route is chosen for one address | `show ip route 10.2.2.10` | read the matching prefix in the table above | `ip route get 10.2.2.10` |
| Add a static route | `ip route 10.2.2.0/24 10.0.12.2` (configure mode) | `set / network-instance default static-routes route ...` | `ip route add 10.2.2.0/24 via 10.0.12.2` |
| Neighbour (ARP) table | `ip neigh` (FRR runs on Linux; run it with `docker exec` as in the exercises) | `show arpnd arp-entries` | `ip neigh` |

Junos and EOS are not part of this lab. Their counterparts are in lesson NEO-37's lab (`multivendor-route-tables`), as text.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name.

**1. Read host-1's table.**
```
docker exec clab-routing-table-next-hop-host-1 ip route
```
```
docker exec clab-routing-table-next-hop-host-1 ip route get 10.2.2.10
```
host-1 has one route that matters: everything in 10.0.0.0/8 goes to its gateway 10.1.1.1 (r1). `ip route get` names the gateway and the interface it will use. The host knows nothing about r2 or about host-2's subnet. It only knows the next hop.

**2. Read r1's table: two routes cover host-2.**
```
docker exec clab-routing-table-next-hop-r1 vtysh -c "show ip route"
```
Look for `S>*` lines (static, selected, installed): `10.2.0.0/16` via `10.0.99.2` (sink) and `10.2.2.0/24` via `10.0.12.2` (r2). Both contain host-2's address 10.2.2.10. Ask r1 which one it uses:
```
docker exec clab-routing-table-next-hop-r1 vtysh -c "show ip route 10.2.2.10"
```
It answers with the /24 through r2: **the longest matching prefix wins**, so the narrower /24 beats the wider /16. Now an address that only the /16 covers:
```
docker exec clab-routing-table-next-hop-r1 vtysh -c "show ip route 10.2.9.9"
```
This one goes to sink. A packet for 10.2.9.9 will leave r1 toward sink, which does not forward it.

**3. Read r2's table.**
```
docker exec clab-routing-table-next-hop-r2 sr_cli "show network-instance default ipv4 route"
```
The table is headed `IPv4-unicast route table for default network-instance`. r2 has its two connected subnets (route type `local`: 10.0.12.0/30 and 10.2.2.0/24) and two `static` routes, 10.1.1.0/24 and 10.0.99.0/30, whose next hop is 10.0.12.1, r1. r2 never sees the /16. To read one prefix, add it to the command, for example `show network-instance default ipv4 route 10.2.2.0/24`.

**4. Follow the first hop (ARP and ping).** In Ubuntu's Terminal app start the capture first (8 seconds), then in VS Code's terminal make host-1 forget r1's hardware address and ping host-2:
```
sudo containerlab capture --name routing-table-next-hop --target host-1:eth1 --duration 8s -w - > "$HOME/neo-hop1.pcapng"
```
```
docker exec clab-routing-table-next-hop-host-1 ip neigh flush all
```
```
docker exec clab-routing-table-next-hop-host-1 ping -c 3 10.2.2.10
```
Open the file in Wireshark. Host-1 sends an ARP request for its **gateway** 10.1.1.1, not for 10.2.2.10: it can only reach devices on its own subnet directly. The ping then goes to r1's hardware address with the destination IP 10.2.2.10. The sample `captures/nexthop-hop1-host1.pcapng` shows it: frames 1 and 2 are r1's own ARP, frames 3 and 4 are host-1's ARP for 10.1.1.1, then three pings. Look at the TTL: the request leaves host-1 with 64 and the reply arrives with 62, because two routers handled it.

**5. Follow the second hop.** Capture on the cable between r1 and r2, and make r1 forget r2's address:
```
sudo containerlab capture --name routing-table-next-hop --target r1:eth2 --duration 8s -w - > "$HOME/neo-hop2.pcapng"
```
```
docker exec clab-routing-table-next-hop-r1 ip neigh flush dev eth2
```
```
docker exec clab-routing-table-next-hop-host-1 ping -c 3 10.2.2.10
```
r1 asks ARP for **10.0.12.2** (the next hop), not for host-2. The ping packets carry the same source and destination IP addresses as on the first hop, but a different hardware address pair, and the TTL is now 63. The sample is `captures/nexthop-hop2-transit.pcapng`. The next hop changes at every router; the destination IP stays the same.

**6. The wrong host route.** Add a /32 route for exactly host-2, pointing at sink:
```
docker exec -i clab-routing-table-next-hop-r1 vtysh < changes/r1-add-host-route.txt
```
```
docker exec clab-routing-table-next-hop-r1 vtysh -c "show ip route 10.2.2.10"
```
r1 now picks `10.2.2.10/32` via `10.0.99.2`: a /32 is the longest possible match, so it beats the /24 even though it is wrong. Ping host-2 and then r2's own address:
```
docker exec clab-routing-table-next-hop-host-1 ping -c 3 -W 1 10.2.2.10
```
```
docker exec clab-routing-table-next-hop-host-1 ping -c 3 -W 1 10.2.2.1
```
host-2 no longer answers, but 10.2.2.1 (r2, in the same /24) still does: **one host breaks while the rest of the subnet works**. That is the signature of a more-specific wrong route. To see where the packets went, capture on r1's cable to sink (`--target r1:eth3`) while you ping. The sample `captures/nexthop-hostroute-sink.pcapng` shows r1's ARP for 10.0.99.2 (sink answers), then three pings that nobody answers. Remove the wrong route:
```
docker exec -i clab-routing-table-next-hop-r1 vtysh < changes/r1-remove-host-route.txt
```
and ping 10.2.2.10 again: it works.

## Sample captures

All are cut to 200 bytes per packet. Open them in Wireshark with File > Open.

| File | Frames | Cable | What it shows |
|---|---|---|---|
| `nexthop-hop1-host1.pcapng` | 10 | host-1:eth1 | ARP for the gateway, then three pings (TTL 64 out, 62 back) |
| `nexthop-hop2-transit.pcapng` | 8 | r1:eth2 | ARP for the next hop 10.0.12.2 (answered by r2), then three pings (TTL 63) |
| `nexthop-hostroute-sink.pcapng` | 5 | r1:eth3 | ARP for sink, then three requests with no reply (the wrong /32 route) |

## Troubleshooting

1. **The first ping between `host-1` and `host-2` fails.** FRR needs 10 to 20 seconds and SR Linux one to two minutes after the containers start. Wait, then check again.
2. **A file in `changes/` seems to do nothing.** Feed it to vtysh with `-i` so Docker passes the file in: `docker exec -i clab-routing-table-next-hop-r1 vtysh < changes/r1-add-host-route.txt`. Without `-i` the file is ignored. Run the command from the lab folder, or give the full path to the file.
3. **`show ip route 10.2.2.10` still shows the /24 after step 6.** The file did not apply (see 2). Run `docker exec clab-routing-table-next-hop-r1 vtysh -c "show running-config"` and look for the `ip route 10.2.2.10/32` line.
4. **The host route is stuck after an experiment.** Run `changes/r1-remove-host-route.txt` the same way, or reset the lab with `containerlab redeploy -c -t routing-table-next-hop.clab.yml`.
5. **The capture is empty.** Start the capture first and wait a few seconds, then run the ping. A capture on the wrong cable shows nothing: host-1 is `host-1:eth1`, the r1 to r2 cable is `r1:eth2`, the sink cable is `r1:eth3`.
6. **`sr_cli` says a command is unknown.** SR Linux is picky about spaces; copy the command exactly (on this SR Linux version the routing table is `show network-instance default ipv4 route`), or open r2 with Attach Shell and press the question mark key for the options.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/routing-table-next-hop
```
```
containerlab destroy --cleanup -t routing-table-next-hop.clab.yml
```
`--cleanup` also removes the generated `clab-routing-table-next-hop` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-routing-table-next-hop` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/routing-table-next-hop/clab-routing-table-next-hop
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- No Junos or EOS device runs here.
- Static routes only: there is no routing protocol, so nothing reroutes by itself when a link fails.
- A veth pair carries each link, so there is no real cable or switch in the path.
