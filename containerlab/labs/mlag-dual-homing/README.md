# Lab: One host, two switches, one bundle (ESI-LAG)

**Folder:** `labs/mlag-dual-homing/`  **Lab file:** `mlag-dual-homing.clab.yml`  **Lesson:** NEO-44 Switch Stacking and MLAG  **Lab version:** 1.0.0 (2026-11-27)

> **Status of this lab (kit 1.2.6):** checked on the build machine only in part. SR Linux accepted both leaf configurations (`commit validate`: "All changes are valid"), the lab file passes the kit's lint, and the scripts pass a syntax check. The build machine's kernel has no bonding driver (h1's `bond0`) and no `dummy` device (SR Linux's `system0`, which VXLAN needs), so the lab could **not** run there end to end. The NEO lab VM's Ubuntu kernel has both. The expected results below are what the configuration is built to do; they are confirmed, and the sample captures recorded, on the first VM run. Until then, treat the outputs quoted here as expected, not measured.

**What runs and what does not:** the lab runs two real Nokia SR Linux systems (leaf1, leaf2) and three Linux hosts. **SR Linux has no MLAG.** It does the same job with **ESI-LAG**, the standards-based way (EVPN multihoming, RFC 7432): each leaf puts its link to h1 into `lag1` with the **same LACP system ID**, and both leaves declare that link as one **Ethernet segment** (the same ESI), which they announce to each other over BGP EVPN. h1 runs an ordinary Linux LACP bond (`bond0`) over its two links and sees one partner: one bundle. There is no peer link, no MLAG keepalive and no stacking cable; the leaves share the Layer 2 segment over VXLAN. **There is no Arista, Cisco or Juniper switch in this lab**; the lesson shows MLAG and stacking on those as text.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** the full lab runs **two** SR Linux systems, which together need about 4 GB (about 1.9 GB each, measured in other labs). Close other programs you do not need, and run no other lab at the same time. **If your VM has 8 GB:** do not deploy the full file. Use the lighter topology `mlag-dual-homing-lite.clab.yml` (one SR Linux leaf and a Linux leaf). See **Lighter topology** below.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/mlag-dual-homing/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 2 to 3 more minutes** for both leaves to start, BGP to come up and h1's bond to bundle. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
             leaf1  e1/3 ============== e1/3  leaf2         10.44.12.0/30, iBGP EVPN (AS 65044), VXLAN VNI 10044
            /     \                           /     \
       e1/2        e1/1                   e1/1        e1/2
        |            \                     /            |
       h2             eth1   [ bond0 ]   eth2           h3
   10.44.0.12             \     h1      /           10.44.0.13
                           10.44.0.11 (one LACP bundle over two switches)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| leaf1 | SR Linux: `lag1` = ethernet-1/1 (to h1 eth1), LACP system ID 02:00:00:44:00:aa, key 44; Ethernet segment `es-h1` (ESI 00:44:44:44:44:44:44:44:44:01, all-active); mac-vrf `lan` (lag1.0, ethernet-1/2.0 to h2, VXLAN VNI 10044); system0 10.44.255.1, ethernet-1/3 10.44.12.1/30, iBGP EVPN to leaf2 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| leaf2 | SR Linux, the same: `lag1` = ethernet-1/1 (to h1 eth2) with the **same** system ID and key, the **same** ESI; ethernet-1/2 to h3; system0 10.44.255.2, ethernet-1/3 10.44.12.2/30 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell |
| h1 | Linux host, `bond0` (mode 802.3ad = LACP, fast) over eth1 and eth2, 10.44.0.11/24 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| h2 | Linux host, 10.44.0.12/24, single-homed on leaf1 | same | Attach Shell |
| h3 | Linux host, 10.44.0.13/24, single-homed on leaf2 | same | Attach Shell |

All IPv4 addresses are private (RFC 1918); the AS number 65044 is a private AS. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **leaf1 and leaf2 each show twice under Running Labs**; the second entry is SR Linux's internal helper, ignore it.

**How the trick works.** LACP lets a host bundle links only if every link reports the same partner (system ID and key). The two leaves are separate boxes, so they agree on purpose: same `system-id-mac`, same `admin-key` on lag1. The ESI tells EVPN that the two lag1s are one segment: the leaves exchange Ethernet-segment routes, elect one of them to forward floods into the segment (the designated forwarder), and both advertise h1's MAC address for the segment, so traffic toward h1 can use either leaf. That is what MLAG does with a peer link and a vendor protocol.

## Files

