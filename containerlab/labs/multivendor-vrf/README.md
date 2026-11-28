# Lab: Multi-vendor VRFs

**Folder:** `labs/multivendor-vrf/`  **Lab file:** `multivendor-vrf.clab.yml`  **Lesson:** NEO-39 Multi-vendor VRFs: Junos routing-instances and EOS VRF instances  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs one real Nokia SR Linux router (r1), one real FRR router on Linux (r2) and four Linux hosts. Both routers hold the same two VRFs, RED and BLUE, each in its own way: on SR Linux a VRF is a network-instance of type `ip-vrf`; on Linux (and so for FRR) a VRF is a **VRF device**, a kernel interface with its own routing table that ports are attached to. **There is no Arista EOS, Juniper Junos or Cisco device in this lab.** The lesson shows Junos routing-instances and EOS VRF instances as text only.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Linux VRF devices:** r2's VRFs need the kernel's `vrf` module, which Ubuntu 24.04 has; the kernel loads it when r2 makes its VRFs. If the Deploy prints `Failed to execute command command="ip link add RED type vrf table 10"`, see Troubleshooting 1.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-vrf/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 site-a (RED)  ---- e1/1                     eth3 ---- site-c (RED)
 10.39.100.10          r1 e1/3 ---RED---- eth1  r2       10.39.200.10
                (SR Linux)   10.39.12.0/30     (FRR)
 site-b (BLUE) ---- e1/2  e1/4 ---BLUE--- eth2      eth4 ---- site-d (BLUE)
 10.39.100.10                10.39.12.0/30               10.39.200.10
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| site-a | Linux host in RED, 10.39.100.10/24, route to 10.39.0.0/16 via 10.39.100.1 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| site-b | Linux host in BLUE, **the same** 10.39.100.10/24 and the same gateway | same | Attach Shell |
| r1 | SR Linux router. network-instance `red` (ip-vrf): ethernet-1/1 10.39.100.1/24, ethernet-1/3 10.39.12.1/30, static 10.39.200.0/24 via 10.39.12.2. network-instance `blue`: ethernet-1/2 10.39.100.1/24, ethernet-1/4 10.39.12.1/30, the same static route | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| r2 | FRR router on Linux. VRF device `RED` (table 10): eth1 10.39.12.2/30, eth3 10.39.200.1/24, static 10.39.100.0/24 via 10.39.12.1. VRF device `BLUE` (table 20): eth2 10.39.12.2/30, eth4 10.39.200.1/24, the same static route | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then type `vtysh` |
| site-c | Linux host in RED, 10.39.200.10/24, route to 10.39.0.0/16 via 10.39.200.1 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| site-d | Linux host in BLUE, **the same** 10.39.200.10/24 and the same gateway | same | Attach Shell |

