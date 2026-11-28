# Lab: two sites joined by eBGP

**Folder:** `labs/ebgp-two-sites/`  **Lab file:** `ebgp-two-sites.clab.yml`  **Lab version:** 1.1.6 (2026-11-27, kit 1.2.3: keepalive sample duration wording; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.1.5)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/ebgp-two-sites/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 5 to 10 minutes (downloads); later Deploys take about 2 minutes. SR Linux then needs about a minute before BGP comes up.

## What this lab builds

```
 host-a                edge-a                     edge-b                host-b
 192.168.10.10  ---  SR Linux  ==== WAN ====  FRR (Cisco-style)  ---  192.168.20.10
 (Site A PC)        AS 65201   10.0.12.1/30   10.0.12.2/30  AS 65202   (Site B PC)
                 192.168.10.1/24                    192.168.20.1/24
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| edge-a | Nokia SR Linux router, AS 65201 | `ghcr.io/nokia/srlinux:26.7.2` | Right-click > **Access** > **Attach Shell** (opens `sr_cli`), or **SSH** (user `admin`, password `NokiaSrl1!`) |
| edge-b | FRR router, AS 65202 | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh` directly) |
| host-a | Linux PC on Site A LAN | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| host-b | Linux PC on Site B LAN | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64 (set in the lab file under `mgmt:`). The AS numbers are private (64512 to 65534).

**edge-a shows twice under Running Labs.** The second one is SR Linux's internal helper (`edge-a-netns`). Ignore it and use the first edge-a.

## Files

- `ebgp-two-sites.clab.yml` - the lab drawing: which routers, which cables.
- `configs/edge-a-srl.cli` - edge-a's starting config.
- `configs/edge-b-frr.conf` - edge-b's starting config.
- `ebgp-two-sites.drawio` and `ebgp-two-sites.png` - the prepared diagram (open the `.drawio` in VS Code, or the `.png` in any viewer).
- `captures/ebgp-session-restart.pcapng` - sample capture of the WAN link while the session restarts (open with the filter `bgp`). Recorded in the identical `multivendor-ebgp` lab (same topology and configs).
- `captures/ebgp-keepalive.pcapng` - sample for E4: the WAN link of this lab, healthy, recorded on a VM. Its packets span about 97 seconds (first to last packet). It shows one KEEPALIVE from each router every 30 seconds (filter `bgp`).
- `scripts/make-captures.sh` - re-records `ebgp-session-restart.pcapng` (the lab must be running). The keepalive sample was recorded by hand; to record your own, use the E4 row. Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.

## Start, reset, stop

Type or paste commands one line at a time.

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `ebgp-two-sites` > right-click `ebgp-two-sites.clab.yml` > **Deploy**. The first time, the images download from the internet (about 3 GB), so allow 5 to 15 minutes. **Then wait about a minute before you ping**: BGP needs a little longer than the green dots. In Ubuntu's Terminal, the checkpoint is `1` under State/PfxRcd:
  ```
  docker exec clab-ebgp-two-sites-edge-b vtysh -c "show bgp summary"
  ```
- **After you edit a config file (and to reset to the lesson start):** in VS Code, **Terminal > New Terminal**, then:
  ```
  cd ~/labs-main/containerlab/labs/ebgp-two-sites
  ```
  ```
  containerlab redeploy -c -t ebgp-two-sites.clab.yml
  ```
  `-c` (cleanup) throws away the old saved configs so your edit is used. Don't use the menu's **Redeploy (Cleanup)**; in our tests it closed VS Code.
- **After a VM restart** (Ubuntu shows the login screen first): check that edge-a, edge-b, host-a and host-b all have green dots before you troubleshoot anything. **edge-b is always the one left stopped.** If it is, in the lab folder run:
  ```
  containerlab redeploy -t ebgp-two-sites.clab.yml
  ```
  No `-c` here: the routers keep their saved configs. The command first prints two long red `ERRO container "clab-ebgp-two-sites-edge-b" exited` blocks. That's expected and harmless. Wait about a minute for BGP, then re-check.
- **Stop:** right-click the running lab > **Destroy**. Plain Destroy leaves the generated, root-owned `clab-ebgp-two-sites` folder; **Destroy (Cleanup)** removes it. Keep capture files in your Home folder so neither touches them.
- **Diagram:** `containerlab graph --drawio -t ebgp-two-sites.clab.yml`, then `sudo chown $USER:$USER ebgp-two-sites.clab.drawio`, then click the file to edit it.

## Capture to a file (main method)