- `mlag-dual-homing.clab.yml` - the full lab drawing (two SR Linux leaves, ESI-LAG, EVPN and VXLAN).
- `mlag-dual-homing-lite.clab.yml` - the lighter drawing: leaf1 is still SR Linux, leaf2 is Linux. Use this on an 8 GB virtual machine.
- `configs/leaf1-srl.cli`, `configs/leaf2-srl.cli` - the two SR Linux leaves in the full lab: lag1 with LACP, the Ethernet segment, the underlay and BGP EVPN, VXLAN, and the mac-vrf `lan`. `configs/leaf1-lite.cli` and `configs/leaf2-bridge.sh` are the lighter lab: the same LACP system ID toward h1, with a plain Layer 2 peer link instead of EVPN and VXLAN.
- `changes/` - the exercise changes. In the full lab, apply them to leaf2 with `docker exec -i ... sr_cli < changes/<file>`. In the lighter lab, run the matching `changes/<file>.sh` instead (`leaf2-member-down`, `leaf2-member-up`, `leaf2-other-system-id`, `leaf2-system-id-undo`).
- `scripts/make-captures.sh` - records the sample captures on the **full** lab. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about three minutes, puts every change back at the end, and keeps a recording only when it succeeds (a failed one prints FAIL). On the lighter lab it checks that leaf2 is Linux and does not write into `captures/` (the samples were recorded on the full lab).
- `mlag-dual-homing.drawio` and `mlag-dual-homing.png` - the prepared diagram; the oval marks h1's one bundle over two switches.
- `captures/` - **no sample captures yet** (see the status note above); `scripts/make-captures.sh` records `mlag-1-member-leaf1.pcapng`, `mlag-1-member-leaf2.pcapng`, `mlag-2-leaf2-member-down.pcapng` and `mlag-3-two-system-ids.pcapng` there.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `mlag-dual-homing` > right-click `mlag-dual-homing.clab.yml` > **Deploy**. For the lighter lab, right-click `mlag-dual-homing-lite.clab.yml` instead (or, in a terminal from this folder: `containerlab deploy -t mlag-dual-homing-lite.clab.yml`). Deploy only one of the two files, not both. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-mlag-dual-homing-h1 ping -c 2 10.44.0.13
  ```
  Two replies. If there are none, the leaf is still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/mlag-dual-homing
  ```
  ```
  containerlab redeploy -c -t mlag-dual-homing.clab.yml
  ```
  If you started the lighter lab, use `mlag-dual-homing-lite.clab.yml` in that command instead.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | Where | Command |
