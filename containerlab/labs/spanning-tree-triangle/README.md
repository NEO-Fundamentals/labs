# Lab: Spanning tree in a triangle

**Folder:** `labs/spanning-tree-triangle/`  **Lab file:** `spanning-tree-triangle.clab.yml`  **Lesson:** NEO-08 Spanning Tree  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the three switches are Linux bridges inside small Linux containers, running the Linux kernel's own spanning tree. That is **classic 802.1D STP only**: no Rapid STP (802.1w), no MSTP, no per-VLAN STP, no PortFast or BPDU guard. The BPDUs, the root election, the blocked port and the slow recovery are real. **There is no Cisco, Arista, Juniper or SR Linux switch in this lab**; the lesson shows their commands as text.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: six Linux containers, about 17 MB in total (measured). No SR Linux in this lab. **If your VM has 8 GB:** this lab already fits comfortably; there is no lighter file.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/spanning-tree-triangle/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB on disk), unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes under a minute. **Then wait about 15 seconds** for the tree to settle (ports go listening, then learning, then forwarding). Do not start the exercises until the check in **Start** passes.
- **Exercise 5 makes a real loop** for 2 seconds. It sends about two million frames and uses a lot of CPU for those 2 seconds; the script turns spanning tree back on by itself. Run it only from the script, not by hand.

## What this lab builds

```
                    h1 10.8.0.11
                     |
                   eth3
                    sw1  (root: priority 4096)
              eth1 /     \ eth2
                  /       \
            eth1 /         \ eth1
   h2 --- eth3 sw2 ------- sw3 eth3 --- h3
 10.8.0.12      eth2     eth2 (blocks)   10.8.0.13
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| sw1 | Linux bridge `br0` (eth1 to sw2, eth2 to sw3, eth3 to h1), STP on, **priority 4096**, bridge MAC 02:00:00:08:00:01 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| sw2 | Linux bridge `br0` (eth1 to sw1, eth2 to sw3, eth3 to h2), STP on, priority 32768 (the default), MAC 02:00:00:08:00:02 | same | Attach Shell |
| sw3 | Linux bridge `br0` (eth1 to sw1, eth2 to sw2, eth3 to h3), STP on, priority 32768, MAC 02:00:00:08:00:03 | same | Attach Shell |
| h1, h2, h3 | Linux hosts 10.8.0.11, .12, .13 (/24), one on each switch | same | Attach Shell |

All three hosts are in one subnet, 10.8.0.0/24: the switches only forward frames, there is no router. All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**Why sw3's eth2 blocks.** The bridge ID is the priority followed by the bridge MAC; the lowest one is the root. sw1 has priority 4096 (shown in hex as `1000`), the others 32768 (`8000`), so sw1 is the root. sw2 and sw3 each take their direct link to sw1 as their **root port** (path cost 2). On the sw2 - sw3 link both ends are 2 away from the root, so the tie goes to the lower bridge ID: sw2 (`8000.020000080002`) beats sw3 (`8000.020000080003`). sw2's end is the **designated port**, sw3's end **blocks**. The fixed bridge MACs make this the same on every deploy.

**Lab timers.** Shortened for the lab: hello 1 s, max age 6 s, forward delay 4 s (802.1D defaults: 2 s, 20 s, 15 s). A port then needs about 8 s to go from listening through learning to forwarding, instead of 30 s. Port costs are the kernel's value for these virtual ports (2), not the IEEE table a hardware switch uses.

## Files

- `spanning-tree-triangle.clab.yml` - the lab drawing. Each switch's bridge is created by the `exec` lines of its node.
- `changes/` - the exercise changes, run with `bash changes/<file>` from the lab folder: `cut-sw1-sw3.sh` and `restore-sw1-sw3.sh`, `sw3-priority-0.sh` and `sw3-priority-undo.sh`, and `loop-2s.sh` (spanning tree off for 2 seconds, then on again).
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `spanning-tree-triangle.drawio` and `spanning-tree-triangle.png` - the prepared diagram.
- `captures/` - three sample captures: `stp-1-bpdus.pcapng`, `stp-2-link-failure.pcapng`, `stp-3-new-root.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `spanning-tree-triangle` > right-click `spanning-tree-triangle.clab.yml` > **Deploy**. Wait for the green dots and about 15 seconds, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-spanning-tree-triangle-h1 ping -c 2 10.8.0.13
  ```
  Two replies. If there are none, the ports are still listening or learning: wait 15 seconds and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/spanning-tree-triangle
  ```
  ```
  containerlab redeploy -c -t spanning-tree-triangle.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | Linux bridge (sw1, sw2, sw3) |
|---|---|
| Each port and its STP state (blocking, listening, learning, forwarding) | `bridge link show` |
| The root this switch believes in (priority.MAC, in hex) | `cat /sys/class/net/br0/bridge/root_id` |
| This switch's own bridge ID | `cat /sys/class/net/br0/bridge/bridge_id` |
| Root port (bridge port number, 0 on the root) and cost to the root | `cat /sys/class/net/br0/bridge/root_port /sys/class/net/br0/bridge/root_path_cost` |
| BPDUs on a port, live | `tcpdump -c 3 -ni eth1 stp` |
| Wireshark filter | `stp` |

The bridge numbers its ports in the order they were added: port 1 = eth1, 2 = eth2, 3 = eth3. Other vendors show the same facts with other commands (`show spanning-tree` and similar); the lesson shows them.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/spanning-tree-triangle`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Who is the root?**
```
docker exec clab-spanning-tree-triangle-sw1 cat /sys/class/net/br0/bridge/root_id /sys/class/net/br0/bridge/bridge_id
```
Both lines are `1000.020000080001`: sw1's own ID is the root ID, so sw1 is the root (priority 4096 = hex 1000). On sw2:
```
docker exec clab-spanning-tree-triangle-sw2 cat /sys/class/net/br0/bridge/root_id /sys/class/net/br0/bridge/root_port /sys/class/net/br0/bridge/root_path_cost
```
The same root ID, root port `1` (eth1, toward sw1), cost `2`.