**The addresses repeat on purpose.** site-a and site-b have the same address, so do site-c and site-d, and the two r1 - r2 links use the same /30. Without VRFs this would not work at all; with them, RED and BLUE never meet. Each site's web page (port 80) answers with the site's name, so `curl` shows which site a request reached.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r1 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `multivendor-vrf.clab.yml` - the lab drawing. r2's `exec` lines make the two Linux VRF devices, attach the ports to them, and load the FRR configuration again so that FRR applies the VRF parts.
- `configs/r1-srl.cli` - r1 (SR Linux): addresses, the network-instances `red` and `blue` (type `ip-vrf`), and one static route in each.
- `configs/r2-frr.conf` - r2 (FRR): a `vrf RED` and a `vrf BLUE` block, each with one static route, and the addresses on `interface eth1 vrf RED` and so on.
- `changes/` - the exercise change, applied to r2 with `docker exec -i ... vtysh < changes/<file>`: `r2-red-route-no-vrf.vtysh` (the mistake) and `r2-red-route-fix.vtysh` (the fix).
- `multivendor-vrf.drawio` and `multivendor-vrf.png` - the prepared diagram.
- No sample captures: everything in this lesson is in the route tables. You can still capture any link (exercise 6).

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-vrf` > right-click `multivendor-vrf.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-vrf-site-a curl -s -m 2 10.39.200.10
  ```
  It prints `site-c`. If it prints nothing, SR Linux is still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-vrf
  ```
  ```
  containerlab redeploy -c -t multivendor-vrf.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | SR Linux (r1: `sr_cli`) | FRR on Linux (r2: `vtysh`, or Linux `ip`) |
|---|---|---|
| List the VRFs | `show network-instance summary` (type `ip-vrf`) | `show vrf` · Linux: `ip -br link show type vrf` |
| Which ports are in a VRF | `show network-instance red interfaces` | `show interface vrf RED brief` · Linux: `ip -br link show master RED` |
| One VRF's routes | `show network-instance red ipv4 route` | `show ip route vrf RED` · Linux: `ip route show vrf RED` |
| Ping inside a VRF | `ping 10.39.100.10 -c 2 network-instance red` | Linux: `ip vrf exec RED ping -c 2 10.39.200.10` |

Junos and EOS are not part of this lab; the lesson shows their commands as text. The idea is the same everywhere: every route, show command and ping must name the VRF, or it uses the default table.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name (on r2, type `vtysh` first for the `show` commands).

**1. Same address, two sites.**
```
docker exec clab-multivendor-vrf-site-a curl -s -m 2 10.39.200.10
```
```
docker exec clab-multivendor-vrf-site-b curl -s -m 2 10.39.200.10
```
The same request to the same address, from two hosts with the same address: site-a gets `site-c`, site-b gets `site-d`. Each request stayed in its VRF on both routers.

**2. The VRFs on SR Linux.**
```
docker exec clab-multivendor-vrf-r1 sr_cli "show network-instance summary"
```
`red` and `blue`, type `ip-vrf`, `up` (plus `mgmt`). Now the two tables:
```
docker exec clab-multivendor-vrf-r1 sr_cli "show network-instance red ipv4 route"
```
```
docker exec clab-multivendor-vrf-r1 sr_cli "show network-instance blue ipv4 route"
```
Both list the same three prefixes: `10.39.12.0/30` and `10.39.100.0/24` (local) and `10.39.200.0/24` (static, next hop 10.39.12.2). The only difference is the ports: ethernet-1/1 and 1/3 in red, ethernet-1/2 and 1/4 in blue.

**3. The VRFs on FRR and Linux.**
```
docker exec clab-multivendor-vrf-r2 vtysh -c "show vrf"
```
One line per VRF, for example `vrf RED id 2 table 10 (configured)` and `vrf BLUE id 3 table 20 (configured)` (the id numbers can differ). A VRF the kernel could not create shows `inactive` (Troubleshooting 1). Then:
```
docker exec clab-multivendor-vrf-r2 vtysh -c "show ip route vrf RED"
```
The connected `10.39.12.0/30` and `10.39.200.0/24` on eth1 and eth3, and `S>* 10.39.100.0/24` via 10.39.12.1 on eth1. `show ip route vrf BLUE` lists the same prefixes on eth2 and eth4. Underneath, each FRR VRF is a Linux VRF device with its own kernel table:
```
docker exec clab-multivendor-vrf-r2 ip -d link show type vrf
```
```
docker exec clab-multivendor-vrf-r2 ip route show vrf RED
```
`RED` shows `vrf table 10` and `BLUE` `vrf table 20`; `ip route show vrf RED` shows the same routes as FRR's table, written by FRR into the kernel.

**4. Name the VRF (the lesson's practice).** On r1, ping site-a's address in red:
```
docker exec clab-multivendor-vrf-r1 sr_cli "ping 10.39.100.10 -c 2 network-instance red"
```
Two replies (`Using network instance red`). This lab has no default network-instance with these ports, and SR Linux says so if you ask for one: `... network-instance default` gives `Must be an existing network namespace`. On r2, a plain Linux ping uses the default table, which has no route to the sites (only the management network):
```
docker exec clab-multivendor-vrf-r2 ping -c 2 -W 1 10.39.200.10
```
No reply. Inside the VRF it works:
```
docker exec clab-multivendor-vrf-r2 ip vrf exec RED ping -c 2 10.39.200.10
```
The route was there all along, in RED. The plain ping looked in the wrong table.

**5. A route typed without its VRF.** Remove RED's route back to the 10.39.100.0/24 sites and type it again, but outside the VRF:
```
cd ~/labs-main/containerlab/labs/multivendor-vrf
```
```
docker exec -i clab-multivendor-vrf-r2 vtysh < changes/r2-red-route-no-vrf.vtysh
```
```
docker exec clab-multivendor-vrf-r2 vtysh -c "show ip route vrf RED"
```
The `S>* 10.39.100.0/24` line is gone from RED. `docker exec clab-multivendor-vrf-site-a curl -s -m 2 10.39.200.10` now prints nothing: the request reaches site-c, but r2 has no way back to site-a in RED. BLUE is untouched (site-b still gets `site-d`). Where did the route go? `docker exec clab-multivendor-vrf-r2 vtysh -c "show running-config"` shows `ip route 10.39.100.0/24 10.39.12.1` at the top level, outside any `vrf` block: in the default table, where no port leads to 10.39.12.1. Fix it:
```
docker exec -i clab-multivendor-vrf-r2 vtysh < changes/r2-red-route-fix.vtysh
```
`show ip route vrf RED` lists the route again, and site-a gets `site-c`.

**6. Optional: watch both VRFs on the wire.** In Ubuntu's Terminal app, capture both r1 - r2 links for 15 seconds:
```
sudo containerlab capture --name multivendor-vrf --target r2:eth1 --target r2:eth2 --duration 15s -w - > "$HOME/neo-mvvrf.pcapng"
```
Within the 15 seconds, run the two `curl` commands from exercise 1. In Wireshark (filter `http`) the two requests look identical, the same source, destination and page, except for the interface: one on `r2:eth1` (RED), one on `r2:eth2` (BLUE). The frame details name the interface.

## What this lab does not do

- No route leaking between RED and BLUE (lesson NEO-12 does that on SR Linux, in `vrf-two-tables`).
- No routing protocol inside the VRFs, no MPLS and no BGP VPNs: each VRF has one static route on each router.
- No Junos or EOS device; the lesson shows their commands as text only.
- A veth pair carries each link; there is no real switch or cable.

## Troubleshooting

1. **Deploy prints `Failed to execute command command="ip link add RED type vrf table 10"`, and `show vrf` on r2 says `inactive`.** The kernel has no VRF support loaded. On the NEO lab VM, load it and redeploy: `sudo modprobe vrf`, then `containerlab redeploy -c -t multivendor-vrf.clab.yml`. (A kernel without the `vrf` module cannot run r2's half of this lab; r1's half still works.)
2. **site-a gets nothing back from `curl`.** SR Linux takes 1 to 2 minutes to start. Wait and try again. If it still fails, check both route tables (exercises 2 and 3) for the static routes.
3. **A change command says `No such file or directory`, or it hangs and nothing changes.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-vrf`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`: without `-i`, `vtysh` never gets the file and just waits (press Ctrl+C).
4. **After exercise 5 RED still does not work.** Run `r2-red-route-fix.vtysh` again, or reset the lab with `containerlab redeploy -c -t multivendor-vrf.clab.yml`.
5. **`show running-config` on r2 also lists `router pim vrf RED` and `router pim vrf BLUE`.** That is FRR's own default output for each VRF; this lab does not use PIM.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-vrf
```
```
containerlab destroy --cleanup -t multivendor-vrf.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-vrf` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-vrf` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-vrf/clab-multivendor-vrf
```
Your capture files in your Home folder are not touched.
