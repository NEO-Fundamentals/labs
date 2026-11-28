# Lab: VLANs and 802.1Q trunks

**Folder:** `labs/vlans-trunks/`  **Lab file:** `vlans-trunks.clab.yml`  **Lesson:** NEO-07 VLANs and 802.1Q Trunks  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs two real Nokia SR Linux systems (sw1, sw2) used as Layer 2 switches, and four Linux hosts. The VLAN tags on the trunk are real 802.1Q tags, added and removed by SR Linux. **There is no Arista EOS, Juniper Junos or Cisco switch in this lab**, and no router: the hosts never leave their VLAN.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** the full lab runs **two** SR Linux systems, which together need about 4 GB (about 1.9 GB each, measured). On an 8 GB virtual machine that can leave too little memory free (the two switches may fail to start, and the machine may become unresponsive). Close other programs you do not need, and run no other lab at the same time. If your virtual machine has 8 GB, use the **lighter topology** below (`vlans-trunks-lite.clab.yml`): one SR Linux switch and a Linux sw2 that uses one bridge per VLAN, which fits comfortably.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/vlans-trunks/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for both switches to start forwarding. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 host-1 (VLAN 10) ---- e1/1                         e1/1 ---- host-3 (VLAN 10)
 10.7.0.11                sw1 e1/3 ======== e1/3 sw2                10.7.0.12
 host-2 (VLAN 30) ---- e1/2     trunk:          e1/2 ---- host-4 (VLAN 30)
 10.7.0.31                      VLAN 30 tagged,             10.7.0.32
                                VLAN 10 untagged (native)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-1 | Linux host, 10.7.0.11/24, on sw1's access port ethernet-1/1 (VLAN 10) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| host-2 | Linux host, 10.7.0.31/24, on sw1's access port ethernet-1/2 (VLAN 30) | same | Attach Shell |
| sw1 | SR Linux switch: VLAN 10 = mac-vrf `vlan10` (ethernet-1/1.0, trunk ethernet-1/3.1 untagged), VLAN 30 = mac-vrf `vlan30` (ethernet-1/2.0, trunk ethernet-1/3.30 tagged 30) | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| sw2 | SR Linux switch, the same layout: host-3 on ethernet-1/1 (VLAN 10), host-4 on ethernet-1/2 (VLAN 30), the trunk on ethernet-1/3 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell |
| host-3 | Linux host, 10.7.0.12/24, on sw2's ethernet-1/1 (VLAN 10) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| host-4 | Linux host, 10.7.0.32/24, on sw2's ethernet-1/2 (VLAN 30) | same | Attach Shell |

**All four hosts are in one subnet, 10.7.0.0/24, on purpose.** By IP alone every host could reach every other one; whatever stops them is the VLANs. In a real network each VLAN would normally have its own subnet and a router between them.

On SR Linux a VLAN on a switch is a **mac-vrf** network-instance: a separate MAC table with its own ports. A port that belongs to one VLAN and carries untagged frames (an **access port**) is subinterface 0 of an untagged interface. The trunk port has `vlan-tagging true` and one subinterface per VLAN: `.30` matches frames tagged with VLAN ID 30, and `.1` matches untagged frames, which makes VLAN 10 the **native VLAN** of this trunk.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **sw1 and sw2 each show twice under Running Labs**; the second entry is SR Linux's internal helper, ignore it.

## Files

