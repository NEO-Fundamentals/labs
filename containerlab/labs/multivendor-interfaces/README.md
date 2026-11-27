# Lab: interface address and state on two routers (FRR), with Junos and EOS shown as text

**Folder:** `labs/multivendor-interfaces/`  **Lab file:** `multivendor-interfaces.clab.yml`  **Lesson:** NEO-34 Multi-vendor interface addressing and show commands  **Lab version:** 1.0.0 (2026-11-26)


**What runs and what does not:** the lab runs real interfaces on FRR (open-source routing software) and Linux. **Junos and EOS appear only as configuration text for comparison (below). They are not run, and there is no Junos or EOS in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-interfaces/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute, plus about 20 seconds for FRR to apply its address file.

## What this lab builds

```
 L (FRR)  10.0.2.1/30  ----  10.0.2.2/30  R (FRR)
   |
   eth2  10.0.3.1/24 (shut down) --- spare host (unused far end)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| l | FRR router L. eth1 has 10.0.2.1/30; eth2 has 10.0.3.1/24 and is shut down | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| r | FRR router R. eth1 has 10.0.2.2/30 | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| spare | A Linux host on the far end of L's eth2, so that port has a cable but starts shut down | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `multivendor-interfaces.clab.yml` - the lab drawing.
- `configs/l-frr.conf`, `configs/r-frr.conf` - each router's addresses and the shutdown on L's eth2.
- `changes/` - small command files you feed to R: `r-typo.txt` (wrong address), `r-fix.txt`, `r-shutdown.txt`, `r-no-shutdown.txt`.
- `scripts/make-captures.sh` - re-records the sample captures (the lab must be running).
- `multivendor-interfaces.drawio` and `multivendor-interfaces.png` - the prepared diagram.
- `captures/` - sample captures from L's cable: `interfaces-ping-ok.pcapng`, `interfaces-ping-typo.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-interfaces` > right-click `multivendor-interfaces.clab.yml` > **Deploy**. Wait for the three green dots, then about 20 more seconds: FRR applies its address file a little after the containers start (`docker exec clab-multivendor-interfaces-l ip -br addr` shows `10.0.2.1/30` on eth1 when it is ready). Run one lab at a time.
- **Reset to the lesson start:** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/multivendor-interfaces
  ```
  ```
  containerlab redeploy -c -t multivendor-interfaces.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | FRR (runs in this lab) | Junos (text only, not run) | EOS (text only, not run) |
|---|---|---|---|
| Set an address | `interface eth1` then `ip address 10.0.2.1/30` | `set interfaces ge-0/0/1 unit 0 family inet address 10.0.2.1/30` | `interface Ethernet1`, `no switchport`, `ip address 10.0.2.1/30` |
| Turn a port off | `shutdown` | `set interfaces ge-0/0/2 disable` | `shutdown` |
| One-line list | `show interface brief` | `show interfaces terse` (Admin and Link columns) | `show ip interface brief` (Status and Protocol columns) |
| Connected routes | `show ip route connected` | `show route protocol direct` | `show ip route connected` |

Not affiliated with or endorsed by Juniper, Arista or the FRRouting project. Junos and EOS syntax is shown for comparison only.

## Exercises

Open each router's shell with right-click > **Access** > **Attach Shell**, or use `docker exec -it clab-multivendor-interfaces-l vtysh`.

**1. Read the interface two ways.** On L:
```
docker exec clab-multivendor-interfaces-l vtysh -c "show interface brief"
```
```
docker exec clab-multivendor-interfaces-l ip -br addr
```
```
docker exec clab-multivendor-interfaces-l ip -br link
```
eth1 is up with 10.0.2.1/30. eth2 is down (admin shutdown) with 10.0.3.1/24. A /30 holds four addresses: network .0, usable .1 and .2, broadcast .3.

**2. Prove the link.**
```
docker exec clab-multivendor-interfaces-l ping -c 2 10.0.2.2
```
Two replies. Look at the detail: `docker exec clab-multivendor-interfaces-l vtysh -c "show interface eth1"` says the interface is up and the line protocol is up.

**3. The wrong subnet.** Give R a typo address (10.0.2.6/30, which is in the next /30):
```
docker exec -i clab-multivendor-interfaces-r vtysh < changes/r-typo.txt
```
Both ports still show up and addressed. Make L forget R's old hardware address, then ping:
```
docker exec clab-multivendor-interfaces-l ip neigh flush all
```
```
docker exec clab-multivendor-interfaces-l ping -c 2 -W 1 10.0.2.2
```
There is no answer (L's ARP requests for .2 go unanswered), and pinging `10.0.2.6` (`docker exec clab-multivendor-interfaces-l ping -c 2 -W 1 10.0.2.6`) fails at once with `ping: sendto: Network unreachable`: L's only routes are 10.0.2.0/30 and the management network 172.20.20.0/24, and it has no default route, so it has nowhere to send the packet. Compare the connected routes on both ends: `show ip route connected` shows 10.0.2.0/30 on L and 10.0.2.4/30 on R. Different subnets, no conversation. Fix it:
```
docker exec -i clab-multivendor-interfaces-r vtysh < changes/r-fix.txt
```

**4. Admin state versus line state.** Shut down R's side:
```
docker exec -i clab-multivendor-interfaces-r vtysh < changes/r-shutdown.txt
```
On L, `show interface brief` may still list eth1 as up (the Status column follows the admin state), but the detail view shows the line protocol is down, and Linux shows NO-CARRIER:
```
docker exec clab-multivendor-interfaces-l vtysh -c "show interface eth1"
```
```
docker exec clab-multivendor-interfaces-l ip -br link show eth1
```
The lesson's practice question: admin up, line protocol down, address correct. Look at the link and the far end first, not your own config. Bring it back with `changes/r-no-shutdown.txt` the same way.

**5. Capture the typo.** In Ubuntu's Terminal app start the capture first, then run the `ip neigh flush all` and the ping from L:
```
sudo containerlab capture --name multivendor-interfaces --target l:eth1 --duration 10s -w - > "$HOME/neo-typo.pcapng"
```
The sample `captures/interfaces-ping-typo.pcapng` shows ARP requests for 10.0.2.2 with no reply.

## Troubleshooting

1. **The first ping between `l` and `r` fails, or `show interface brief` shows no address.** FRR applies its address file 10 to 20 seconds after the containers start. Wait, then check again.
2. **A file in `changes/` seems to do nothing.** Feed it to vtysh with `-i` so Docker passes the file in: `docker exec -i clab-multivendor-interfaces-r vtysh < changes/r-fix.txt` (change the node and file name as needed). Without `-i` the file is ignored.
3. **After `r-typo.txt` the ping fails.** That is the exercise: the typo puts the wrong address on the interface. Apply `changes/r-fix.txt`, and use `changes/r-no-shutdown.txt` after `r-shutdown.txt`.
4. **The typo capture shows no ARP request.** The router remembered the neighbour from the earlier ping. Clear it first: `docker exec clab-multivendor-interfaces-l ip neigh flush all`, then ping again.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-interfaces
```
```
containerlab destroy --cleanup -t multivendor-interfaces.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-interfaces` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-interfaces` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-interfaces/clab-multivendor-interfaces
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- No Junos or EOS device runs here; the table above is text.
- A veth pair carries the link, so shutting R's port also drops L's carrier; a real cable would need the far end's transmitter turned off.
