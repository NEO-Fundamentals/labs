# Lab: eBGP, iBGP and how a router chooses a path

**Folder:** `labs/bgp-ebgp-ibgp-path-choice/`  **Lab file:** `bgp-ebgp-ibgp-path-choice.clab.yml`  **Lesson:** NEO-11 BGP: What It Is, eBGP and iBGP, and Path Choice  **Lab version:** 1.0.1 (2026-11-26; README: Before you start, Troubleshooting and Cleanup sections added, diagram re-rendered. Lab file and configs unchanged)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/bgp-ebgp-ibgp-path-choice/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 5 to 10 minutes (downloads). Then wait about two minutes for all three BGP sessions.

## What this lab builds

```
                              +-- eBGP 10.0.12.0/30 --  edge-b1 (FRR, AS 65202) --+
 host-a --- edge-a (SR Linux, AS 65201)                    |  iBGP 10.0.23.0/30     |
 192.168.10.10                                             +-- eBGP 10.0.13.0/30 --  edge-b2 (FRR, AS 65202) --- host-b
                                                                                                          192.168.20.10
```

edge-a peers by **eBGP** with both routers of AS 65202. edge-b1 and edge-b2 peer with each other by **iBGP**. So edge-a hears about Site B's network (192.168.20.0/24) twice and has to choose. edge-b2 hears about Site A's network (192.168.10.0/24) twice as well: once by eBGP, once by iBGP.

On purpose, edge-b2 adds its AS number twice more (an "AS-path prepend") to what it tells edge-a. That makes the path through edge-b2 look longer, so edge-a prefers the path through edge-b1 even though that is the physically longer way.

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| edge-a | Nokia SR Linux router, AS 65201 | `ghcr.io/nokia/srlinux:26.7.2` | Right-click > **Access** > **Attach Shell** (opens `sr_cli`) |
| edge-b1 | FRR router, AS 65202 | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| edge-b2 | FRR router, AS 65202 (adds the prepend) | same | same |
| host-a | Linux PC on Site A LAN | `ghcr.io/srl-labs/network-multitool` | Attach Shell |
| host-b | Linux PC on Site B LAN | same | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. AS numbers are private (64512 to 65534).

**edge-a shows twice under Running Labs.** The second one is SR Linux's internal helper. Ignore it.

## Files

- `bgp-ebgp-ibgp-path-choice.clab.yml` - the lab drawing.
- `configs/edge-a-srl.cli`, `configs/edge-b1-frr.conf`, `configs/edge-b2-frr.conf` - starting configs.
- `bgp-ebgp-ibgp-path-choice.drawio` and `.png` - the prepared diagram.
- `captures/` - sample captures recorded from this lab: `ibgp-session-restart.pcapng` (the iBGP link while the session restarts) and `ebgp-session-restart.pcapng` (edge-b1 to edge-a). Open them in Wireshark with the filter `bgp`.
- `scripts/make-captures.sh` - re-records those two files.

## Start, reset, stop

Type or paste commands one line at a time.

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `bgp-ebgp-ibgp-path-choice` > right-click the `.clab.yml` file > **Deploy**. Run one lab at a time (SR Linux needs about 2 GB). **Wait about two minutes** before you check BGP. Checkpoint, in Ubuntu's Terminal:
  ```
  docker exec clab-bgp-ebgp-ibgp-path-choice-edge-b2 vtysh -c "show bgp summary"
  ```
  Both neighbors show a number under `State/PfxRcd`.
