# Lab: A port channel with LACP

**Folder:** `labs/port-channel-lacp/`  **Lab file:** `port-channel-lacp.clab.yml`  **Lesson:** NEO-43 Port Channels: bundling links with LACP  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs two real Nokia SR Linux systems (sw1, sw2) used as Layer 2 switches, joined by two links bundled into one port channel, `lag1`, with LACP (IEEE 802.1AX, formerly 802.3ad). The LACPDUs, the bundle and its members going up and down are real. **There is no Arista EOS, Juniper Junos, Cisco or Open vSwitch in this lab**; the lesson shows their commands as text. The hosts are single-homed: the bundle in this lab is between the two switches. (A host bundle, `bond0` on Linux, is in the NEO-44 lab `mlag-dual-homing`.)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** the full lab runs **two** SR Linux systems, which together need about 4 GB (about 1.9 GB each, measured). Close other programs you do not need, and run no other lab at the same time. **If your VM has 8 GB:** do not deploy the full file. Use the lighter topology `port-channel-lacp-lite.clab.yml` (one SR Linux switch and a Linux bond on sw2). See **Lighter topology** below.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/port-channel-lacp/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB), unless an earlier lab already did. After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for both switches to start forwarding. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
                        lag1 (LACP, two members)
 h1 ---- e1/3  sw1  e1/1 ======================== e1/1  sw2  e1/3 ---- h2
 10.43.0.11         e1/2 ======================== e1/2             10.43.0.12
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| h1 | Linux host, 10.43.0.11/24, on sw1's ethernet-1/3 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| sw1 | SR Linux switch: `lag1` = ethernet-1/1 + ethernet-1/2, LACP active, fast; LACP system ID 02:00:00:43:00:01; mac-vrf `lan` with lag1.0 and ethernet-1/3.0 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| sw2 | SR Linux switch, the same layout; LACP system ID 02:00:00:43:00:02 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell |
| h2 | Linux host, 10.43.0.12/24, on sw2's ethernet-1/3 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

h1 and h2 share one subnet, 10.43.0.0/24, so all their traffic crosses the port channel. All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **sw1 and sw2 each show twice under Running Labs**; the second entry is SR Linux's internal helper, ignore it.

On SR Linux a port channel is a **LAG interface** (`lag1`). A port joins it with `ethernet aggregate-id lag1`; the switch configuration (VLANs, the mac-vrf) is done once, on `lag1`, not on the members. LACP runs on every member: each side sends an LACPDU once a second (`interval FAST`) saying who it is (system ID, key, port) and who it hears. A member carries traffic only when both ends agree (`IN_SYNC`). Each flow is hashed onto one member, so one ping uses one link; two links give more total capacity and survive a link failure, not a faster single flow.

## Files

- `port-channel-lacp.clab.yml` - the full lab drawing (two SR Linux switches).
- `port-channel-lacp-lite.clab.yml` - the lighter drawing: sw1 is still SR Linux, sw2 is a Linux LACP bond bridged to h2. Use this on an 8 GB virtual machine.
- `configs/sw1-srl.cli`, `configs/sw2-srl.cli` - the two SR Linux switches in the full lab: the two members, `lag1` with LACP, the host port, and the mac-vrf `lan`. `configs/sw2-bond.sh` builds the same bundle on Linux in the lighter lab.
- `changes/` - the exercise changes. In the full lab, apply them with `docker exec -i ... sr_cli < changes/<file>`. In the lighter lab, sw1 still uses the `.cli` files; for sw2 run the matching `changes/<file>.sh` instead (`sw2-lacp-off`, `sw2-lacp-on`).
- `scripts/make-captures.sh` - re-records the sample captures on the **full** lab. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, puts every change back at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays). On the lighter lab it checks that sw2 is Linux and leaves the samples unchanged (they were recorded on the full lab).
- `port-channel-lacp.drawio` and `port-channel-lacp.png` - the prepared diagram; the oval marks the two members of lag1.
- `captures/` - four sample captures: `lacp-1-member-1.pcapng` and `lacp-1-member-2.pcapng` (the same 10 seconds on both members), `lacp-2-member-down.pcapng`, `lacp-3-partner-silent.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `port-channel-lacp` > right-click `port-channel-lacp.clab.yml` > **Deploy**. For the lighter lab, right-click `port-channel-lacp-lite.clab.yml` instead (or, in a terminal from this folder: `containerlab deploy -t port-channel-lacp-lite.clab.yml`). Deploy only one of the two files, not both. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-port-channel-lacp-h1 ping -c 2 10.43.0.12
  ```
  Two replies. If there are none, the switch is still starting: wait a minute and run it again.
