# Lab: Multi-vendor spanning tree status (Rapid STP on SR Linux, 802.1D on a Linux bridge)

**Folder:** `labs/multivendor-stp-status/`  **Lab file:** `multivendor-stp-status.clab.yml`  **Lesson:** NEO-36 Multi-vendor RSTP and MSTP status  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** two real Nokia SR Linux systems (sw1, sw2) run **Rapid STP (802.1w)** in a mac-vrf, and a Linux bridge (sw3) runs the Linux kernel's **classic 802.1D STP**. All three build **one** tree together: on the ports that face sw3, SR Linux falls back to 802.1D, as Rapid STP is designed to. You read the same tree in two status formats. **MSTP is not run in this lab** (the Linux kernel has none, and the lab keeps to one tree); the lesson shows MSTP regions as text. **There is no Arista EOS, Juniper Junos or Cisco switch in this lab**; the lesson shows their commands as text.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** the full lab runs **two** SR Linux systems, which together need about 4 GB (about 1.9 GB each, as measured for `vlans-trunks`). Close other programs you do not need, and run no other lab at the same time. **If your VM has 8 GB:** do not deploy the full file. Use the lighter topology `multivendor-stp-status-lite.clab.yml` (one SR Linux switch; sw2 and sw3 are Linux bridges). See **Lighter topology** below.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-stp-status/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for both SR Linux systems to start and the tree to settle. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
                         h1 10.36.0.11
                          |
                        e1/3
                         sw1   SR Linux, Rapid STP, priority 4096 (root)
                  e1/1 /     \ e1/2
          Rapid STP   /       \   802.1D
                e1/1 /         \ eth1
 h2 --- e1/3 sw2 e1/2 --------- eth2 sw3 eth3 --- h3
 10.36.0.12  SR Linux    802.1D  (blocks)          10.36.0.13
             Rapid STP               Linux bridge, 802.1D STP
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| sw1 | SR Linux switch: mac-vrf `lan` (ethernet-1/1 to sw2, ethernet-1/2 to sw3, ethernet-1/3 to h1), spanning tree on, **bridge priority 4096**, bridge address 02:00:00:36:00:01 | `ghcr.io/nokia/srlinux:26.7.2` | Right-click > **Access** > **Attach Shell** (opens `sr_cli`) |
| sw2 | SR Linux switch, the same layout (ethernet-1/1 to sw1, ethernet-1/2 to sw3, ethernet-1/3 to h2), priority 32768, bridge address 02:00:00:36:00:02 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell |
| sw3 | Linux bridge `br0` (eth1 to sw1, eth2 to sw2, eth3 to h3), kernel 802.1D STP, priority 32768, bridge MAC 02:00:00:36:00:03 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| h1, h2, h3 | Linux hosts 10.36.0.11, .12, .13 (/24), one on each switch | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

All three hosts are in one subnet, 10.36.0.0/24: the switches only forward frames, there is no router. All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **sw1 and sw2 each show twice under Running Labs**; the second entry is SR Linux's internal helper, ignore it.

On SR Linux, spanning tree runs per mac-vrf (`network-instance lan protocols stp`) and is switched on per port (`interface ... subinterface 0 bridge-table stp`). The host ports are **edge ports** (`edge-port EDGE_ENABLE`): Rapid STP lets them forward at once.

**Why sw3's eth2 blocks.** sw1 has the lowest priority (4096), so it is the root. sw2 and sw3 each reach it over their direct link (root path cost 2000). On the sw2 - sw3 link both ends are 2000 away from the root, so the tie goes to the lower bridge ID: sw2 (32768, …:02) beats sw3 (32768, …:03). sw2's end is the designated port; sw3's end blocks. The fixed bridge addresses make this the same on every deploy.

**Lab timers and costs.** Shortened for the lab on all three switches: hello 1 s, max age 6 s, forward delay 4 s (defaults: 2 s, 20 s, 15 s). Every switch-to-switch port has path cost 2000, the Rapid STP value for 10 Gb/s, set by hand on both kinds of switch: the Linux bridge would otherwise use the older 802.1D cost (2), and the two kinds of switch would not agree on distances.

## Files

