# Lab: A firewall pair: failover, and what happens to sessions

**Folder:** `labs/firewall-ha-vrrp/`  **Lab file:** `firewall-ha-vrrp.clab.yml`  **Lesson:** NEO-18 Firewall high availability: active/passive, session sync, and failover testing  **Lab version:** 1.1.0 (2026-11-27)

**What runs and what does not:** `fw1` and `fw2` are Linux routers running **nftables with connection tracking**, **keepalived (VRRP)** and **conntrackd** (session sync) in the NEO helper image `neo-tools:1.1.0`. The shared gateway addresses, the VRRP advertisements, the failover, the outage window, and the copied session table are real. They are a Linux packet-filter pair, **not a commercial firewall cluster**: there is a dedicated HA link for session sync, but no configuration sync. Exercise 4 stops conntrackd to show what a failover does **without** session sync; exercise 6 leaves it running so the session survives.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** modest: four Linux containers and two small switch containers, about 60 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/firewall-ha-vrrp/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy uses `ghcr.io/neo-fundamentals/neo-tools:1.0.0` for the hosts, `ghcr.io/neo-fundamentals/neo-tools:1.1.0` for the two firewalls (conntrackd), and `ghcr.io/srl-labs/network-multitool:v0.10.0` for the two switches. 1.1.0 is built from `tools/neo-tools` and is not on the public registry yet; load or build that tag before Deploy (see the kit README). After the images are present the lab works offline.
- **Time:** Deploy takes a few seconds; the pair elects its active firewall about 4 seconds later. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab assumes you know rules, `ct state` and the session table.

## What this lab builds

```
                         fw1 (priority 150, active)
                    .2 eth1                eth2 .2
   host-a ---- sw-in           eth3 HA              sw-out ---- host-b
 10.18.1.10         .3 eth1    10.18.3.0/24    eth2 .3          10.18.2.20
 gw 10.18.1.1            fw2 (priority 100, standby)        web :80, sessions :7000
                                                            route to 10.18.1.0/24 via 10.18.2.1

   virtual addresses, held by the active firewall:  inside 10.18.1.1   outside 10.18.2.1
   HA link (session sync only): fw1 10.18.3.2  --  fw2 10.18.3.3
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw1 | firewall 1: nftables + keepalived + conntrackd, VRRP **priority 150**. eth1 = inside 10.18.1.2/24, eth2 = outside 10.18.2.2/24, eth3 = HA 10.18.3.2/24. `configs/fw1-keepalived.conf`, `configs/fw1-conntrackd.conf` | `ghcr.io/neo-fundamentals/neo-tools:1.1.0` | Right-click > **Access** > **Attach Shell** |
| fw2 | firewall 2, the same with **priority 100**: eth1 = 10.18.1.3/24, eth2 = 10.18.2.3/24, eth3 = HA 10.18.3.3/24 | same | Attach Shell |
| sw-in, sw-out | plain Linux bridges (no filtering), one per side, so host and both firewalls share each LAN | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| host-a | inside client 10.18.1.10/24, gateway **10.18.1.1** (the virtual address) | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| host-b | outside server 10.18.2.20/24, route to 10.18.1.0/24 via **10.18.2.1** (virtual). Web page on port 80, session server `tick_server.py` on **7000** (log `/var/log/tick.log`) | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**VRRP** (`configs/fw?-keepalived.conf`): two instances, `INSIDE` (eth1, virtual router 18, address 10.18.1.1) and `OUTSIDE` (eth2, virtual router 28, address 10.18.2.1), in one **sync group** so that they always move together; advertisements every second; the higher priority wins and takes the addresses back when it returns (preemption, the keepalived default).

**fw1's and fw2's rules** (`configs/fw-rules.nft`, the same on both, chain `forward`, policy drop): `replies and known sessions` (`ct state established,related`, accept), `no session for this packet` (`ct state invalid`, drop), `inside -> outside` (new sessions from eth1 to eth2, accept), then a counter before the drop. Both use **strict TCP state** (`nf_conntrack_tcp_loose = 0`): a TCP packet from the middle of a session the firewall never saw is `invalid`.

## Files

- `firewall-ha-vrrp.clab.yml` - the lab drawing. Addresses, routes, the rules, the TCP setting, conntrackd and keepalived are set by each node's `exec` lines.
- `configs/fw1-keepalived.conf`, `configs/fw2-keepalived.conf` - VRRP (above). `configs/fw1-conntrackd.conf`, `configs/fw2-conntrackd.conf` - session sync over eth3. `scripts/ha-notify.sh` - keepalived commits or flushes conntrackd's cache on a role change. `configs/fw-rules.nft` - the rules of both firewalls.
- `scripts/session.py` and `scripts/tick_server.py` - one long TCP session: the client sends `tick N` every half second and prints the answer `ok N` (mounted on host-a and host-b as `/neo/scripts/`).
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about two minutes, unplugs fw1 up to four times, leaves the pair as after a deploy, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays). If conntrackd is not running, it prints SKIP for `ha-4-session-sync.pcapng` and leaves that file unchanged (or absent).
- `firewall-ha-vrrp.drawio` and `firewall-ha-vrrp.png` - the prepared diagram.
- `captures/` - sample captures: `ha-1-failover.pcapng`, `ha-2-session-strict.pcapng` and `ha-3-session-loose.pcapng` are in this folder. `ha-4-session-sync.pcapng` is recorded by `make-captures.sh` when both conntrackd daemons stay up (the NEO lab VM has the kernel module they need). The machine that built this kit could not start conntrackd, so ha-4 is not in the folder yet.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `firewall-ha-vrrp` > right-click `firewall-ha-vrrp.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-firewall-ha-vrrp-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.18.2.20/
  ```
  It prints `http 200 in ...`: host-a reached host-b through the active firewall. If it prints `http 000`, wait 5 seconds (the pair is still electing) and try again.
- **Reset to the lesson start** (fw1 plugged in and active, strict TCP state, counters and session tables empty):
  ```
  cd ~/labs-main/containerlab/labs/firewall-ha-vrrp
  ```
  ```
  containerlab redeploy -c -t firewall-ha-vrrp.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Where | Command |