- `vlans-trunks.clab.yml` - the full lab drawing (two SR Linux switches).
- `vlans-trunks-lite.clab.yml` - the lighter drawing: sw1 is still SR Linux, sw2 is Linux with one bridge per VLAN and a tagged subinterface on the trunk (same idea as the path-trace-access-port lab). Same hosts, addresses, VLANs and trunk. Use this on an 8 GB virtual machine.
- `configs/sw1-srl.cli`, `configs/sw2-srl.cli` - the two SR Linux switches in the full lab (the same file twice): access ports, the trunk with its two subinterfaces, and the mac-vrfs `vlan10` and `vlan30`. `configs/sw2-bridge.sh` builds the same layout on the Linux bridge in the lighter lab.
- `changes/` - the exercise changes. In the full lab, apply them to sw2 with `docker exec -i ... sr_cli < changes/<file>.cli`. In the lighter lab, run the matching `changes/<file>.sh` instead (`sw2-native-30`, `sw2-native-undo`, `sw2-trunk-drop-30`, `sw2-trunk-undo`).
- `scripts/make-captures.sh` - re-records the sample captures on the **full** lab. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays). On the lighter lab it checks that sw2 is Linux and leaves the samples unchanged (they were recorded on the full lab).
- `vlans-trunks.drawio` and `vlans-trunks.png` - the prepared diagram.
- `captures/` - three sample captures, recorded on the trunk (sw1's ethernet-1/3): `vlan-1-trunk.pcapng`, `vlan-2-native-mismatch.pcapng`, `vlan-3-vlan30-not-on-trunk.pcapng`.

## Start, reset, stop

- **Start (full lab):** Containerlab panel > **Undeployed Local Labs** > `labs` > `vlans-trunks` > right-click `vlans-trunks.clab.yml` > **Deploy**. For the lighter lab, right-click `vlans-trunks-lite.clab.yml` instead (or, in a terminal from this folder: `containerlab deploy -t vlans-trunks-lite.clab.yml`). Deploy only one of the two files, not both. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-vlans-trunks-host-1 ping -c 2 10.7.0.12
  ```
  Two replies. If there are none, the switches are still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/vlans-trunks
  ```
  ```
  containerlab redeploy -c -t vlans-trunks.clab.yml
  ```
  For the lighter lab, use `vlans-trunks-lite.clab.yml` in that command instead.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | SR Linux (sw1, sw2: `sr_cli`) |
|---|---|
| The VLANs (mac-vrfs) and whether they are up | `show network-instance summary` |
| The ports of one interface and their tags | `show interface ethernet-1/3` |
| The MAC table of one VLAN | `show network-instance vlan10 bridge-table mac-table all` |
| The configuration of the trunk | `info interface ethernet-1/3` |
| Wireshark filters | `vlan` (tagged frames only), `vlan.id == 30`, `not vlan` (untagged only) |

Other vendors use other words for the same ideas: an access port in VLAN 10, a trunk with an allowed-VLAN list and a native VLAN. The lesson shows them.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). You can also right-click a host > **Access** > **Attach Shell** and type the part after the container name.

**1. Same VLAN works, other VLAN does not.**
```
docker exec clab-vlans-trunks-host-1 ping -c 2 10.7.0.12
```
```
docker exec clab-vlans-trunks-host-1 ping -c 2 -W 1 10.7.0.32
```
host-1 reaches host-3 (both VLAN 10, on different switches, across the trunk). host-4 is in the same subnet but in VLAN 30: no reply (`100% packet loss`). host-1's ARP question "who has 10.7.0.32?" is flooded only inside VLAN 10, so host-4 never hears it. The same for host-1 to host-2, even though both are on sw1. `docker exec clab-vlans-trunks-host-2 ping -c 2 10.7.0.32` works: VLAN 30 to VLAN 30.

**2. The VLANs on a switch.**
```
docker exec clab-vlans-trunks-sw1 sr_cli "show network-instance summary"
```
`vlan10` and `vlan30`, both `mac-vrf`, `up` (plus `mgmt`, the management network). Then the trunk:
```
docker exec clab-vlans-trunks-sw1 sr_cli "show interface ethernet-1/3"
```
`ethernet-1/3.1` in `vlan10 (mac-vrf)` with `Encapsulation : null` (untagged) and `ethernet-1/3.30` in `vlan30 (mac-vrf)` with `Encapsulation : vlan-id 30`.

**3. MAC learning is per VLAN.**
```
docker exec clab-vlans-trunks-sw1 sr_cli "show network-instance vlan10 bridge-table mac-table all"
```
After the pings in exercise 1, host-1's MAC is learnt on `ethernet-1/1.0` and host-3's on `ethernet-1/3.1` (the trunk). A third entry on `ethernet-1/3.1` is sw2's own trunk port, which sends untagged frames of its own. (Compare with each host's MAC: `docker exec clab-vlans-trunks-host-1 cat /sys/class/net/eth1/address`.) Run the same for `vlan30`: host-2's MAC on `ethernet-1/2.0`, host-4's on `ethernet-1/3.30`. Each VLAN has its own table. (Entries age out after 300 seconds without traffic; ping again if a table is empty.)