- `multivendor-stp-status.clab.yml` - the lab drawing. sw3's bridge is created by the `exec` lines of its node.
- `multivendor-stp-status-lite.clab.yml` - the lighter drawing: sw1 is still SR Linux, sw2 is a Linux bridge like sw3. Use this on an 8 GB virtual machine.
- `configs/sw1-srl.cli`, `configs/sw2-srl.cli` - the two SR Linux switches in the full lab: the three ports, the mac-vrf `lan`, spanning tree with its priority, bridge address and timers. `configs/sw2-bridge.sh` builds the same role on a Linux bridge in the lighter lab.
- `changes/` - the exercise changes. SR Linux files are applied with `docker exec -i ... sr_cli < changes/<file>`: `sw1-cut-to-sw3.cli` and `sw1-restore-to-sw3.cli` (sw1's ethernet-1/2 off and on), `sw2-cut-to-sw3.cli` and `sw2-restore-to-sw3.cli` (sw2's ethernet-1/2 off and on). Linux bridge files run with `bash changes/<file>`: `sw3-priority-0.sh` and `sw3-priority-undo.sh`.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `multivendor-stp-status.drawio` and `multivendor-stp-status.png` - the prepared diagram.
- `captures/` - three sample captures: `mvstp-1-rstp-bpdus.pcapng`, `mvstp-2-stp-bpdus.pcapng`, `mvstp-3-alternate-takeover.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-stp-status` > right-click `multivendor-stp-status.clab.yml` > **Deploy**. For the lighter lab, right-click `multivendor-stp-status-lite.clab.yml` instead (or, in a terminal from this folder: `containerlab deploy -t multivendor-stp-status-lite.clab.yml`). Deploy only one of the two files, not both. Wait for the green dots and 1 to 2 minutes, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-stp-status-h1 ping -c 2 10.36.0.13
  ```
  Two replies. If there are none, SR Linux is still starting or the ports are still learning: wait 30 seconds and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-stp-status
  ```
  ```
  containerlab redeploy -c -t multivendor-stp-status.clab.yml
  ```
  If you started the lighter lab, use `multivendor-stp-status-lite.clab.yml` in that command instead.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | SR Linux (sw1, sw2: `sr_cli`) | Linux bridge (sw3) |
|---|---|---|
| This switch's bridge ID, the root, its root port and cost | `info from state /network-instance lan protocols stp` | `cat /sys/class/net/br0/bridge/{bridge_id,root_id,root_port,root_path_cost}` |
| One port: role, state, protocol spoken | `info from state /interface ethernet-1/1 subinterface 0 bridge-table stp` | `bridge link show dev eth1` (state only) |
| BPDUs on a port, live | `tcpdump -c 2 -ni e1-1 stp` (from the Linux shell: `docker exec clab-multivendor-stp-status-sw2 tcpdump ...`) | `tcpdump -c 2 -ni eth1 stp` |
| Wireshark filter | `stp` | `stp` |

**Reading the two formats side by side:**