**2. The blocked port.**
```
docker exec clab-spanning-tree-triangle-sw3 bridge link show
```
`eth1` and `eth3` are `state forwarding`; **`eth2` is `state blocking`**: sw3's end of the sw2 - sw3 link (see "Why sw3's eth2 blocks" above). Run the same on sw1 and sw2: every port forwards. The loop is broken in one place.

**3. The BPDUs.** The root sends a configuration BPDU every hello time (1 s here):
```
docker exec clab-spanning-tree-triangle-sw2 tcpdump -c 2 -ni eth1 stp
```
Two lines like `STP 802.1d, Config, Flags [none], bridge-id 1000.02:00:00:08:00:01.8001, length 35`: the sender is sw1 (`1000.02:00:00:08:00:01`) on its port `8001` (port priority 0x80, port 1). In Wireshark (sample `stp-1-bpdus.pcapng` or your own capture of `sw2:eth1`) open one BPDU: Root Identifier 4096 / 02:00:00:08:00:01, Root Path Cost 0, and the timers.

**4. A link fails.** Cut the sw1 - sw3 link and watch sw3's blocked port (run the second line a few times, about every 2 seconds):
```
bash changes/cut-sw1-sw3.sh
```
```
docker exec clab-spanning-tree-triangle-sw3 bridge link show dev eth2
```
`state listening`, then `state learning`, then `state forwarding`, about 8 seconds in all (two forward delays). Now `cat /sys/class/net/br0/bridge/root_port` on sw3 says `2` (eth2) with cost `4`: sw3 reaches the root through sw2. `docker exec clab-spanning-tree-triangle-h1 ping -c 2 10.8.0.13` works again (if the first try fails, wait a few seconds and run it again: the switches are still re-learning where h3 is). Put the link back:
```
bash changes/restore-sw1-sw3.sh
```
After about 10 seconds sw3's eth2 is `blocking` again. With the standard 802.1D timers the same recovery takes 30 to 50 seconds; Rapid STP usually needs about a second.