|---|---|---|
| The host's bond: mode, partner, aggregator of each member | h1 | `cat /proc/net/bonding/bond0` |
| The leaf's half of the bundle | leaf1, leaf2 (`sr_cli`) | `show lag lag1` and `show lag lag1 lacp-state` |
| The Ethernet segment, its peers and the designated forwarder | leaf1, leaf2 | `show system network-instance ethernet-segments detail` |
| BGP EVPN between the leaves | leaf1, leaf2 | `show network-instance default protocols bgp neighbor` |
| Where each MAC was learnt (local, or the other leaf over VXLAN) | leaf1, leaf2 | `show network-instance lan bridge-table mac-table all` |
| Wireshark filter | | `lacp` |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/mlag-dual-homing`).

**1. One bundle on the host.**
```
docker exec clab-mlag-dual-homing-h1 cat /proc/net/bonding/bond0
```
Expected: `Bonding Mode: IEEE 802.3ad Dynamic link aggregation`; under **Active Aggregator Info** `Number of ports: 2` and `Partner Mac Address: 02:00:00:44:00:aa`; for each slave (eth1, eth2) the **same Aggregator ID** and the same partner system. h1 cannot tell that its two links end on two different switches.

**2. Each leaf's half.**
```
docker exec clab-mlag-dual-homing-leaf1 sr_cli "show lag lag1 lacp-state"
```
Expected: one member, `ethernet-1/1`, `IN_SYNC`, system ID `02:00:00:44:00:aa`, partner = h1's bond. The same on leaf2. Then the segment:
```
docker exec clab-mlag-dual-homing-leaf1 sr_cli "show system network-instance ethernet-segments detail"
```
Expected: `es-h1` up, all-active, ESI `00:44:44:44:44:44:44:44:44:01`, the other leaf (10.44.255.2) as a peer, and which leaf is the designated forwarder.

**3. Both leaves carry h1's traffic.** Ping from h1 to both single-homed hosts:
```
docker exec clab-mlag-dual-homing-h1 ping -c 2 10.44.0.12
```
```
docker exec clab-mlag-dual-homing-h1 ping -c 2 10.44.0.13
```
Then look at leaf1's MAC table: `docker exec clab-mlag-dual-homing-leaf1 sr_cli "show network-instance lan bridge-table mac-table all"`. h2's MAC is local (ethernet-1/2.0), h3's arrives over VXLAN from leaf2, and h1's MAC belongs to the Ethernet segment (lag1), whichever leaf h1's bond used.

**4. Lose one switch's link.** Disable leaf2's member:
```
docker exec -i clab-mlag-dual-homing-leaf2 sr_cli < changes/leaf2-member-down.cli
```
```
docker exec clab-mlag-dual-homing-h1 ping -c 2 10.44.0.13
```
Expected: h1's bond keeps one member (eth1, to leaf1), and h3, on leaf2, is still reached: through leaf1 and across VXLAN. Put it back:
```
docker exec -i clab-mlag-dual-homing-leaf2 sr_cli < changes/leaf2-member-up.cli
```

**5. The leaves disagree (the lesson's practice).** Give leaf2 a different LACP system ID:
```
docker exec -i clab-mlag-dual-homing-leaf2 sr_cli < changes/leaf2-other-system-id.cli
```
```
docker exec clab-mlag-dual-homing-h1 cat /proc/net/bonding/bond0
```
Expected: h1 now hears two different partners (02:00:00:44:00:aa and 02:00:00:44:00:bb), puts eth1 and eth2 in **two aggregators**, and uses only one of them: the bundle is gone, though every link is up. This is the classic MLAG mistake, and why both switches must present one identity. Put it back:
```
docker exec -i clab-mlag-dual-homing-leaf2 sr_cli < changes/leaf2-system-id-undo.cli
```

## Sample captures

None yet: they are recorded on the first VM run (`sudo bash scripts/make-captures.sh`), all on h1's two members, filter `lacp`:

| File | Recorded on | What it is meant to show |
|---|---|---|
| `mlag-1-member-leaf1.pcapng`, `mlag-1-member-leaf2.pcapng` | h1:eth1, h1:eth2 | the same 12 seconds on both members: LACPDUs from leaf1 and from leaf2 with the **same** actor system ID 02:00:00:44:00:aa and key 44; h1's pings to h2 and h3 |
| `mlag-2-leaf2-member-down.pcapng` | h1:eth1 | leaf2's member is disabled 4 s in; the bundle keeps the member to leaf1 and h1 still reaches h3 |
| `mlag-3-two-system-ids.pcapng` | h1:eth2 | leaf2 changes its system ID to 02:00:00:44:00:bb 4 s in; h1's member to leaf2 leaves the bundle |

## What this lab does not do

- No MLAG and no stacking: SR Linux has neither. ESI-LAG gives the host the same result (one bundle over two switches) with EVPN instead of a peer link. The lesson shows MLAG (Arista, Cisco vPC) and stacking (Juniper Virtual Chassis) as text.
- No peer link, keepalive or split-brain test; no designated-forwarder tuning; no Layer 3 (IRB) on the leaves.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** The leaves take 2 to 3 minutes to start and bring up BGP. Wait and try again. If you deployed the full lab on an 8 GB virtual machine and it is slow or stuck, destroy it and deploy `mlag-dual-homing-lite.clab.yml` instead. Check memory with `free -h` (two SR Linux systems need about 4 GB), then `docker exec clab-mlag-dual-homing-leaf1 sr_cli "show network-instance default protocols bgp neighbor"`: the neighbor 10.44.255.2 should be `established`.
2. **`cat /proc/net/bonding/bond0` says `No such file or directory`.** h1's bond was not created: this computer's kernel has no bonding driver. The NEO lab VM (Ubuntu 24.04) has one; check with `lsmod | grep bonding` in Ubuntu's Terminal (empty is fine, it loads on demand), and redeploy.
3. **A change command says `No such file or directory`, or `Input not from a terminal/file/pipe`.** Run it from the lab folder so that `changes/...` is found, and keep the `-i` in `docker exec -i`.
4. **After exercise 4 or 5 the bundle does not come back.** Run the matching undo (`leaf2-member-up.cli`, `leaf2-system-id-undo.cli`) and wait 10 seconds; or reset the lab with `containerlab redeploy -c -t mlag-dual-homing.clab.yml`.
5. **The capture command says the interface does not exist.** Use h1's Linux names: `h1:eth1`, `h1:eth2`.

## Lighter topology (8 GB virtual machines)

Use `mlag-dual-homing-lite.clab.yml` when the full lab would be too large (two SR Linux leaves, about 4 GB together, on an 8 GB virtual machine). leaf1 is still SR Linux and still uses the same LACP system ID and key toward h1, so `show lag lag1` on leaf1 and the ping commands do not change. leaf2 is Linux: a bond that advertises the same system ID, plus a plain Layer 2 peer link to leaf1. The three exercises still work (one bundle, one member down, two system IDs), using the `.sh` files in `changes/`. `scripts/make-captures.sh` does not write into `captures/` on the lighter lab (the samples were recorded on the full lab).

The lighter lab does **not** run ESI-LAG, BGP EVPN or VXLAN: those need two SR Linux leaves. On a 12 GB (or larger) virtual machine, use the full file to see the Ethernet segment, the designated forwarder and MAC addresses learnt over VXLAN.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/mlag-dual-homing
```
```
containerlab destroy --cleanup -t mlag-dual-homing.clab.yml
```
`--cleanup` also removes the generated `clab-mlag-dual-homing` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-mlag-dual-homing` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/mlag-dual-homing/clab-mlag-dual-homing
```
Your capture files in your Home folder are not touched.
