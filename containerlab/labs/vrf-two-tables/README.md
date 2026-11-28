# Lab: VRFs, separate routing tables on one device

**Folder:** `labs/vrf-two-tables/`  **Lab file:** `vrf-two-tables.clab.yml`  **Lesson:** NEO-12 VRFs: Separate Routing Tables on One Device  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs one real Nokia SR Linux router (r1) with two VRFs and three Linux hosts. On SR Linux a VRF is a **network-instance of type `ip-vrf`**; r1 has two, `alpha` and `beta`. These are real separate routing tables (the lesson video was recorded in an older setup that imitated them with Linux policy routing). **There is no Arista EOS, Juniper Junos or Cisco device in this lab.**

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/vrf-two-tables/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/nokia/srlinux:26.7.2` (about 2.4 GB on disk) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 4 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 5 to 10 minutes (downloads); later Deploys take about a minute. **Then wait 1 to 2 more minutes** for SR Linux to start. Do not start the exercises until the check in **Start** passes.

## What this lab builds

```
 h1  10.12.1.10 ----+   VRF alpha
     10.12.1.0/24    \  (ethernet-1/1, ethernet-1/2)
                      r1 (SR Linux) ---------------- h3  10.12.3.10
 h2  10.12.2.10 ----+/                  VRF beta          10.12.3.0/24
     10.12.2.0/24       (ethernet-1/3)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| h1 | Linux host in VRF alpha: 10.12.1.10/24, route to 10.12.0.0/16 via r1 (10.12.1.1) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| h2 | Linux host in VRF alpha: 10.12.2.10/24, route to 10.12.0.0/16 via 10.12.2.1 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| r1 | SR Linux router. VRF `alpha`: ethernet-1/1 10.12.1.1/24, ethernet-1/2 10.12.2.1/24. VRF `beta`: ethernet-1/3 10.12.3.1/24 | `ghcr.io/nokia/srlinux:26.7.2` | Attach Shell (opens `sr_cli`) |
| h3 | Linux host in VRF beta: 10.12.3.10/24, route to 10.12.0.0/16 via 10.12.3.1 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |

The hosts know nothing about VRFs: each just sends everything for 10.12.0.0/16 to r1. Which table r1 looks in depends on the **interface the packet arrives on**.

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. **r1 shows twice under Running Labs**; the second is SR Linux's internal helper, ignore it.

## Files