**5. Why we need it: a loop.** This script turns spanning tree off on all three switches (every port forwards), sends **one** broadcast from h1 (an ARP question), counts what h2 receives in 2 seconds, and turns spanning tree back on:
```
bash changes/loop-2s.sh
```
It prints something like `h2 received 1926304 frames in about 2 seconds, from one broadcast.` (the number depends on the computer; on the build machine it was about two million). Ethernet frames have no hop count, so the one broadcast circles the triangle and is copied at every switch until something stops it. Wait about 15 seconds; then the ping in **Start** works again.

**6. A new root (the lesson's practice).** Give sw3 a lower priority than sw1:
```
bash changes/sw3-priority-0.sh
```
After about 15 seconds `docker exec clab-spanning-tree-triangle-sw2 cat /sys/class/net/br0/bridge/root_id` says `0000.020000080003`: sw3 is the root and the tree has re-formed around it. Run `bridge link show` on all three: now **sw2's eth1** (toward sw1) blocks, and sw3's eth2 forwards. Traffic between h1 and h2 now goes through sw3. Put it back:
```
bash changes/sw3-priority-undo.sh
```
Wait about 25 seconds (sw2's eth1 goes listening, learning, forwarding again) before the ping in **Start** works.

## Sample captures

Open them in Wireshark with File > Open and filter `stp`.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `stp-1-bpdus.pcapng` | sw2:eth1 | 21 | the settled tree: 10 configuration BPDUs from sw1 (Root = 4096/0/02:00:00:08:00:01, port 0x8001), one per second, and h1's ping to h2 |
| `stp-2-link-failure.pcapng` | sw3:eth2 | 32 | sw2's BPDUs (Root 4096, cost 2, port 0x8002) on sw3's blocked port; the sw1 - sw3 link is cut 4 s in; 8 s later sw3 sends a Topology Change Notification (frame 15) and h1's ping to h3 crosses this link; then BPDUs with the TC flag |
| `stp-3-new-root.pcapng` | sw2:eth1 | 16 | sw3 gets priority 0 about 4 s in: the BPDUs from sw1 switch from Root = 4096/…:01 to Root = 0/…:03 (cost 2: sw1 is now one hop from the root) |

The other frames are background traffic (IPv6 router solicitations); the filter `stp or icmp or arp` hides them. The loop of exercise 5 is not a sample: its file would hold millions of frames.

## What this lab does not do

- No Rapid STP, MSTP or per-VLAN STP; no PortFast, BPDU guard or root guard. The Linux kernel bridge runs classic 802.1D only.
- No VLANs and no link aggregation.
- No Cisco, Arista, Juniper or SR Linux switch; the lesson shows their commands as text.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** The ports need about 8 seconds after Deploy (listening, learning). Wait 15 seconds and try again. `docker exec clab-spanning-tree-triangle-sw3 bridge link show` should show eth2 `blocking` and the other ports `forwarding`.
2. **A change script says `No such file or directory`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/spanning-tree-triangle`) so that `changes/...` is found.
3. **After exercise 4, 5 or 6 a ping that should work fails.** Spanning tree needs time after every change: wait 15 to 25 seconds. If you skipped an undo, run it (`restore-sw1-sw3.sh`, `sw3-priority-undo.sh`), or reset the lab with `containerlab redeploy -c -t spanning-tree-triangle.clab.yml`.
4. **The computer is slow after exercise 5.** The script turns spanning tree back on after 2 seconds; if it was interrupted (Ctrl+C), turn it on by hand: `docker exec clab-spanning-tree-triangle-sw1 ip link set br0 type bridge stp_state 1`, the same for sw2 and sw3, or reset the lab.
5. **The capture command says the interface does not exist.** Use the Linux port names: `sw2:eth1`, `sw3:eth2`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/spanning-tree-triangle
```
```
containerlab destroy --cleanup -t spanning-tree-triangle.clab.yml
```
`--cleanup` also removes the generated `clab-spanning-tree-triangle` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-spanning-tree-triangle` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/spanning-tree-triangle/clab-spanning-tree-triangle
```
Your capture files in your Home folder are not touched.
