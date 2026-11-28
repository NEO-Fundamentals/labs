# Lab: one eBGP session, two different network operating systems

**Folder:** `labs/multivendor-ebgp/`  **Lab file:** `multivendor-ebgp.clab.yml`  **Lesson:** NEO-32 Multi-vendor eBGP  **Lab version:** 1.0.2 (2026-11-27, kit 1.2.3: E3 wording, E4 now says how to capture the Bad Peer AS NOTIFICATION; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.0.1)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-ebgp/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk), `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 5 to 10 minutes (downloads); later Deploys take about 2 minutes, then about a minute for BGP.

## What this lab builds

```
 host-a                edge-a                     edge-b                host-b
 192.168.10.10  ---  SR Linux  ==== WAN ====  FRR (Cisco-style)  ---  192.168.20.10
 (Site A PC)        AS 65201   10.0.12.1/30   10.0.12.2/30  AS 65202   (Site B PC)
                 192.168.10.1/24                    192.168.20.1/24
```

Two real routers from two different makers run one eBGP session. It is the same topology and the same starting configs as `ebgp-two-sites`, kept in its own folder so this lesson opens with everything it needs. **Arista EOS and Juniper Junos are shown as text only** (table below): this kit has no EOS or Junos images.

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| edge-a | Nokia SR Linux router, AS 65201 | `ghcr.io/nokia/srlinux:26.7.2` | Right-click > **Access** > **Attach Shell** (opens `sr_cli`) |
| edge-b | FRR router, AS 65202 | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| host-a, host-b | Linux PCs | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. AS numbers are private (64512 to 65534). **edge-a shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `multivendor-ebgp.clab.yml` - the lab drawing.
- `configs/edge-a-srl.cli`, `configs/edge-b-frr.conf` - starting configs.
- `multivendor-ebgp.drawio` and `.png` - the prepared diagram.
- `captures/ebgp-session-restart.pcapng` - sample capture of the WAN link while the session restarts (open with the filter `bgp`).
- `scripts/make-captures.sh` - re-records that file (the lab must be running). Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.

## Start, reset, stop

Type or paste commands one line at a time.

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-ebgp` > right-click the `.clab.yml` file > **Deploy**. Run one lab at a time. **Wait about a minute** before checking BGP. Checkpoint, in Ubuntu's Terminal:
  ```
  docker exec clab-multivendor-ebgp-edge-b vtysh -c "show bgp summary"
  ```
  The neighbor 10.0.12.1 shows `1` under `State/PfxRcd`.