|---|---|---|
| Which firewall holds the virtual addresses? | fw1, fw2 | `ip -br addr show eth1` and `ip -br addr show eth2` (the active one lists 10.18.1.1 and 10.18.2.1 too) |
| What did keepalived decide, and when? | fw1, fw2 | `grep Entering /var/log/keepalived.log` |
| Which MAC address does the host use for its gateway? | host-a | `ip neigh show 10.18.1.1` |
| Watch the VRRP advertisements | host-a | `tcpdump -lnni eth1 -c 3 vrrp` |
| "Unplug" fw1 (inside, outside and HA links down), and plug it back | VM | `docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 down; ip link set eth2 down; ip link set eth3 down'` (and the same with `up`) |
| Which rule counted it? | fw1, fw2 | `nft list chain ip fw forward` |
| Does this firewall know the session? | fw1, fw2 | `conntrack -L | grep 7000` (or `grep 7000 /proc/net/nf_conntrack`) |
| Is session sync running? | fw1, fw2 | `pgrep -a conntrackd` |
| Strict or loose TCP state? | fw1, fw2 | `sysctl net.netfilter.nf_conntrack_tcp_loose` (`0` strict, `1` loose) |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-ha-vrrp`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The pair at rest.**
```
docker exec clab-firewall-ha-vrrp-fw1 ip -br addr show eth1
```
```
docker exec clab-firewall-ha-vrrp-fw2 ip -br addr show eth1
```
```
docker exec clab-firewall-ha-vrrp-fw1 grep Entering /var/log/keepalived.log
```
```
docker exec clab-firewall-ha-vrrp-host-a ip neigh show 10.18.1.1
```
```
docker exec clab-firewall-ha-vrrp-fw1 ip -br link show eth1
```
```
docker exec clab-firewall-ha-vrrp-host-a tcpdump -lnni eth1 -c 3 vrrp
```
fw1's eth1 lists `10.18.1.2/24 10.18.1.1/24`; fw2's only `10.18.1.3/24`. fw1's log: `(INSIDE) Entering BACKUP STATE (init)`, then, about 3 seconds later, `Entering MASTER STATE` for both instances (the sync group moves them together). host-a's gateway 10.18.1.1 resolves to **fw1's own eth1 MAC** (compare the two `lladdr` values). The capture shows `IP 10.18.1.2 > ...: VRRPv2, Advertisement, vrid 18, prio 150, authtype none, intvl 1s` once a second, sent to the VRRP multicast group that every VRRP router listens to: fw1 telling the LAN "I am alive and active". fw2 stays quiet while it hears them.

**2. Failover test: unplug the active firewall.** Start a ping from host-a in a second terminal (two pings a second, 10 seconds):
```
docker exec clab-firewall-ha-vrrp-host-a ping -i 0.5 -c 20 -W 1 10.18.2.20
```
About 3 seconds later, in the first terminal:
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 down; ip link set eth2 down; ip link set eth3 down'
```
When the ping has finished:
```
docker exec clab-firewall-ha-vrrp-fw2 grep Entering /var/log/keepalived.log
```
```
docker exec clab-firewall-ha-vrrp-fw2 ip -br addr show eth1
```
```
docker exec clab-firewall-ha-vrrp-host-a ip neigh show 10.18.1.1
```
The ping summary says about `20 packets transmitted, 13 received`: **about 7 pings, 3.5 seconds, were lost**. That is the outage window: fw2 waits three missed advertisements (3 seconds) plus a little more for its priority before it decides fw1 is gone. fw2's log now has `Entering MASTER STATE` for both instances; fw2's eth1 lists `10.18.1.3/24 10.18.1.1/24`; host-a's gateway now resolves to **fw2's** MAC: fw2 sent gratuitous ARPs for the virtual addresses so the hosts and switches learn the new owner at once. (Sample `ha-1-failover.pcapng`: fw1's advertisements from 10.18.1.2, the gap, then fw2's gratuitous ARPs and advertisements from 10.18.1.3.)