- **Reset to the lesson start** (undo every change):
  ```
  cd ~/labs-main/containerlab/labs/port-channel-lacp
  ```
  ```
  containerlab redeploy -c -t port-channel-lacp.clab.yml
  ```
  If you started the lighter lab, use `port-channel-lacp-lite.clab.yml` in that command instead.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | SR Linux (sw1, sw2: `sr_cli`) |
|---|---|
| The bundle and each member: up or down, and why | `show lag lag1` |
| LACP per member: in sync, partner system ID, ports | `show lag lag1 lacp-state` |
| LACPDUs sent and received per member | `show lag lag1 lacp-statistics` |
| Where each MAC was learnt (lag1.0 or the host port) | `show network-instance lan bridge-table mac-table all` |
| The configuration of the bundle | `info interface lag1` |
| Wireshark filter | `lacp` |

Other vendors use other words: a port-channel or ae interface, `channel-group … mode active`, `802.3ad`. The lesson shows them.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/port-channel-lacp`). You can also right-click a switch > **Access** > **Attach Shell** and type the part in quotes.

**1. The bundle is up.**
```
docker exec clab-port-channel-lacp-sw1 sr_cli "show lag lag1"
```
`lag1 is up, Aggregate speed 50000 Mbps, min links 1`, with `ethernet-1/1` and `ethernet-1/2` both `up`. (The lab's virtual links report 25 Gb/s each; real speeds depend on the ports.)

**2. What LACP agreed.**
```
docker exec clab-port-channel-lacp-sw1 sr_cli "show lag lag1 lacp-state"
```
Each member: `ACTIVE`, timeout `SHORT` (fast), state `IN_SYNC`, its own system ID `02:00:00:43:00:01` and the **partner ID `02:00:00:43:00:02`** (sw2), key 1, port numbers 1 and 2 at both ends. Both members see the same partner and key, so they may be bundled. `show lag lag1 lacp-statistics` counts the LACPDUs: they keep growing, one a second each way.

**3. See the LACPDUs.** In Ubuntu's Terminal app, capture one member for 10 seconds:
```
sudo containerlab capture --name port-channel-lacp --target sw1:e1-1 --duration 10s -w - > "$HOME/neo-lacp.pcapng"
```
Open it in Wireshark and filter `lacp`: one PDU a second from each side. Open one: the **Actor** (the sender: system 02:00:00:43:00:01, key 1, port 1) and the **Partner** it hears (02:00:00:43:00:02), and the state flags (Activity, Timeout, Aggregation, Synchronization, Collecting, Distributing). (Containerlab names SR Linux's ethernet-1/1 `e1-1` in Linux.)

**4. Pull a member.** Disable sw1's ethernet-1/2:
```
docker exec -i clab-port-channel-lacp-sw1 sr_cli < changes/sw1-member2-down.cli
```
```
docker exec clab-port-channel-lacp-sw1 sr_cli "show lag lag1"
```
`lag1 is up, Aggregate speed 25000 Mbps`: ethernet-1/2 is `down` (`port-disabled`), ethernet-1/1 still `up`. `docker exec clab-port-channel-lacp-h1 ping -c 2 10.43.0.12` still works: the traffic moves to the remaining member, the bundle keeps its address and its place in the MAC table. Put it back:
```
docker exec -i clab-port-channel-lacp-sw1 sr_cli < changes/sw1-member2-up.cli
```

**5. The far end stops speaking LACP (the lesson's practice).** Make sw2's lag1 a static bundle (no LACP), while sw1 still expects LACP:
```
docker exec -i clab-port-channel-lacp-sw2 sr_cli < changes/sw2-lacp-off.cli
```
```
docker exec clab-port-channel-lacp-sw1 sr_cli "show lag lag1"
```
After a few seconds: `lag1 is down, reason no-active-links`, both members `down` with reason **`lacp-down`**. Every link is up, but sw1 hears no partner: `show lag lag1 lacp-state` shows `OUT_SYNC` and partner `00:00:00:00:00:00`. The ping from h1 to h2 fails. LACP does what it is for: it refuses to bundle links when it cannot confirm who is at the other end. Put it back:
```
docker exec -i clab-port-channel-lacp-sw2 sr_cli < changes/sw2-lacp-on.cli
```

## Sample captures

All are recorded on sw1's side of the members. Open them in Wireshark with File > Open and filter `lacp` (or `lacp or icmp`).

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `lacp-1-member-1.pcapng` | sw1:e1-1 | 26 | 10 LACPDUs each way (actor 02:00:00:43:00:01 port 1 / partner 02:00:00:43:00:02, all flags set: in sync, collecting, distributing) and h1's 3 pings to h2: the hash put this flow on member 1 |
| `lacp-1-member-2.pcapng` | sw1:e1-2 | 20 | the same 10 seconds on member 2: 10 LACPDUs each way (port 2), no ping: one flow uses one member |
| `lacp-2-member-down.pcapng` | sw1:e1-1 | 31 | member 2 is disabled 4 s in; LACPDUs on member 1 go on and h1's pings still cross it |
| `lacp-3-partner-silent.pcapng` | sw1:e1-1 | 21 | sw2 turns LACP off 4 s in: sw2's PDUs stop after frame 11; 3 s later (three missed fast PDUs) sw1 marks the partner Expired and stops distributing (frame 15), 3 s after that Defaulted, partner 00:00:00:00:00:00 (frame 19); sw1 keeps sending. Two LLDP frames: the switches announce themselves |

## What this lab does not do

- The hosts are not bundled: `bond0` on a Linux host is in the NEO-44 lab. The lab's own plan named one (h1 bond0); it is left out here so that the whole lab can be checked on the build machine.
- No static (non-LACP) bundle on both sides, no LACP priority or standby members, no load-sharing settings.
- No Arista, Juniper, Cisco or Open vSwitch; the lesson shows their commands as text.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start gets no replies.** The SR Linux switches take 1 to 2 minutes to start. Wait and try again. If you deployed the full lab on an 8 GB virtual machine and it is slow or stuck, destroy it and deploy `port-channel-lacp-lite.clab.yml` instead. Check memory with `free -h`: two SR Linux systems need about 4 GB.
2. **A change command says `No such file or directory`, or `Input not from a terminal/file/pipe`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/port-channel-lacp`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`.
3. **lag1 stays down after exercise 5.** Run `sw2-lacp-on.cli` (it puts back LACP with the same system ID and key); after a few seconds both members are `up`. Or reset the lab with `containerlab redeploy -c -t port-channel-lacp.clab.yml`.
4. **The capture command says the interface does not exist.** Use `sw1:e1-1`, not `sw1:ethernet-1/1`: in Linux the SR Linux port names are shortened.

## Lighter topology (8 GB virtual machines)

Use `port-channel-lacp-lite.clab.yml` when the full lab would be too large (two SR Linux switches, about 4 GB together, on an 8 GB virtual machine). sw1 is the same SR Linux switch as in the full lab, so `show lag lag1` and the sw1 exercises do not change. sw2 is a Linux bond (`bond0`, LACP, fast timers) bridged to h2; that uses a few megabytes. The hosts, addresses and the two-member bundle stay the same, and the container names stay `clab-port-channel-lacp-*`, so the ping commands do not change. To turn LACP off and on on sw2, run `bash changes/sw2-lacp-off.sh` and `bash changes/sw2-lacp-on.sh`. `scripts/make-captures.sh` does not overwrite the sample captures on the lighter lab (they were recorded on the full lab).

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/port-channel-lacp
```
```
containerlab destroy --cleanup -t port-channel-lacp.clab.yml
```
`--cleanup` also removes the generated `clab-port-channel-lacp` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-port-channel-lacp` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/port-channel-lacp/clab-port-channel-lacp
```
Your capture files in your Home folder are not touched.