In Ubuntu's Terminal app (not VS Code's terminal), record edge-b's WAN interface for 45 seconds:
```
sudo containerlab capture --name ebgp-two-sites --target edge-b:eth1 --duration 45s -w - > "$HOME/neo-wan-test.pcapng"
```
While it runs (the terminal stays quiet; that's normal), open a second Terminal window and ping:
```
docker exec clab-ebgp-two-sites-host-a ping -c 3 192.168.20.10
```
When the prompt comes back, open Wireshark > **File > Open...** > Home > `neo-wan-test.pcapng` and filter `icmp`: three echo requests and three replies between 192.168.10.10 and 192.168.20.10. (Without the filter the file holds about 14 frames: ARP, BGP keepalives, LLDP and IPv6 router solicitation too.) Use a new file name each run.
Optional shortcut: right-click edge-b > eth1 > **Capture With Wireshark** (live). If the Wireshark window crashes (GLib "antialiasing" error), use the file method.

## Check it works

1. edge-b Attach Shell: `show bgp summary` - neighbor 10.0.12.1 shows a number in `State/PfxRcd` (1), not `Active` or `Connect`.
2. edge-a Attach Shell: `show network-instance default protocols bgp neighbor` - 10.0.12.2 is `established`.
3. host-a shell: `ping -c 3 192.168.20.10` - 3 replies.

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | Run the 45-second file capture above while host-a pings 192.168.20.10, then open the file with the `icmp` filter | ICMP echo request/reply on the WAN link | Nothing to undo |
| E2 | In `configs/edge-b-frr.conf`, change `remote-as 65201` to `remote-as 65299`, save, run the clean redeploy (`-c`) above. Then record 75 seconds to a new file (command below) and open it with the `bgp` filter | BGP never comes up (edge-b `Idle`); ping fails with `Destination Net Unreachable` from 192.168.10.1, so no ICMP appears on the WAN capture; the file shows OPEN then NOTIFICATION. Expand a NOTIFICATION from 10.0.12.2: OPEN Message Error, **Bad Peer AS (2)**, Bad Peer AS: 65201. (A `Cease / Connection Collision Resolution` NOTIFICATION from 10.0.12.1 is normal; ignore it.) | Change it back to 65201, save, run the clean redeploy again |
| E3 | edge-a Attach Shell: `enter candidate`, `set / interface ethernet-1/1 admin-state disable`, `commit now` | BGP drops; ping fails | `enter candidate`, `set / interface ethernet-1/1 admin-state enable`, `commit now` |
| E4 | Record the WAN link for 2 minutes (`--duration 120s`, new file name) and filter `bgp` | BGP KEEPALIVE messages about every 30 s from each router (the hold time is 90 s and the keepalive is one third of it) | Nothing to undo |

E2 capture. Start it right after the clean redeploy finishes. 75 seconds is long enough to catch the routers trying again at least once. OPEN and NOTIFICATION lines repeat while the routers keep retrying; your count and times will differ:
```
sudo containerlab capture --name ebgp-two-sites --target edge-b:eth1 --duration 75s -w - > "$HOME/neo-wrong-as.pcapng"
```

## Troubleshooting

1. **`show bgp summary` on edge-b shows `Active` or `Connect`, or edge-a's neighbor is not `established`, just after Deploy.** SR Linux takes one to two minutes to boot and start BGP. Wait, then run the check again. If it is still down after 3 minutes, reset with `containerlab redeploy -c -t ebgp-two-sites.clab.yml`.
2. **After a VM restart edge-b has a stopped (grey) dot and BGP is down.** edge-b is always the router left stopped. In the lab folder run `containerlab redeploy -t ebgp-two-sites.clab.yml` (no `-c`), ignore the two red `ERRO ... exited` blocks, and wait about a minute.
3. **You changed `remote-as` in `configs/edge-b-frr.conf` (E2) and nothing changed.** Configs are read only on a clean deploy. Run `containerlab redeploy -c -t ebgp-two-sites.clab.yml`; a plain Redeploy keeps the saved config.
4. **The E2 capture has no BGP lines.** You started the capture too late or the filter is not applied. Start it right after the clean redeploy table appears, record 75 seconds, and type `bgp` in the filter bar so it turns green.
5. **`sudo containerlab capture` prints a permission error, or the Wireshark window crashes with a GLib error.** Run the capture in Ubuntu's Terminal app (not VS Code's terminal) and keep the `sudo`. If live capture from the right-click menu crashes, use the file method.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/ebgp-two-sites
```
```
containerlab destroy --cleanup -t ebgp-two-sites.clab.yml
```
`--cleanup` also removes the generated `clab-ebgp-two-sites` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-ebgp-two-sites` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/ebgp-two-sites/clab-ebgp-two-sites
```
Your capture files in your Home folder are not touched.

## Concept comparison (not part of this lab)

Arista EOS and Juniper Junos use the same BGP ideas (local AS, neighbor, remote AS, which networks to advertise) with different command words. This kit does not include those images.
