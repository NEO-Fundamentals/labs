# Lab: private and public addresses, and the NAT that joins them

**Folder:** `labs/private-public-nat/`  **Lab file:** `private-public-nat.clab.yml`  **Lesson:** NEO-46 IP Address Space: Public, Private, and Reserved Ranges  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs a real FRR router as a stand-in Internet provider (isp), two Linux routers with the Linux firewall nftables (rtr-a and rtr-b) and two Linux hosts. **There is no Arista EOS, Juniper Junos or Cisco device in this lab, and it never touches the real Internet.**

**One thing to know first.** A lab must not use real public addresses. So in this lab, **192.168.200.0/24 plays the role of public Internet addresses**, and the 10.46.x networks are the private ones. 192.168.200.0/24 is really a private range too (RFC 1918); the lab only pretends it is public, the way a stage set pretends to be a street.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/private-public-nat/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB on disk) and `ghcr.io/neo-fundamentals/neo-tools:1.0.0` (about 260 MB). After that the lab works offline. Keep at least 1 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute. Then wait 10 to 20 seconds: FRR (isp) loads its addresses after the containers start. Do not trust a ping until the check in **Start** passes.

## What this lab builds

```
   site A (private)                 "the Internet"                    site B (private)
 host-a ------- rtr-a ---------------- isp ---------------- rtr-b ------- host-b
 10.46.1.10     10.46.1.1    192.168.200.2 | 192.168.200.6    10.46.2.1     10.46.2.10
                             (rtr-a's "public")   (rtr-b's "public")        web server
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux host 10.46.1.10/24 at site A, gateway rtr-a (10.46.1.1). Has `ping` and `curl` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| rtr-a | Site A's Linux router: 10.46.1.1/24 inside (eth1), "public" 192.168.200.2/30 outside (eth2), default route to isp. No NAT until exercise 3 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| isp | The stand-in provider (FRR): 192.168.200.1/30 (eth1, to rtr-a) and 192.168.200.5/30 (eth2, to rtr-b). It knows only those two links, has **no route to any 10.x network**, and **drops every packet that comes from a 10.x address** | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell (opens `vtysh`) |
| rtr-b | Site B's Linux router: "public" 192.168.200.6/30 outside (eth1), 10.46.2.1/24 inside (eth2), default route to isp. No NAT until exercise 5 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| host-b | Linux host 10.46.2.10/24 at site B, gateway rtr-b, with a small web server on port 80 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `private-public-nat.clab.yml` - the lab drawing. The isp's "drop everything from 10.x" rule is one line in it (`ip rule add from 10.0.0.0/8 blackhole`).
- `configs/isp-frr.conf` - the isp's two interfaces. No routes: that is the point.
- `changes/` - the NAT rules you add and remove during the exercises, as nftables files: `rtr-a-snat-on.nft` and `rtr-a-snat-off.nft` (source NAT on rtr-a), `rtr-b-port-forward-on.nft` and `rtr-b-port-forward-off.nft` (a port forward on rtr-b). Open them: each is a few lines with comments.
- `scripts/make-captures.sh` - re-records the sample captures. The lab must be running. Run it with `sudo bash scripts/make-captures.sh` from the lab folder; it waits up to 90 seconds for the isp, removes any NAT rules you added, takes about one minute, removes the rules again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `private-public-nat.drawio` and `private-public-nat.png` - the prepared diagram.
- `captures/` - four sample captures, recorded from this lab: `nat-1-private-dropped.pcapng`, `nat-2-snat.pcapng`, `nat-3-private-destination.pcapng`, `nat-4-port-forward.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `private-public-nat` > right-click `private-public-nat.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal** that rtr-a reaches the isp:
  ```
  docker exec clab-private-public-nat-rtr-a ping -c 2 192.168.200.1
  ```
  Two replies means the isp has its addresses. If it says 100% packet loss, wait 20 seconds and run it again.
- **Reset to the lesson start** (no NAT anywhere):
  ```
  cd ~/labs-main/containerlab/labs/private-public-nat
  ```
  ```
  containerlab redeploy -c -t private-public-nat.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The ranges, and the commands

The private ranges (RFC 1918) are 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16. Anyone may use them inside their own network, so the same private address exists in thousands of places at once, and Internet providers do not route or accept them. This lab's isp does the same. The lesson video covers the other reserved ranges (loopback, link-local, shared and documentation ranges); the lab itself uses only private addresses, by design.

| Task | Linux router (rtr-a, rtr-b) | Linux host | FRR (isp) |
|---|---|---|---|
| Show addresses and routes | `ip -4 addr`, `ip route` | `ip -4 addr`, `ip route` | `show ip route` (in `vtysh`) |
| Add or remove NAT rules | `nft -f <file>` (fed from `changes/`) | - | - |
| Show the NAT rules | `nft list table ip neo_snat` (rtr-a), `nft list table ip neo_dnat` (rtr-b) | - | - |
| Show NAT translations | `conntrack -L` (or `cat /proc/net/nf_conntrack`) | - | - |
| Show the drop rule | - | - | `ip rule` (in a shell: `docker exec clab-private-public-nat-isp ip rule`) |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name. Run them from the lab folder (`cd ~/labs-main/containerlab/labs/private-public-nat`), because exercises 3 and 5 read files from `changes/`.

