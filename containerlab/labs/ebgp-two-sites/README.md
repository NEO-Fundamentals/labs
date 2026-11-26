# Lab: two sites joined by eBGP

**Folder:** `labs/ebgp-two-sites/`  **Lab file:** `ebgp-two-sites.clab.yml`  **Lab version:** 1.1.1 (2026-11-26, renamed from the 1.0.0 lab)

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
| host-a | Linux PC on Site A LAN | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| host-b | Linux PC on Site B LAN | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64 (set in the lab file under `mgmt:`). The AS numbers are private (64512 to 65534).

**edge-a shows twice under Running Labs.** The second one is SR Linux's internal helper (`edge-a-netns`). Ignore it and use the first edge-a.

## Files

- `ebgp-two-sites.clab.yml` - the lab drawing: which routers, which cables.
- `configs/edge-a-srl.cli` - edge-a's starting config.
- `configs/edge-b-frr.conf` - edge-b's starting config.

## Start, reset, stop

- **Start:** Containerlab panel > right-click `ebgp-two-sites.clab.yml` > **Deploy**. The first time, the images download (about 3 GB), so allow 5 to 15 minutes.
- **After you edit a config file (and to reset to the lesson start):** in VS Code, **Terminal > New Terminal**, then:
  `cd ~/labs-main/containerlab/labs/ebgp-two-sites`
  `containerlab redeploy -c -t ebgp-two-sites.clab.yml`
  `-c` (cleanup) throws away the old saved configs so your edit is used. Don't use the menu's **Redeploy (Cleanup)**; in our tests it closed VS Code.
- **Stop:** right-click the running lab > **Destroy**.
- **Diagram:** `containerlab graph --drawio -t ebgp-two-sites.clab.yml`, then `sudo chown $USER:$USER ebgp-two-sites.clab.drawio`, then click the file to edit it.

## Check it works

1. edge-b Attach Shell: `show bgp summary` - neighbor 10.0.12.1 shows a number in `State/PfxRcd` (1), not `Active` or `Connect`.
2. edge-a Attach Shell: `show network-instance default protocols bgp neighbor` - 10.0.12.2 is `established`.
3. host-a shell: `ping -c 3 192.168.20.10` - 3 replies.

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | Right-click edge-b > eth1 > **Capture With Wireshark**, then on host-a run `ping 192.168.20.10` | ICMP echo request/reply on the WAN link | Stop the capture |
| E2 | In `configs/edge-b-frr.conf`, change `remote-as 65201` to `remote-as 65299`, save, run the redeploy command above | BGP never comes up; capture shows OPEN then NOTIFICATION "Bad Peer AS"; ping fails | Change it back to 65201, save, run the redeploy command again |
| E3 | edge-a Attach Shell: `enter candidate`, `set / interface ethernet-1/1 admin-state disable`, `commit now` | BGP drops; ping fails | `enter candidate`, `set / interface ethernet-1/1 admin-state enable`, `commit now` |
| E4 | Capture on the WAN link and wait 2 minutes | BGP KEEPALIVE messages every ~60 s | Nothing to undo |

## Concept comparison (not part of this lab)

Arista EOS and Juniper Junos use the same BGP ideas (local AS, neighbor, remote AS, which networks to advertise) with different command words. This kit does not include those images.
