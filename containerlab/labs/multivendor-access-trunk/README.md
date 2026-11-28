# Lab: Access and trunk ports on two kinds of switch (SR Linux and a Linux bridge)

**Folder:** `labs/multivendor-access-trunk/`  **Lab file:** `multivendor-access-trunk.clab.yml`  **Lesson:** NEO-35 Multi-vendor access and trunk ports  **Lab version:** 1.0.0 (2026-11-27)

> **Status of this lab (kit 1.2.7):** checked on the build machine only in part. The SR Linux half ran there: both VLANs up, the trunk sending every frame with its 802.1Q tag (VLAN 10 and VLAN 20 seen on the cable), and the SR Linux change files apply and undo. The build machine's kernel has **no bridge VLAN filtering**, so sw2 (the Linux bridge with VLANs) could not be created there, and no ping across the trunk was seen. The NEO lab VM's Ubuntu kernel has VLAN filtering. The Linux-bridge outputs and the ping results below are what the configuration is built to do; they are confirmed, and the sample captures recorded, on the first VM run. Until then, treat them as expected, not measured.

**What runs and what does not:** sw1 is a real Nokia SR Linux system; sw2 is a Linux bridge with VLAN filtering (the Linux kernel's own switch). Both carry the same two VLANs, and a trunk joins them. The tags on the trunk are real 802.1Q tags. **There is no Arista EOS, Juniper Junos or Cisco switch in this lab**; the lesson shows their commands as text. There is no router: the hosts never leave their VLAN.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** one SR Linux system (about 1.9 GB, measured in other labs) and five small Linux containers. Close other programs you do not need, and run no other lab at the same time.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-access-trunk/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start forwarding. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 h1 (VLAN 10) ---- e1/1                               eth2 ---- h3 (VLAN 10)
 10.35.0.11           sw1 e1/3 ============== eth1 sw2              10.35.0.12
 h2 (VLAN 20) ---- e1/2  SR Linux    trunk:   Linux bridge eth3 ---- h4 (VLAN 20)
 10.35.0.21                     VLAN 10 + 20 tagged                 10.35.0.22
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| h1 | Linux host, 10.35.0.11/24, on sw1's access port ethernet-1/1 (VLAN 10) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| h2 | Linux host, 10.35.0.21/24, on sw1's access port ethernet-1/2 (VLAN 20) | same | Attach Shell |
| sw1 | SR Linux switch: VLAN 10 = mac-vrf `vlan10` (ethernet-1/1.0, trunk ethernet-1/3.10), VLAN 20 = mac-vrf `vlan20` (ethernet-1/2.0, trunk ethernet-1/3.20) | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| sw2 | Linux bridge `br0` with VLAN filtering: eth1 = trunk (VLANs 10 and 20 tagged), eth2 = access VLAN 10, eth3 = access VLAN 20 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| h3 | Linux host, 10.35.0.12/24, on sw2's eth2 (VLAN 10) | same | Attach Shell |
| h4 | Linux host, 10.35.0.22/24, on sw2's eth3 (VLAN 20) | same | Attach Shell |

**All four hosts are in one subnet, 10.35.0.0/24, on purpose.** By IP alone every host could reach every other one; whatever stops them is the VLANs. In a real network each VLAN would normally have its own subnet and a router between them.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **sw1 shows twice under Running Labs**; the second entry is SR Linux's internal helper, ignore it.

**The same ports in two dialects:**

| | SR Linux (sw1) | Linux bridge (sw2) |
|---|---|---|
| A VLAN | a mac-vrf network-instance (`vlan10`) | a VLAN ID on the bridge's ports (VID 10) |
| Access port, VLAN 10 | untagged interface, subinterface `.0` in mac-vrf `vlan10` | `bridge vlan add dev eth2 vid 10 pvid untagged` |
| Trunk port | `vlan-tagging true`, one subinterface per VLAN (`.10` with `vlan encap single-tagged vlan-id 10`, `.20` ...) | `bridge vlan add dev eth1 vid 10` and `vid 20` (tagged: no `untagged`) |
| Allowed VLANs on the trunk | the subinterfaces that exist | the VIDs listed on the port |
| Native (untagged) VLAN on a trunk | a subinterface with `vlan encap untagged` (none here) | a VID with `pvid untagged` on the trunk port (none here) |

`pvid` means "untagged frames that come IN on this port belong to this VLAN"; `untagged` means "frames of this VLAN go OUT of this port without a tag". An access port has both.

## Files

- `multivendor-access-trunk.clab.yml` - the lab drawing. sw2's bridge and its VLANs are created by the `exec` lines of its node.
- `configs/sw1-srl.cli` - sw1: the two access ports, the trunk with its two tagged subinterfaces, the two mac-vrfs.
- `changes/` - the exercise changes. Linux bridge (sw2) files run with `bash changes/<file>`: `sw2-trunk-drop-20.sh` and `sw2-trunk-undo.sh`, `sw2-eth1-access-10.sh` and `sw2-eth1-trunk.sh`. SR Linux (sw1) files are applied with `docker exec -i ... sr_cli < changes/<file>`: `sw1-trunk-drop-20.cli` and `sw1-trunk-undo.cli`.
- `scripts/make-captures.sh` - records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `multivendor-access-trunk.drawio` and `multivendor-access-trunk.png` - the prepared diagram.
- `captures/` - the sample captures, once recorded: `mvat-1-trunk-tags.pcapng`, `mvat-2-vlan20-not-allowed.pcapng`, `mvat-3-access-vs-trunk.pcapng` (see `captures/NOT_YET_RECORDED.md`).

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-access-trunk` > right-click `multivendor-access-trunk.clab.yml` > **Deploy**. Wait for the green dots and 1 to 2 minutes, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-access-trunk-h1 ping -c 2 10.35.0.12
  ```
  Two replies: h1 (on SR Linux) reaches h3 (on the Linux bridge) in VLAN 10. If there are none, SR Linux is still starting: wait 30 seconds and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-access-trunk
  ```
  ```
  containerlab redeploy -c -t multivendor-access-trunk.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | SR Linux (sw1: `sr_cli`) | Linux bridge (sw2) |
|---|---|---|
| Which VLANs exist | `show network-instance summary` | `bridge vlan show` |
| A port: mode and VLANs | `show interface ethernet-1/3` (its subinterfaces and their VLAN IDs) | `bridge vlan show dev eth1` |
| Learned addresses, per VLAN | `show network-instance vlan10 bridge-table mac-table all` | `bridge fdb show br br0 vlan 10` |
| Tags on the trunk, live | - | `tcpdump -e -c 4 -ni eth1` |
| Wireshark filter | `vlan` (or `vlan.id == 20`) | |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-access-trunk`). You can also right-click a node > **Access** > **Attach Shell** and type the part in quotes (SR Linux) or after the container name (Linux).

**1. Same VLAN across two vendors.**
```
docker exec clab-multivendor-access-trunk-h1 ping -c 2 10.35.0.12
```
```
docker exec clab-multivendor-access-trunk-h2 ping -c 2 10.35.0.22
```
```
docker exec clab-multivendor-access-trunk-h1 ping -c 2 -W 1 10.35.0.22
```
Expected: the first two work (VLAN 10 and VLAN 20, each from the SR Linux side to the Linux side); the third fails: h1 (VLAN 10) and h4 (VLAN 20) share a subnet but not a VLAN.

**2. Read both switches.** SR Linux, the trunk port:
```
docker exec clab-multivendor-access-trunk-sw1 sr_cli "show interface ethernet-1/3"
```
`ethernet-1/3.10` and `ethernet-1/3.20` are up, with `Encapsulation : vlan-id 10` and `vlan-id 20` (measured on the build machine). The Linux bridge:
```
docker exec clab-multivendor-access-trunk-sw2 bridge vlan show
```
Expected: `eth1` lists `10` and `20` (no flags: tagged); `eth2` lists `10 PVID Egress Untagged`; `eth3` lists `20 PVID Egress Untagged`. Two ways of writing the same idea: a trunk that carries 10 and 20 tagged, and one access port per VLAN.

**3. See the tags.** Start this, then run exercise 1's first two pings again in a second terminal:
```
docker exec clab-multivendor-access-trunk-sw2 tcpdump -e -c 4 -ni eth1
```
Each line shows `ethertype 802.1Q (0x8100), length ...: vlan 10` or `vlan 20`, then the ARP or ping inside. (On the build machine: `vlan 10, p 0, ethertype ARP (0x0806), Request who-has 10.35.0.12` and `vlan 20 ... who-has 10.35.0.22`.) The hosts never see a tag: the access ports add and remove it.

**4. VLAN 20 works on one end only (the lesson's practice).** Take VLAN 20 off sw2's trunk:
```
bash changes/sw2-trunk-drop-20.sh
```
Expected: `ping 10.35.0.12` from h1 still works; `ping -W 1 10.35.0.22` from h2 fails. Both trunk ports are up. Where do you look first? At the VLAN, not the link: is VLAN 20 allowed at **both** ends?
```
docker exec clab-multivendor-access-trunk-sw1 sr_cli "show interface ethernet-1/3"
```
```
docker exec clab-multivendor-access-trunk-sw2 bridge vlan show dev eth1
```
SR Linux still has `ethernet-1/3.20`; the Linux bridge's eth1 lists only `10`. sw1 sends VLAN 20 tagged and sw2 drops it. Put it back:
```
bash changes/sw2-trunk-undo.sh
```
The same fault from the other side: `docker exec -i clab-multivendor-access-trunk-sw1 sr_cli < changes/sw1-trunk-drop-20.cli` removes VLAN 20 from SR Linux's trunk (`show interface ethernet-1/3` then lists only `.10`); undo with `changes/sw1-trunk-undo.cli`.

**5. One end access, the other trunk.** Make sw2's eth1 an access port in VLAN 10 while sw1's end stays a trunk:
```
bash changes/sw2-eth1-access-10.sh
```
Expected: both pings from exercise 1 fail. sw2 now sends VLAN 10 **untagged** on eth1 and carries no VLAN 20; sw1's trunk has no subinterface for untagged frames, so it drops them. `tcpdump -e -ni eth1` on sw2 shows h3's ARP replies leaving without a tag. Put it back:
```
bash changes/sw2-eth1-trunk.sh
```

## Sample captures

Open them in Wireshark with File > Open and filter `vlan or arp or icmp`. They are recorded on the first VM run (`captures/NOT_YET_RECORDED.md`).

| File | Recorded on | What it will show |
|---|---|---|
| `mvat-1-trunk-tags.pcapng` | sw2:eth1 | the working trunk: h1's ping to h3 tagged VLAN 10, h2's ping to h4 tagged VLAN 20 |
| `mvat-2-vlan20-not-allowed.pcapng` | sw2:eth1 | VLAN 20 removed from sw2's trunk: VLAN 10 still answered; h2's ARP requests arrive tagged 20 and get no answer |
| `mvat-3-access-vs-trunk.pcapng` | sw2:eth1 | sw2's eth1 as an access port: VLAN 10 frames from sw2 leave untagged, frames from sw1 arrive tagged; no ping gets through |

## What this lab does not do

- No native VLAN on the trunk (both VLANs are tagged); `vlans-trunks` (NEO-07) shows a native VLAN and what a mismatch does.
- No router between the VLANs.
- No Arista EOS, Juniper Junos or Cisco switch; the lesson shows their commands as text.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** SR Linux needs 1 to 2 minutes after Deploy. Wait and try again. Then check sw2: `docker exec clab-multivendor-access-trunk-sw2 bridge vlan show` must list eth1, eth2 and eth3 as in exercise 2. If it says `Cannot find device "br0"` or lists nothing, sw2's bridge was not created (the computer's Linux kernel lacks bridge VLAN filtering); this lab needs the NEO lab VM.
2. **`sr_cli` says `Parsing error`.** Copy the whole line, including the quotes. Run the `changes/*.cli` lines from the lab folder.
3. **A ping that should work fails after an exercise.** Run the undo of that exercise, or reset the lab with `containerlab redeploy -c -t multivendor-access-trunk.clab.yml`.
4. **The capture command says the interface does not exist.** Use the Linux port name on sw2 (`sw2:eth1`); on sw1 SR Linux ports are written `e1-3`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-access-trunk
```
```
containerlab destroy --cleanup -t multivendor-access-trunk.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-access-trunk` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-access-trunk` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-access-trunk/clab-multivendor-access-trunk
```
Your capture files in your Home folder are not touched.