**3. Plug fw1 back in: preemption.**
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 up; ip link set eth2 up; ip link set eth3 up'
```
```
docker exec clab-firewall-ha-vrrp-fw1 grep Entering /var/log/keepalived.log
```
```
docker exec clab-firewall-ha-vrrp-fw2 grep Entering /var/log/keepalived.log
```
fw1's log shows the whole story: `Entering FAULT STATE` when its links went down, `Entering BACKUP STATE` when they came back, and within a few seconds `Entering MASTER STATE`; fw2's log ends with `Entering BACKUP STATE`: fw1 has the higher priority and **takes the addresses back** (preemption). That is a second switch-over, and a second short outage, that nobody asked for; many teams switch preemption off (`nopreempt` in keepalived, "preempt disabled" on firewall products) and move back by hand in a maintenance window.

**4. A session during failover, without session sync.** Stop conntrackd on both firewalls first, so the standby has no copy of the session table. Then start a long session (30 ticks, normally 15 seconds) from host-a to host-b, unplug fw1 about 3 seconds later, and read the result after about 30 seconds (each lost tick waits a second for its answer):
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'kill $(pgrep conntrackd) || true'
```
```
docker exec clab-firewall-ha-vrrp-fw2 sh -c 'kill $(pgrep conntrackd) || true'
```
```
docker exec -d clab-firewall-ha-vrrp-host-a sh -c "python3 -u /neo/scripts/session.py 10.18.2.20 7000 30 > /tmp/session.out"
```
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 down; ip link set eth2 down; ip link set eth3 down'
```
```
docker exec clab-firewall-ha-vrrp-host-a cat /tmp/session.out
```
```
docker exec clab-firewall-ha-vrrp-fw2 nft list chain ip fw forward
```
The first ticks get `ok`; from the failover on every tick says **`no reply`**, to the end, even though new pings work again after 3.5 seconds. fw2's `no session for this packet` counter has risen: host-a's retransmissions reached fw2, but fw2 never saw this session's handshake, and with strict TCP state a mid-session packet without a session is `invalid` and dropped. **The failover worked; the session did not survive it.** (Sample `ha-2-session-strict.pcapng`: ticks and answers, then only host-a's retransmissions, further and further apart.) Plug fw1 back in and wait 5 seconds:
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 up; ip link set eth2 up; ip link set eth3 up'
```