- `vrf-two-tables.clab.yml` - the lab drawing.
- `configs/r1-srl.cli` - r1 (SR Linux): the three interfaces and the two network-instances `alpha` and `beta`. Nothing is leaked at the start.
- `changes/` - the route leak, applied to r1 with `docker exec -i ... sr_cli < changes/<file>`:
  - `leak-1-alpha-takes-h3.cli` - adds a /32 route to each host in its own VRF, two routing policies that let only those host routes through, an **export** policy on both VRFs (what each one offers) and an **import** policy on alpha only (alpha takes h3's route; beta takes nothing yet).
  - `leak-2-beta-takes-alpha.cli` - the import policy on beta (beta takes the routes to h1 and h2): the way back.
  - `leak-undo.cli` - removes both VRFs' import and export policies, so nothing is leaked again.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it switches any leak off first, takes about one minute, switches the leak off again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `vrf-two-tables.drawio` and `vrf-two-tables.png` - the prepared diagram.
- `captures/` - three sample captures, recorded from this lab: `vrf-1-isolation.pcapng`, `vrf-2-one-way-leak.pcapng`, `vrf-3-two-way-leak.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `vrf-two-tables` > right-click `vrf-two-tables.clab.yml` > **Deploy**. Wait for the green dots, then check r1 in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-vrf-two-tables-r1 sr_cli "show network-instance summary"
  ```
  Three lines: `alpha`, `beta` and `mgmt` (the management VRF Containerlab uses), each `ip-vrf`, `enable`, `up`. If it prints an error, SR Linux is still starting: wait a minute and run it again.
- **Reset to the lesson start** (no leak, no host routes):
  ```
  cd ~/labs-main/containerlab/labs/vrf-two-tables
  ```
  ```
  containerlab redeploy -c -t vrf-two-tables.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | SR Linux (r1: `sr_cli`) | Linux hosts |
|---|---|---|
| List the VRFs | `show network-instance summary` | - |
| One VRF's routing table | `show network-instance alpha ipv4 route` | `ip route` |
| Ping from the router, in a VRF | `ping 10.12.3.10 -c 2 network-instance beta` | `ping -c 2 10.12.3.10` |
| See what a VRF imports and exports | `info network-instance alpha inter-instance-policies` | - |
| Wireshark filter | `icmp` | `icmp` |

Junos and EOS are not part of this lab. On them and on Cisco devices the same idea is called a VRF or a routing instance, and a router command such as `ping` or `show ip route` needs the VRF name, just like `network-instance beta` here. Leaking between VRFs is usually done with route targets in BGP or with routing policies; the idea is the same as r1's import and export policies.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name.

**1. Two tables on one router.**
```
docker exec clab-vrf-two-tables-r1 sr_cli "show network-instance alpha ipv4 route"
```
```
docker exec clab-vrf-two-tables-r1 sr_cli "show network-instance beta ipv4 route"
```
alpha holds two rows, `10.12.1.0/24` and `10.12.2.0/24` (type `local`: the subnets of its own interfaces). beta holds one row, `10.12.3.0/24`. There is no table that holds all three. Each interface belongs to exactly one VRF, and a packet is looked up in the table of the interface it arrived on.

**2. Inside one VRF everything works.**
```
docker exec clab-vrf-two-tables-h1 ping -c 2 10.12.2.10
```
Two replies: h1 and h2 are both in alpha, and alpha has both subnets.

**3. Isolation.**
```
docker exec clab-vrf-two-tables-h1 ping -c 2 -W 1 10.12.3.10
```
```
From 10.12.1.1 icmp_seq=1 Destination Net Unreachable
From 10.12.1.1 icmp_seq=2 Destination Net Unreachable
```
The address is right and the cable is fine. h1's packet arrives on ethernet-1/1, so r1 looks in alpha, and alpha has **no 10.12.3.0/24 row**. r1 answers "net unreachable" from its alpha address 10.12.1.1. The sample `captures/vrf-1-isolation.pcapng` shows it on h1's cable: request, unreachable, three times, and nothing at all on h3's cable. Even h3's gateway, 10.12.3.1 (an address on r1 itself), is unreachable from h1.

**4. A ping from the router itself.** A router command has to say which table to use:
```
docker exec clab-vrf-two-tables-r1 sr_cli "ping 10.12.3.10 -c 2"
```
It prints `ping: connect: Network is unreachable` and `Using network instance <base>`: without a name, SR Linux uses its own base Linux table, which has none of the lab's routes. Name the VRF h3 is in:
```
docker exec clab-vrf-two-tables-r1 sr_cli "ping 10.12.3.10 -c 2 network-instance beta"
```
Two replies. From the router, always name the VRF; the ping then also leaves with a source address from that VRF (here 10.12.3.1).

**5. A leak, one way only.** Let alpha take the route to h3:
```
cd ~/labs-main/containerlab/labs/vrf-two-tables
```
```
docker exec -i clab-vrf-two-tables-r1 sr_cli < changes/leak-1-alpha-takes-h3.cli
```
It prints `All changes have been committed. Leaving candidate mode.` Now alpha has a new row:
```
docker exec clab-vrf-two-tables-r1 sr_cli "show network-instance alpha ipv4 route"
```
```
10.12.3.10/32        static       1        5       >L       10.12.3.10(net-instance:beta, route:local)
```
`L` means leaked from another network-instance, and the next hop says `net-instance:beta`. Try the ping again:
```
docker exec clab-vrf-two-tables-h1 ping -c 2 -W 1 10.12.3.10
```
`100% packet loss`, and this time without any "unreachable" line. The sample `captures/vrf-2-one-way-leak.pcapng` shows why: on h3's cable the request arrives (frame 2) and h3 sends its reply (frame 3). The reply arrives at r1 on ethernet-1/3, so r1 looks it up in **beta**, and beta has no route to 10.12.1.10. r1 sends an unreachable to h3 (frame 4), and h1 never hears anything. **A leak usually has to go both ways.**

**6. The way back.**
```
docker exec -i clab-vrf-two-tables-r1 sr_cli < changes/leak-2-beta-takes-alpha.cli
```
```
docker exec clab-vrf-two-tables-r1 sr_cli "show network-instance beta ipv4 route"
```
beta now has `10.12.1.10/32` and `10.12.2.10/32` with `L`. Now both work:
```
docker exec clab-vrf-two-tables-h1 ping -c 2 10.12.3.10
```
```
docker exec clab-vrf-two-tables-h3 ping -c 2 10.12.2.10
```
Two replies each, and `traceroute -n -w 1 10.12.3.10` from h1 shows two hops: 10.12.1.1 (r1), 10.12.3.10. Compare with `captures/vrf-3-two-way-leak.pcapng`: request and reply on both cables. See what alpha imports and exports:
```
docker exec clab-vrf-two-tables-r1 sr_cli "info network-instance alpha inter-instance-policies"
```
`import-policy [ beta-hosts-only ]` and `export-policy [ alpha-hosts-only ]`. Only the three host routes cross; everything else stays in its own VRF.

**7. What did not leak.** The leak is only what you allowed:
```
docker exec clab-vrf-two-tables-h1 ping -c 2 -W 1 10.12.3.1
```
Still `Destination Net Unreachable`: only 10.12.3.10/32 crossed into alpha, not the whole 10.12.3.0/24 and not r1's own address 10.12.3.1. The same from the router:
```
docker exec clab-vrf-two-tables-r1 sr_cli "ping 10.12.3.10 -c 2 network-instance alpha"
```
`100% packet loss`: the ping leaves from alpha's address 10.12.1.1, and the policies only let the host routes cross, so beta has no way back to 10.12.1.1. With `network-instance beta` it works. From the router, name a VRF that has a source address the far side can answer.

**8. Switch the leak off.**
```
docker exec -i clab-vrf-two-tables-r1 sr_cli < changes/leak-undo.cli
```
The `L` rows are gone, and h1's ping to h3 says `Destination Net Unreachable` again. (The /32 host routes and the policies from `leak-1` stay in the configuration, unused; redeploy for a fully clean start.)

## Sample captures

Each recording covers h1's cable (`h1:eth1`) and h3's cable (`h3:eth1`) for 10 seconds while h1 pings h3 three times. Open them in Wireshark with File > Open and filter on `icmp`. The interface name of each frame is in the frame details.

| File | Frames | What it shows |
|---|---|---|
| `vrf-1-isolation.pcapng` | 8 | No leak: each request on h1's cable is answered by r1 (10.12.1.1) with Destination unreachable (Network unreachable); nothing on h3's cable |
| `vrf-2-one-way-leak.pcapng` | 14 | alpha takes h3's route, beta takes nothing: the request reaches h3 and h3 replies, but r1 answers h3's reply with Network unreachable from 10.12.3.1; h1 gets nothing |
| `vrf-3-two-way-leak.pcapng` | 14 | Both ways: request and reply on both cables |

The last two frames of each file are ARP between a host and r1.

## What this lab does not do

- No routing protocol: each VRF knows only its own connected subnets and the host routes from `leak-1`. In real networks VRFs are often carried between routers with MPLS and BGP (route distinguishers and route targets); that is not part of this lesson.
- No overlapping addresses. VRFs allow the same subnet in two VRFs; this lab keeps them different so the leak works.
- No Linux VRF devices on the hosts; the hosts are plain.
- **Why the leak uses /32 host routes:** on SR Linux 26.7.2 in this lab, leaking the connected /24 subnets makes the routes appear with `L`, but traffic to a host behind the other VRF's interface is not delivered. A /32 static route to each host, in the host's own VRF, leaks and works. That is what `leak-1` does.

## Troubleshooting

1. **`show network-instance summary` prints an error, or a change file says `Error: Commit failed`.** SR Linux is still starting: wait a minute and try again.
2. **A change command says `No such file or directory` or `Input not from a terminal`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/vrf-two-tables`) so that `changes/...` is found, and keep the `-i` in `docker exec -i`: without `-i`, `sr_cli` never gets the file and says `Error: Input not from a terminal/file/pipe (fd=0).`
3. **You edited a change file and now it fails with `Leafref destination ... does not exist` or a parsing error.** `sr_cli` reads the file line by line; lines that start with `#` are not comments there and break the commit. Keep only `enter candidate`, the `set` or `delete` lines and `commit now`.
4. **h1 still cannot reach h3 after exercise 6.** Check both tables (exercise 1 commands): alpha needs `10.12.3.10/32` with `L`, beta needs `10.12.1.10/32` with `L`. If one is missing, apply that change file again. If nothing helps, reset the lab (see **Start, reset, stop**) and start at exercise 5.
5. **`sr_cli` says a command is unknown.** SR Linux is picky about spaces; copy the command exactly, or open r1 with Attach Shell and press the question mark key for the options.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/vrf-two-tables
```
```
containerlab destroy --cleanup -t vrf-two-tables.clab.yml
```
`--cleanup` also removes the generated `clab-vrf-two-tables` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-vrf-two-tables` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/vrf-two-tables/clab-vrf-two-tables
```
Your capture files in your Home folder are not touched.