**1. Private addresses are not routed on the Internet.** Read the isp's routing table:
```
docker exec clab-private-public-nat-isp vtysh -c "show ip route"
```
The `C>*` lines are the isp's connected networks: 192.168.200.0/30, 192.168.200.4/30 and the management network 172.20.20.0/24 on eth0 (Containerlab's own; ignore it). FRR also lists `L>*` lines, one for each of its own addresses. There is no 10.46.1.0/24 and no 10.46.2.0/24: nobody on the Internet has a route to your private network. Now try to reach host-b's private address from host-a:
```
docker exec clab-private-public-nat-host-a ping -c 3 -W 1 10.46.2.10
```
`100% packet loss`. rtr-a sends the packet to the isp (its default route), and the isp throws it away.

**2. Even a "public" destination fails from a private source.** rtr-b's outside address 192.168.200.6 is a "public" one. Try it:
```
docker exec clab-private-public-nat-host-a ping -c 3 -W 1 192.168.200.6
```
Still `100% packet loss`. To see why, capture on rtr-a's outside cable while you ping. In Ubuntu's Terminal app start the capture first (8 seconds), then run the ping again in VS Code's terminal:
```
sudo containerlab capture --name private-public-nat --target rtr-a:eth2 --duration 8s -w - > "$HOME/neo-nat-1.pcapng"
```
The sample `captures/nat-1-private-dropped.pcapng` shows it: three Echo requests (frames 4 to 6) leave rtr-a with the source **10.46.1.10**, a private address, and no reply comes back. The isp drops packets from 10.x (`docker exec clab-private-public-nat-isp ip rule` shows the rule `from 10.0.0.0/8 blackhole`). And even if it delivered them, rtr-b could not answer: it has no route back to 10.46.1.10 either.

**3. Source NAT on rtr-a.** Give rtr-a a rule that replaces the private source address with its own public one on the way out:
```
docker exec -i clab-private-public-nat-rtr-a nft -f - < changes/rtr-a-snat-on.nft
```
```
docker exec clab-private-public-nat-rtr-a nft list table ip neo_snat
```
The rule reads `oifname "eth2" ip saddr 10.46.1.0/24 masquerade`: packets from site A that leave on eth2 get rtr-a's own address there. Ping again:
```
docker exec clab-private-public-nat-host-a ping -c 3 -W 1 192.168.200.6
```
Three replies. Capture both of rtr-a's cables at once to see the change (start the capture first, then ping):
```
sudo containerlab capture --name private-public-nat --target rtr-a:eth1,eth2 --duration 8s -w - > "$HOME/neo-nat-2.pcapng"
```
In the sample `captures/nat-2-snat.pcapng` every ping appears twice. Inside (`rtr-a:eth1`, frame 4) it goes from 10.46.1.10 to 192.168.200.6. Outside (`rtr-a:eth2`, frame 5) the same request goes from **192.168.200.2**. The reply comes back to 192.168.200.2 (frame 6), and rtr-a sends it on to 10.46.1.10 (frame 7). rtr-a remembers each translation. Two commands show the same **session table** (the list of connections the firewall or NAT router has seen). **Try `conntrack -L` first.** It talks to the kernel through a modern interface and works on every lab kernel we have tried, including newer ones (for example Linux 7.0) that do not create the file `/proc/net/nf_conntrack`. If `conntrack` is not installed, or it prints an error such as `Operation failed: invalid parameters`, use the file instead: `cat /proc/net/nf_conntrack`. Either way, each line is one session (addresses, ports, and a state such as `ESTABLISHED`). They are two windows onto the same table, not two different tables.
```
docker exec clab-private-public-nat-rtr-a conntrack -L
```
If that command is missing or errors, use `docker exec clab-private-public-nat-rtr-a cat /proc/net/nf_conntrack` instead. Each line shows the original direction (`src=10.46.1.10 dst=192.168.200.6`) and the reply direction (`src=192.168.200.6 dst=192.168.200.2`): that pair is the translation.

**4. NAT does not make private addresses reachable.** With source NAT still on, ping host-b's private address again:
```
docker exec clab-private-public-nat-host-a ping -c 2 -W 1 10.46.2.10
```
Now the isp answers: `From 192.168.200.1 icmp_seq=1 Destination Net Unreachable`. The packet's source is public now, so the isp no longer drops it, but the isp has no route to 10.46.2.10 and says so. The sample `captures/nat-3-private-destination.pcapng` shows the request leaving as 192.168.200.2 (frame 4), the isp's ICMP **Network unreachable** (frame 5), and rtr-a passing it back to host-a (frame 6).