**5. Loose TCP state: fw2 adopts the session.** Let fw2 accept a TCP packet from the middle of a session as a new session, then repeat exercise 4:
```
docker exec clab-firewall-ha-vrrp-fw2 sysctl -w net.netfilter.nf_conntrack_tcp_loose=1
```
```
docker exec -d clab-firewall-ha-vrrp-host-a sh -c "python3 -u /neo/scripts/session.py 10.18.2.20 7000 30 > /tmp/session2.out"
```
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 down; ip link set eth2 down; ip link set eth3 down'
```
After about 20 seconds:
```
docker exec clab-firewall-ha-vrrp-host-a cat /tmp/session2.out
```
Two commands show the same **session table** (the list of connections the firewall or NAT router has seen). **Try `conntrack -L` first.** It talks to the kernel through a modern interface and works on every lab kernel we have tried, including newer ones (for example Linux 7.0) that do not create the file `/proc/net/nf_conntrack`. If `conntrack` is not installed, or it prints an error such as `Operation failed: invalid parameters`, use the file instead: `cat /proc/net/nf_conntrack`. Either way, each line is one session (addresses, ports, and a state such as `ESTABLISHED`). They are two windows onto the same table, not two different tables.
```
docker exec clab-firewall-ha-vrrp-fw2 conntrack -L | grep 7000
```
If `conntrack` is missing or errors, use `docker exec clab-firewall-ha-vrrp-fw2 grep 7000 /proc/net/nf_conntrack` instead. A few ticks say `no reply`, then the answers come back (several at once, as the waiting ticks catch up) and the session ends with `ok`: fw2 created a session from host-a's next retransmission and passed it (`inside -> outside` counted it as new). The gap is longer than the 3.5-second outage because TCP waits longer and longer between retransmissions. This is **pickup, not sync**: fw2 trusts a mid-session packet without having checked the handshake, and anything it never saw (a NAT translation, for example) cannot be rebuilt this way. Firewall pairs avoid both problems by copying the session table to the standby all the time (session sync, `conntrackd` on Linux), so the standby already knows every session when it takes over. (Sample `ha-3-session-loose.pcapng`.) Put fw2 back to strict, plug fw1 back in, and start session sync again:
```
docker exec clab-firewall-ha-vrrp-fw2 sysctl -w net.netfilter.nf_conntrack_tcp_loose=0
```
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 up; ip link set eth2 up; ip link set eth3 up'
```
```
docker exec clab-firewall-ha-vrrp-fw1 conntrackd -d -C /etc/neo/conntrackd.conf
```
```
docker exec clab-firewall-ha-vrrp-fw2 conntrackd -d -C /etc/neo/conntrackd.conf
```
Wait 5 seconds for fw1 to become active again.