- **Reset (and after editing a config file):** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/multivendor-ebgp
  ```
  ```
  containerlab redeploy -c -t multivendor-ebgp.clab.yml
  ```
- **After a VM restart:** check all four nodes have green dots; if edge-b is stopped, run `containerlab redeploy -t multivendor-ebgp.clab.yml` in the lab folder (no `-c`).
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The same session on four systems

The first two columns run in this lab. The last two are text only.

| Step | Nokia SR Linux (live) | FRR (live) | Arista EOS (text only) | Juniper Junos (text only) |
|---|---|---|---|---|
| My AS | `set / network-instance default protocols bgp autonomous-system 65201` | `router bgp 65202` | `router bgp 65201` | `set routing-options autonomous-system 65201` |
| Neighbor and its AS | `... bgp group ebgp peer-as 65202` then `... bgp neighbor 10.0.12.2 peer-group ebgp` | `neighbor 10.0.12.1 remote-as 65201` | `neighbor 10.0.12.2 remote-as 65202` | `set protocols bgp group ebgp type external`, `set protocols bgp group ebgp peer-as 65202`, `set protocols bgp group ebgp neighbor 10.0.12.2` |
| Advertise Site's network | a prefix-set and an export policy | `network 192.168.20.0/24` under `address-family ipv4 unicast` | `network 192.168.10.0/24` | an export policy: `set protocols bgp group ebgp export export-site` with a `policy-statement` that accepts 192.168.10.0/24 |
| Check the session | `show network-instance default protocols bgp neighbor` | `show bgp summary` | `show ip bgp summary` | `show bgp summary` |
| Check the routes | `show network-instance default protocols bgp routes ipv4 summary` | `show bgp ipv4 unicast` | `show ip bgp` | `show route protocol bgp` |

The ideas are identical: your AS, the neighbor's address and AS, what you advertise, and one command to read the session state. Only the words differ.

## Check it works

1. edge-b Attach Shell: `show bgp summary` - neighbor 10.0.12.1, `State/PfxRcd` is 1.
2. edge-a Attach Shell: `show network-instance default protocols bgp neighbor` - 10.0.12.2 is `established`.
3. host-a shell: `ping -c 3 192.168.20.10` - 3 replies.

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | Run the "Check the session" command on edge-a and on edge-b | Both ends say the session is up (`established` on SR Linux; a prefix count under `State/PfxRcd` on FRR), with the other router's AS (65202 and 65201) | Nothing to undo |
| E2 | Run the "Check the routes" command on both | edge-a learned 192.168.20.0/24 with AS path `65202`. edge-b learned 192.168.10.0/24 with AS path `65201` (`show bgp ipv4 unicast`). Same BGP table idea, different layout | Nothing to undo |
| E3 | In Ubuntu's Terminal: `sudo containerlab capture --name multivendor-ebgp --target edge-b:eth1 --duration 20s -w - > "$HOME/neo-mv-bgp.pcapng"`. While it runs, in a second Terminal: `docker exec clab-multivendor-ebgp-edge-b vtysh -c "clear bgp ipv4 unicast 10.0.12.1"`. Open the file (or `captures/ebgp-session-restart.pcapng`) with the filter `bgp` and open each OPEN message | The OPEN from 10.0.12.1 (SR Linux) says `My AS: 65201`, hold time 90 s, BGP identifier 10.255.0.1. The OPEN from 10.0.12.2 (FRR) says `My AS: 65202`, hold time 180 s, identifier 10.255.0.2. The two makers offer different timers and different optional capabilities (FRR lists more); the session still comes up because the required fields match, and the lower hold time is used. A first NOTIFICATION `Cease / Administratively Reset` (Wireshark's wording) is the restart you asked for | Nothing to undo |
| E4 | In `configs/edge-b-frr.conf` change `remote-as 65201` to `remote-as 65299`, save, run the clean redeploy (`-c`) above. Check `show bgp summary` on edge-b and `show network-instance default protocols bgp neighbor` on edge-a. To see why in Wireshark, record the link with the E3 capture command, but with `--duration 60s` and a new file name (no `clear bgp` needed), and filter `bgp` | The session never comes up on either vendor (edge-b `Idle`/`Active`; SR Linux not `established`). In the capture both routers send an OPEN, then edge-b (10.0.12.2) answers with a NOTIFICATION `OPEN Message Error / Bad Peer AS`; this repeats every few seconds to half a minute | Change it back to 65201, save, run the clean redeploy again |

## Troubleshooting

1. **BGP shows `Active` or `Connect` right after Deploy.** SR Linux takes one to two minutes to boot. Wait, then check again; if it is still down after 3 minutes run `containerlab redeploy -c -t multivendor-ebgp.clab.yml`.
2. **After a VM restart edge-b (FRR) is stopped.** In the lab folder run `containerlab redeploy -t multivendor-ebgp.clab.yml` (no `-c`), and wait about a minute.
3. **You edited a config file and nothing changed.** Configs are read only on a clean deploy: run `containerlab redeploy -c -t multivendor-ebgp.clab.yml`.
4. **The capture of the session restart has no BGP lines.** Start the capture first in Ubuntu's Terminal with `sudo`, restart the session in a second window, and type `bgp` in the filter bar.
5. **You look for Arista EOS or Juniper Junos in the Containerlab panel.** They are not in this kit. Their commands appear in the lab README as text only, for comparison.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-ebgp
```
```
containerlab destroy --cleanup -t multivendor-ebgp.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-ebgp` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-ebgp` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-ebgp/clab-multivendor-ebgp
```
Your capture files in your Home folder are not touched.

## Concept comparison (not part of this lab)

Arista EOS and Juniper Junos behave as described in the text table, but this kit does not include those images.