- **Reset to the lesson start (and after editing a config file):** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/bgp-ebgp-ibgp-path-choice
  ```
  ```
  containerlab redeploy -c -t bgp-ebgp-ibgp-path-choice.clab.yml
  ```
- **After a VM restart:** check every node has a green dot; if one is stopped, run `containerlab redeploy -t bgp-ebgp-ibgp-path-choice.clab.yml` in the lab folder (no `-c`).
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Check it works

1. host-a shell: `ping -c 3 192.168.20.10` gives 3 replies.
2. edge-a Attach Shell: `show network-instance default protocols bgp neighbor` shows 10.0.12.2 and 10.0.13.2 both `established`.

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | edge-a Attach Shell: `show network-instance default protocols bgp routes ipv4 prefix 192.168.20.0/24 detail`. Then on host-a: `traceroute -n 192.168.20.10` | Two paths. Path 1 (next hop 10.0.12.2, AS path 65202) is `Best`. Path 2 (next hop 10.0.13.2, AS path 65202 65202 65202) shows `Tie Break Reason : as-path-length`. The traceroute goes edge-a, edge-b1, edge-b2, host-b (4 hops) | Nothing to undo |
| E2 | edge-a Attach Shell: `enter candidate`, then `set / routing-policy policy prefer-b2 statement 10 action policy-result accept`, `set / routing-policy policy prefer-b2 statement 10 action bgp local-preference operation set`, `set / routing-policy policy prefer-b2 statement 10 action bgp local-preference value 200`, `set / network-instance default protocols bgp group to-b2 import-policy [ prefer-b2 ]`, `commit now`. Repeat E1's two commands | Local preference is checked before AS-path length. The path through edge-b2 now has `LocalPref is 200`, becomes `Best`, and the traceroute shortens to 3 hops (edge-a, edge-b2, host-b) | `enter candidate`, `set / network-instance default protocols bgp group to-b2 import-policy [ accept-all ]`, `commit now` |
| E3 | edge-b2 Attach Shell: `show bgp ipv4 unicast 192.168.10.0/24` | Two paths for the same network. The one from 10.0.13.1 is `external` and `best`; the one from 10.0.23.1 is `internal`. Same local preference, same AS path length, so BGP prefers the eBGP path | Nothing to undo |
| E4 | edge-b1 Attach Shell: `configure terminal`, `router bgp 65202`, `address-family ipv4 unicast`, `no neighbor 10.0.23.2 next-hop-self`, `end`, `clear bgp ipv4 unicast 10.0.23.2 soft out`. Then on edge-b2: `show bgp ipv4 unicast 192.168.10.0/24` | iBGP does not change the next hop. The iBGP path now names 10.0.12.1 (edge-a's far end of the link to edge-b1), which edge-b2 cannot reach: `inaccessible`, `invalid, internal`. Traffic still works through the eBGP path | `configure terminal`, `router bgp 65202`, `address-family ipv4 unicast`, `neighbor 10.0.23.2 next-hop-self`, `end` |
| E5 | In Ubuntu's Terminal record the iBGP link: `sudo containerlab capture --name bgp-ebgp-ibgp-path-choice --target edge-b1:eth2 --duration 20s -w - > "$HOME/neo-ibgp.pcapng"`. While it runs, in a second Terminal: `docker exec clab-bgp-ebgp-ibgp-path-choice-edge-b1 vtysh -c "clear bgp ipv4 unicast 10.0.23.2"`. Open the file with the filter `bgp` (or open `captures/ibgp-session-restart.pcapng`) | Two OPEN messages, both `My AS: 65202` (same AS on both ends is what makes it iBGP). UPDATE messages carry `LOCAL_PREF` and an AS path that does not yet contain AS 65202; an eBGP UPDATE (open `captures/ebgp-session-restart.pcapng`) has no `LOCAL_PREF` and carries the sender's AS first in the path. A `Cease / Connection Collision Resolution` NOTIFICATION is normal when both routers reconnect at once; ignore it | Nothing to undo |

## Troubleshooting

1. **`show bgp summary` on edge-b2 shows a neighbor in `Active` or `Connect` just after Deploy.** There are three sessions and SR Linux is slow to start. Wait the full two minutes after Deploy, then check again. After 4 minutes with no change, run `containerlab redeploy -c -t bgp-ebgp-ibgp-path-choice.clab.yml`.
2. **E1 shows only one path to 192.168.20.0/24 on edge-a.** One of edge-a's two eBGP sessions is down. On edge-a run `show network-instance default protocols bgp neighbor`: both 10.0.12.2 and 10.0.13.2 must be `established`. If one is not, wait a minute and check again, then reset with `redeploy -c`.
3. **E4 (`no neighbor ... next-hop-self`) makes the iBGP path on edge-b2 show `inaccessible`.** That is the lesson: the path now names 10.0.12.1, which edge-b2 cannot reach, and traffic still flows through the eBGP path. Use the **Put it back** step in the exercise table (add `next-hop-self` again) or reset with `containerlab redeploy -c -t bgp-ebgp-ibgp-path-choice.clab.yml`.
4. **The E5 capture file is empty, or you see only KEEPALIVEs.** Start the capture first (in Ubuntu's Terminal, with `sudo`), then run the `clear bgp` command in a second window within the 20 seconds. Filter `bgp`.
5. **After a VM restart one node has a stopped dot.** In the lab folder run `containerlab redeploy -t bgp-ebgp-ibgp-path-choice.clab.yml` (no `-c`) and wait two minutes.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/bgp-ebgp-ibgp-path-choice
```
```
containerlab destroy --cleanup -t bgp-ebgp-ibgp-path-choice.clab.yml
```
`--cleanup` also removes the generated `clab-bgp-ebgp-ibgp-path-choice` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-bgp-ebgp-ibgp-path-choice` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/bgp-ebgp-ibgp-path-choice/clab-bgp-ebgp-ibgp-path-choice
```
Your capture files in your Home folder are not touched.

## Concept comparison (not part of this lab)

Arista EOS and Juniper Junos use the same BGP decision steps (local preference, AS-path length, eBGP over iBGP) with different command words. This kit does not include those images.