**6. The same failover, with session sync.** Keep strict TCP state. Start a long session, check that fw2 already knows it, then unplug fw1:
```
docker exec -d clab-firewall-ha-vrrp-host-a sh -c "python3 -u /neo/scripts/session.py 10.18.2.20 7000 30 > /tmp/session3.out"
```
```
sleep 2
```
```
docker exec clab-firewall-ha-vrrp-fw1 conntrack -L | grep 7000
```
```
docker exec clab-firewall-ha-vrrp-fw2 conntrack -L | grep 7000
```
If `conntrack` is missing or errors, use `grep 7000 /proc/net/nf_conntrack` on the same firewall instead.
```
docker exec clab-firewall-ha-vrrp-fw1 sh -c 'ip link set eth1 down; ip link set eth2 down; ip link set eth3 down'
```
After about 20 seconds:
```
docker exec clab-firewall-ha-vrrp-host-a cat /tmp/session3.out
```
Both firewalls list the session on port 7000 before the unplug (fw2 has a copy from conntrackd, not from seeing the handshake itself). A few ticks may say `no reply` during the 3.5-second VRRP outage, then the answers come back and the session ends with `ok`. That is **session sync**: fw2 already knew the session when it took over, and it stayed on strict TCP state. (Sample `ha-4-session-sync.pcapng`.)

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open. ha-1, ha-2 and ha-3 were recorded on host-a:eth1 (the inside LAN). ha-4 is recorded the same way when conntrackd is running.

| File | Frames | What it shows |
|---|---|---|
| `ha-1-failover.pcapng` | 53 | fw1's gratuitous ARPs and VRRP advertisements (from 10.18.1.2, priority 150) and two pings a second; fw1 is unplugged; about 3.5 seconds of requests with no reply; fw2's gratuitous ARPs for 10.18.1.1 and its advertisements (from 10.18.1.3, priority 100); the replies come back |
| `ha-2-session-strict.pcapng` | 65 | the session's handshake, ticks and answers every half second; fw1 is unplugged; only host-a's `[TCP Retransmission]`s, further and further apart, never answered |
| `ha-3-session-loose.pcapng` | 127 | the same start; after the gap one retransmission is answered, the waiting ticks catch up, and the session goes on to the end |
| `ha-4-session-sync.pcapng` |  | session sync left running: after the short VRRP gap the ticks are answered and the session ends with `ok`. Not recorded on the build machine (the kernel has no `nf_conntrack_netlink`); record it on the NEO lab VM |

Each recording starts with fw1 repeating its gratuitous ARPs (it does that a few seconds after becoming active). Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic; the display filters `vrrp`, `icmp` and `tcp.port == 7000` show each part.

## What this lab does not do

- No commercial firewall cluster: no configuration sync and no vendor HA monitor; the lesson shows them as text. Session sync is Linux `conntrackd` over a dedicated link, not a vendor HA protocol.
- Active/passive only; no active/active, no link or path monitoring, no `nopreempt` exercise (exercise 3 explains it).
- "Unplugging" sets fw1's links down inside its container; nothing is powered off.
- No NAT (see `firewall-nat`). A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start says `http 000`.** The pair elects its active firewall about 4 seconds after the deploy: wait and try again.
2. **Both firewalls list 10.18.1.1.** Each thinks it is active (split brain): they cannot hear each other's advertisements. Check that both are plugged in (`ip -br link` on fw1 and fw2 shows `UP`) and reset the lab.
3. **Exercise 2 lost no pings.** fw1 was not the active one (an earlier exercise left fw2 active): plug fw1 back in, wait 5 seconds, and check exercise 1 again.
4. **`cat /tmp/session.out` stops in the middle.** The session is still running: in exercise 4 every lost tick waits a second, so it takes about 30 seconds.
5. **Exercise 5 behaves like exercise 4.** Check `sysctl net.netfilter.nf_conntrack_tcp_loose` on **fw2** says `1`, and that fw1 was plugged back in (and active) before you started the session.
6. **`conntrackd` is not running, or `/var/log/conntrackd.log` says `can't get kernel conntrack table`.** Session sync needs the kernel's `nf_conntrack_netlink` module (`CONFIG_NF_CT_NETLINK`). The NEO lab VM includes it. If the module is missing, exercises 1 to 5 still work; exercise 6 cannot copy the session table.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/firewall-ha-vrrp
```
```
containerlab destroy --cleanup -t firewall-ha-vrrp.clab.yml
```
`--cleanup` also removes the generated `clab-firewall-ha-vrrp` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-firewall-ha-vrrp` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/firewall-ha-vrrp/clab-firewall-ha-vrrp
```
Your capture files in your Home folder are not touched.