**4. See the tags.** In Ubuntu's Terminal app, capture the trunk for 15 seconds:
```
sudo containerlab capture --name vlans-trunks --target sw1:e1-3 --duration 15s -w - > "$HOME/neo-trunk.pcapng"
```
Within the 15 seconds, in VS Code's terminal, ping once in each VLAN:
```
docker exec clab-vlans-trunks-host-1 ping -c 2 10.7.0.12
```
```
docker exec clab-vlans-trunks-host-2 ping -c 2 10.7.0.32
```
(Containerlab names SR Linux's ethernet-1/3 `e1-3` in Linux.) Open the file in Wireshark. The VLAN 10 frames have no tag: Ethernet II, then IPv4 or ARP. The VLAN 30 frames have an extra **802.1Q Virtual LAN** header between the source MAC and the type: type 0x8100, **ID: 30**, priority 0. Filter `vlan` to see only the tagged ones. On the access ports (for example `host-2:eth1`) the same VLAN 30 frames have no tag: the switch adds it on the trunk and removes it on the far side.

**5. A native VLAN that does not match.** Tell sw2 that untagged frames on the trunk belong to VLAN 30 (sw1 still sends VLAN 10 untagged):
```
cd ~/labs-main/containerlab/labs/vlans-trunks
```
```
docker exec -i clab-vlans-trunks-sw2 sr_cli < changes/sw2-native-30.cli
```
```
docker exec clab-vlans-trunks-host-1 ping -c 2 -W 1 10.7.0.32
```
```
docker exec clab-vlans-trunks-host-1 ping -c 2 -W 1 10.7.0.12
```
Now host-1 (VLAN 10 on sw1) **reaches host-4 (VLAN 30 on sw2)**, and no longer host-3. Its untagged frames cross the trunk and land in the wrong VLAN: traffic leaks between VLANs. (If the first ping still fails, the hosts remember old MAC addresses: wait a few seconds and run it again.) Put it back:
```
docker exec -i clab-vlans-trunks-sw2 sr_cli < changes/sw2-native-undo.cli
```
The fix is the same at any vendor: match the native VLAN at both ends, or tag every VLAN and leave the native VLAN unused.

**6. VLAN 30 is not on the trunk at one end (the lesson's practice).** Remove VLAN 30 from sw2's trunk (on SR Linux: delete the tagged subinterface; elsewhere: take 30 off the trunk's allowed list):
```
docker exec -i clab-vlans-trunks-sw2 sr_cli < changes/sw2-trunk-drop-30.cli
```
```
docker exec clab-vlans-trunks-host-2 ping -c 2 -W 1 10.7.0.32
```
```
docker exec clab-vlans-trunks-host-1 ping -c 2 10.7.0.12
```
VLAN 30 fails, VLAN 10 still works across the same trunk, so the trunk itself is up. Check VLAN 30 at both ends: `show interface ethernet-1/3` on sw1 still lists `ethernet-1/3.30`, on sw2 it does not. sw1 keeps sending host-2's ARP questions tagged 30, and sw2 drops them. Put it back:
```
docker exec -i clab-vlans-trunks-sw2 sr_cli < changes/sw2-trunk-undo.cli
```

## Sample captures

All three are recorded on the trunk, sw1:e1-3. Open them in Wireshark with File > Open. Add a column for the VLAN ID: right-click **ID** in the 802.1Q header > **Apply as Column**.

| File | Frames | What it shows |
|---|---|---|
| `vlan-1-trunk.pcapng` | 23 | host-1 pings host-3: ARP and three echo pairs untagged (VLAN 10, native); then host-2 pings host-4: ARP and echoes tagged with VLAN ID 30 |
| `vlan-2-native-mismatch.pcapng` | 21 | sw2 maps untagged frames to VLAN 30: host-1's untagged ARP goes out (frame 1) and comes straight back tagged 30 (frame 2), because sw2 floods it in VLAN 30, trunk included; host-4 answers and the ping works; host-1's ARP for host-3 gets no answer |
| `vlan-3-vlan30-not-on-trunk.pcapng` | 13 | sw2 has no VLAN 30 on the trunk: host-2's ARP for 10.7.0.32 goes out tagged 30 three times with no answer; host-1's ping to host-3 (untagged, VLAN 10) works |

The other frames are background traffic (LLDP between the switches, IPv6 group reports); the filter `arp or icmp` hides them.


## Lighter topology (8 GB virtual machines)

Use `vlans-trunks-lite.clab.yml` when the full lab would be too large (two SR Linux switches, about 4 GB together, on an 8 GB virtual machine). sw1 is the same SR Linux switch as in the full lab, so the SR Linux commands in exercises 2 and 3 are unchanged. sw2 is Linux, with one bridge per VLAN (`br10`, `br30`) and a tagged subinterface `eth3.30` on the trunk. That does the same job with a few megabytes of memory, and it works on kernels that do not support a single VLAN-aware bridge (`vlan_filtering`). The hosts, addresses, VLANs and the trunk (VLAN 30 tagged, VLAN 10 untagged/native) are unchanged, and the container names stay `clab-vlans-trunks-*`, so the ping commands do not change.

On the Linux sw2, the ports are named `eth1` (host-3, VLAN 10), `eth2` (host-4, VLAN 30) and `eth3` (the trunk). To see the VLANs on the trunk:

```
docker exec clab-vlans-trunks-sw2 ip -br link
```
You should see `br10`, `br30`, `eth3` and `eth3.30`. `eth3` is the untagged (native) VLAN 10 side of the trunk; `eth3.30` is VLAN 30 tagged. `bridge link` shows `eth1` and `eth3` in `br10`, and `eth2` and `eth3.30` in `br30`.

You should see VLAN 10 as `PVID Egress Untagged` and VLAN 30 as a tagged member.

For exercises 5 and 6, run the shell scripts instead of the SR Linux CLI files (from the lab folder):

```
bash changes/sw2-native-30.sh
```

```
bash changes/sw2-native-undo.sh
```

```
bash changes/sw2-trunk-drop-30.sh
```

```
bash changes/sw2-trunk-undo.sh
```

`scripts/make-captures.sh` detects which sw2 is running and applies the matching change file. On the lighter lab it does not overwrite the sample captures (they were recorded on the full lab).

## What this lab does not do

- No spanning tree, no voice VLAN, no VTP/GVRP/MVRP, no QinQ (double tags), no link aggregation.
- No routing between VLANs: there is no router and no gateway.
- No Junos, EOS or Cisco switch; the lesson shows their commands as text.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** The SR Linux switch (or switches) take 1 to 2 minutes to start. Wait and try again. If you deployed the full lab (two SR Linux systems) on an 8 GB virtual machine and it is slow or stuck, destroy it and deploy `vlans-trunks-lite.clab.yml` instead. Check memory with `free -h`: two SR Linux systems need about 4 GB.
2. **A change command says `No such file or directory`, or `Input not from a terminal/file/pipe`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/vlans-trunks`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`.
3. **After exercise 5 or 6 a ping that should work fails.** Run the matching undo (`sw2-native-undo.cli`, `sw2-trunk-undo.cli`). The hosts and switches may remember MAC addresses from the change for a short time: wait a few seconds and ping again, or reset the lab with `containerlab redeploy -c -t vlans-trunks.clab.yml`.
4. **The capture command says the interface does not exist.** Use `sw1:e1-3`, not `sw1:ethernet-1/3`: in Linux the SR Linux port names are shortened.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/vlans-trunks
```
```
containerlab destroy --cleanup -t vlans-trunks.clab.yml
```
If you started the lighter lab, use `vlans-trunks-lite.clab.yml` in that command instead.

`--cleanup` also removes the generated `clab-vlans-trunks` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-vlans-trunks` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/vlans-trunks/clab-vlans-trunks
```
Your capture files in your Home folder are not touched.