**5. A port forward on rtr-b.** host-b's web server is private. From outside, ask rtr-b's public address for the page:
```
docker exec clab-private-public-nat-host-a curl -sS -m 3 http://192.168.200.6/
```
It fails with `Couldn't connect to server`: nothing on rtr-b itself listens on port 80. Add a destination NAT rule (a "port forward") on rtr-b:
```
docker exec -i clab-private-public-nat-rtr-b nft -f - < changes/rtr-b-port-forward-on.nft
```
```
docker exec clab-private-public-nat-host-a curl -sS -m 3 http://192.168.200.6/
```
It prints `hello from host-b (10.46.2.10)`. Who does host-b think asked?
```
docker exec clab-private-public-nat-host-b cat /var/log/web.log
```
The line starts with `192.168.200.2`: rtr-a's public address, not host-a's 10.46.1.10. Both NATs are visible here: rtr-a changed the source, rtr-b changed the destination. The sample `captures/nat-4-port-forward.pcapng` was recorded on both of rtr-b's cables (`rtr-b:eth1,eth2`): outside, the SYN goes to 192.168.200.6 (frame 3); inside, the same SYN goes to **10.46.2.10** (frame 6); the answers come back the other way.

**6. Take the NAT away again.**
```
docker exec -i clab-private-public-nat-rtr-b nft -f - < changes/rtr-b-port-forward-off.nft
```
```
docker exec -i clab-private-public-nat-rtr-a nft -f - < changes/rtr-a-snat-off.nft
```
The ping from exercise 2 fails again. NAT is the only thing that lets a private network talk to the Internet.

## Sample captures

All are cut to 200 bytes per packet (the web page in `nat-4` is cut too). Open them in Wireshark with File > Open. The interface name of each frame (for example `rtr-a:eth2`) is in the frame details.

| File | Frames | Cables | What it shows |
|---|---|---|---|
| `nat-1-private-dropped.pcapng` | 6 | rtr-a:eth2 | No NAT: three pings leave with the private source 10.46.1.10; no reply (frames 1 to 3 are an IPv6 router solicitation and ARP) |
| `nat-2-snat.pcapng` | 15 | rtr-a:eth1 and eth2 | Source NAT: each ping inside from 10.46.1.10, outside from 192.168.200.2, and the replies the other way |
| `nat-3-private-destination.pcapng` | 11 | rtr-a:eth1 and eth2 | Ping to 10.46.2.10 with source NAT on: the isp answers Network unreachable |
| `nat-4-port-forward.pcapng` | 29 | rtr-b:eth1 and eth2 | Port forward: one web request, outside to 192.168.200.6, inside to 10.46.2.10 |

## What this lab does not do

- No real public addresses and no real Internet (see "One thing to know first").
- No IPv6. IPv6 has its own private-style range (ULA, fd00::/8), and IPv6 networks usually do not use NAT.
- No carrier-grade NAT (NAT inside the provider) and no NAT on the isp; one NAT router per site.
- The isp is one FRR router with two links and a drop rule, not a provider network.

## Troubleshooting

1. **The ping in exercise 3 still fails after you added the rule.** Run `docker exec clab-private-public-nat-rtr-a nft list table ip neo_snat`. If it prints `Error: No such file or directory` instead of the table, the file did not apply: feed it with `-i` so Docker passes the file in (`docker exec -i ... nft -f - < changes/rtr-a-snat-on.nft`), and run the command from the lab folder.
2. **An `-off.nft` file prints `Error: Could not process rule: No such file or directory`.** The rule was not there (already removed, or never added). Nothing to do.
3. **The rule appears twice in `nft list table ...`.** You applied the same `-on.nft` file twice; nftables accepts that without an error. It still works, but to keep it tidy remove it with the matching `-off.nft` file and apply it once.
4. **`curl` in exercise 5 still says `Couldn't connect to server`.** The port forward is not on rtr-b (see 1, on rtr-b), or host-b's web server stopped: `docker exec clab-private-public-nat-host-b pgrep -a python3` must print one line. A redeploy starts it again.
5. **Everything fails, even the check in Start.** FRR needs 10 to 20 seconds to load the isp's addresses after Deploy. Wait and try again. Run `docker exec clab-private-public-nat-isp vtysh -c "show ip route"`: both 192.168.200.x links must be there.
6. **The capture is empty.** Start the capture first and wait a few seconds, then run the ping. Check the cable: rtr-a's outside is `rtr-a:eth2`, its inside `rtr-a:eth1`; rtr-b's outside is `rtr-b:eth1`, its inside `rtr-b:eth2`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/private-public-nat
```
```
containerlab destroy --cleanup -t private-public-nat.clab.yml
```
`--cleanup` also removes the generated `clab-private-public-nat` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-private-public-nat` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/private-public-nat/clab-private-public-nat
```
Your capture files in your Home folder are not touched.