| Fact | SR Linux | Linux bridge |
|---|---|---|
| Bridge ID | `4096.0.02:00:00:36:00:01` (priority, VLAN/instance ID 0, MAC) | `1000.020000360001` (priority in hex: 1000 = 4096, then the MAC without colons) |
| Root port | `root-port 2048` (SR Linux's port number; 2048 = ethernet-1/1, 2049 = ethernet-1/2) | `root_port` = `1` (the bridge's own port number: 1 = eth1) |
| Port role | `port-role ROOT`, `DESIGNATED`, `ALTERNATE` | not shown (802.1D has no alternate role) |
| Port state | `FORWARDING`, `DISCARDING`, `LEARNING` | `forwarding`, `blocking`, `listening`, `learning` |
| Protocol on the port | `oper-protocol rstp` or `stp` (fallback) | always 802.1D |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-stp-status`). You can also right-click a node > **Access** > **Attach Shell** and type the part in quotes (SR Linux) or after the container name (Linux).

**1. Who is the root? Ask SR Linux.**
```
docker exec clab-multivendor-stp-status-sw2 sr_cli "info from state /network-instance lan protocols stp" | grep -E "bridge-id|designated-root|root-port|root-cost"
```
`bridge-id 32768.0.02:00:00:36:00:02` (sw2 itself), `designated-root 4096.0.02:00:00:36:00:01` (sw1), `root-port 2048` (ethernet-1/1) and `root-cost 2000`.

**2. Ask the Linux bridge the same question.**
```
docker exec clab-multivendor-stp-status-sw3 cat /sys/class/net/br0/bridge/root_id /sys/class/net/br0/bridge/bridge_id /sys/class/net/br0/bridge/root_port /sys/class/net/br0/bridge/root_path_cost
```
`1000.020000360001`, `8000.020000360003`, `1`, `2000`. The same root as in exercise 1, written differently: priority in hex (1000 = 4096, 8000 = 32768) and the MAC without colons. When you compare switches from different vendors, convert to one format first.

**3. Roles, states and the protocol each port speaks.** On sw2:
```
docker exec clab-multivendor-stp-status-sw2 sr_cli "info from state /interface ethernet-1/1 subinterface 0 bridge-table stp" | grep -E "port-state|port-role|oper-protocol"
```
```
docker exec clab-multivendor-stp-status-sw2 sr_cli "info from state /interface ethernet-1/2 subinterface 0 bridge-table stp" | grep -E "port-state|port-role|oper-protocol"
```
ethernet-1/1: `FORWARDING`, `ROOT`, `rstp`. ethernet-1/2: `FORWARDING`, `DESIGNATED`, **`stp`**: sw2 heard 802.1D BPDUs from sw3 on that port and answers in 802.1D. Now the Linux bridge:
```
docker exec clab-multivendor-stp-status-sw3 bridge link show
```
`eth1` and `eth3` are `state forwarding`; **`eth2` is `state blocking`**. The Linux bridge reports a state only, no role. You can hear the two dialects on the wire:
```
docker exec clab-multivendor-stp-status-sw2 tcpdump -c 2 -ni e1-1 stp
```
```
docker exec clab-multivendor-stp-status-sw3 tcpdump -c 2 -ni eth1 stp
```
The first says `STP 802.1w, Rapid STP, Flags [Learn, Forward, Agreement], bridge-id 1000.02:00:00:36:00:01.8800`; the second `STP 802.1d, Config, Flags [none], bridge-id 1000.02:00:00:36:00:01.8801`. Both come from sw1, one in each dialect.

**4. A link fails on the 802.1D side.** Start a ping from h1 to h3 (5 per second for 20 s) in a second terminal, then cut the sw1 - sw3 link and watch sw3's blocked port (run the third line a few times, about every 2 seconds):
```
docker exec clab-multivendor-stp-status-h1 ping -i 0.2 -c 100 10.36.0.13
```
```
docker exec -i clab-multivendor-stp-status-sw1 sr_cli < changes/sw1-cut-to-sw3.cli
```
```
docker exec clab-multivendor-stp-status-sw3 bridge link show dev eth2
```
`listening`, then `learning`, then `forwarding`: about 8 seconds (two forward delays). The ping loses about a third of its replies (38 of 100 on the build machine, about 7 seconds). sw3's `root_port` is now `2` with cost `4000`. This is 802.1D speed, even with short timers. Put the link back:
```
docker exec -i clab-multivendor-stp-status-sw1 sr_cli < changes/sw1-restore-to-sw3.cli
```
After about 10 seconds sw3's eth2 is `blocking` again.

**5. Move the root to the Linux bridge.**
```
bash changes/sw3-priority-0.sh
```
After about 10 seconds, ask both kinds of switch again (exercises 1 and 2): SR Linux says `designated-root 0.0.02:00:00:36:00:03`, the Linux bridge `0000.020000360003`: sw3 is the root. On sw2, ethernet-1/2 (toward sw3) is now the `ROOT` port, and **ethernet-1/1 (toward sw1) is `ALTERNATE` and `DISCARDING`**: a blocked port that Rapid STP keeps ready as a backup path to the root. All of sw3's ports forward (a root forwards on every port).

**6. Rapid STP's backup path.** With sw3 still the root, start a ping from h2 to h3 in a second terminal and cut the sw2 - sw3 link:
```
docker exec clab-multivendor-stp-status-h2 ping -i 0.2 -c 75 10.36.0.13
```
```
docker exec -i clab-multivendor-stp-status-sw2 sr_cli < changes/sw2-cut-to-sw3.cli
```
```
docker exec clab-multivendor-stp-status-sw2 sr_cli "info from state /interface ethernet-1/1 subinterface 0 bridge-table stp" | grep -E "port-state|port-role"
```
ethernet-1/1 is already `FORWARDING` and `ROOT`: the alternate port took over at once, and the ping loses **no** replies (0% loss on the build machine). Compare with exercise 4: there the backup port was on the 802.1D switch and had to listen and learn first. Put everything back:
```
docker exec -i clab-multivendor-stp-status-sw2 sr_cli < changes/sw2-restore-to-sw3.cli
```
```
bash changes/sw3-priority-undo.sh
```
Wait about 25 seconds; then sw3's eth2 is `blocking` again and the ping in **Start** works.

## Sample captures

Open them in Wireshark with File > Open and filter `stp`.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `mvstp-1-rstp-bpdus.pcapng` | sw2:e1-1 | 18 | the settled tree on the SR Linux - SR Linux link: Rapid STP BPDUs (`RST.`, protocol version 2) from sw1, Root = 4096/0/02:00:00:36:00:01, port 0x8800, one per second, and h1's ping to h2 |
| `mvstp-2-stp-bpdus.pcapng` | sw3:eth1 | 14 | recorded at the same time on the SR Linux - Linux link: classic 802.1D configuration BPDUs (`Conf.`, version 0) from the same sw1, port 0x8801 |
| `mvstp-3-alternate-takeover.pcapng` | sw2:e1-1 | 19 | sw3 is the root (Root = 0/0/02:00:00:36:00:03, cost 2000 from sw1); the sw2 - sw3 link is cut about 4 s in; sw2's alternate port becomes its root port at once and h2's ping to h3 keeps crossing this link; BPDUs carry the Topology Change flag (`TC`) |

The other frames are background traffic (ARP, IPv6 router solicitations, LLDP); the filter `stp or icmp` hides them. A new run of `make-captures.sh` gives slightly different totals, more of them right after a deploy (box re-run on a fresh deploy: 18 / 15 / 25). In that re-run the first echo reply of `mvstp-3` did not appear on this link while the switches were flushing their MAC tables after the topology change; the second reply did.

## What this lab does not do

- No MSTP: the Linux kernel bridge has none, and this lab keeps to one tree. The lesson shows MSTP regions (name, revision, VLAN map) as text.
- No Rapid STP on the Linux bridge: the kernel runs classic 802.1D only. (A separate user-space program, mstpd, can add Rapid STP and MSTP to Linux; it is not in this lab.)
- No VLANs and no link aggregation.
- No Arista, Cisco or Juniper switch; the lesson shows their commands as text.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** SR Linux needs 1 to 2 minutes after Deploy. Wait and try again. `docker exec clab-multivendor-stp-status-sw3 bridge link show` should show eth2 `blocking` and the other ports `forwarding`.
2. **`sr_cli` says `Parsing error`.** Copy the whole line, including the quotes. Run the `changes/*.cli` lines from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-stp-status`).
3. **After exercise 4, 5 or 6 a ping that should work fails.** Spanning tree needs time after a change on the 802.1D side: wait 15 to 25 seconds. If you skipped an undo, run it, or reset the lab with `containerlab redeploy -c -t multivendor-stp-status.clab.yml`.
4. **The capture command says the interface does not exist.** SR Linux ports are written `e1-1`, `e1-2` in capture targets (`sw2:e1-1`); Linux ports `eth1`, `eth2` (`sw3:eth1`).

## Lighter topology (8 GB virtual machines)

Use `multivendor-stp-status-lite.clab.yml` when the full lab would be too large (two SR Linux switches, about 4 GB together, on an 8 GB virtual machine). sw1 is the same SR Linux switch (RSTP, priority 4096, the root). sw2 is a Linux bridge running classic 802.1D STP, like sw3 already is. The triangle, hosts, addresses and the ping checks stay the same, and the container names stay `clab-multivendor-stp-status-*`. To cut and restore the sw2–sw3 link in the lighter lab, run `bash changes/sw2-cut-to-sw3.sh` and `bash changes/sw2-restore-to-sw3.sh`.

Because sw2 is Linux, the sw1–sw2 link also speaks 802.1D. The side-by-side Rapid STP versus classic STP capture (`mvstp-1-rstp-bpdus` next to `mvstp-2-stp-bpdus`) needs the full lab, where sw2 is SR Linux. The lighter lab still shows a settled tree, a blocking port, and a new root.

Running `make-captures.sh` on the lighter lab checks that the tree settles, that a new root works, and that the pings work. It does not overwrite the sample captures in `captures/` (those were recorded on the full lab). The Rapid STP alternate-port takeover, which completes in about three seconds, also needs the full lab.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-stp-status
```
```
containerlab destroy --cleanup -t multivendor-stp-status.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-stp-status` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-stp-status` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-stp-status/clab-multivendor-stp-status
```
Your capture files in your Home folder are not touched.
