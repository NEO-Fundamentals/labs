# Lab: Firewall zones, default deny and the session table

**Folder:** `labs/firewall-zones/`  **Lab file:** `firewall-zones.clab.yml`  **Lesson:** NEO-13 Firewall fundamentals: stateful inspection, the session table, zones, and default deny  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables with connection tracking** (the NEO helper image `neo-tools`). Its stateful rules, session table, counters and packet trace are real. It is a Linux packet filter, **not a commercial firewall product**: there is no Palo Alto, Fortinet, Cisco or Juniper firewall here, and their syntax differs (the lesson shows it as text). The three hosts are small Linux containers with Python web servers.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: four Linux containers, about 11 MB each (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/firewall-zones/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
   host-a (inside)                fw                  host-b (outside)
   10.13.1.10  ---- eth1 10.13.1.1    10.13.2.1 eth2 ---- 10.13.2.20
   web :8080                nftables + conntrack          web :80  (plays the Internet)
                           10.13.3.1 eth3
                                 |
                           host-c (dmz)
                           10.13.3.30, web :80
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking. **eth1 = inside zone** (10.13.1.1/24), **eth2 = outside zone** (10.13.2.1/24), **eth3 = dmz** (10.13.3.1/24). Loads `configs/fw-zones.nft` at deploy | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-a | inside host 10.13.1.10/24, gateway fw; web server on **port 8080** | same | Attach Shell |
| host-b | outside host 10.13.2.20/24 (and 10.13.2.21, used only by the probe in exercise 6), gateway fw; web server on port 80 | same | Attach Shell |
| host-c | dmz server 10.13.3.30/24, gateway fw; web server on port 80 | same | Attach Shell |

All addresses are private (RFC 1918). The outside zone **plays** the Internet; the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The zone policy** (`configs/fw-zones.nft`), read top to bottom; the first rule that matches decides:

| # | Rule | Meaning |
|---|---|---|
| 1 | `ct state established,related accept` | replies and follow-ups of a connection that was already allowed |
| 2 | `ct state invalid drop` | packets that belong to no known connection |
| 3 | `iifname "eth1" oifname "eth2" ct state new accept` | inside may start connections to outside |
| 4 | `oifname "eth3" tcp dport 80 ct state new accept` | any zone may start a web connection to the dmz server |
| 5 | `counter` + chain `policy drop` | **default deny**: everything else is counted, then dropped |

The firewall rules only touch traffic that **passes through** fw (the `forward` hook); the hosts and fw themselves are not filtered.

## Files

- `firewall-zones.clab.yml` - the lab drawing. Addresses, routes and web servers are set by each node's `exec` lines.
- `configs/fw-zones.nft` - the stateful zone policy that fw loads at deploy.
- `changes/` - the exercise policies, loaded with `docker exec -i clab-firewall-zones-fw nft -f - < changes/<file>`: `fw-open.nft` (no filtering), `fw-default-deny.nft` (deny only), `fw-zones.nft` (back to the zone policy), `fw-stateless.nft` (the stateless mistake), `trace-on.nft` and `trace-off.nft` (packet tracing). Each file replaces the table `inet fw` as a whole.
- `scripts/sport80-probe.py` - used in exercise 6 on host-b (it is mounted there as `/neo/scripts/sport80-probe.py`): opens a new connection to host-a:8080 from **source port 80**.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads the zone policy again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `firewall-zones.drawio` and `firewall-zones.png` - the prepared diagram.
- `captures/` - three sample captures: `fw-1-default-deny.pcapng`, `fw-2-stateful-zones.pcapng`, `fw-3-stateless-hole.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `firewall-zones` > right-click `firewall-zones.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.2.20/
  ```
  It prints `http 200 in ...`: host-a (inside) reached host-b's web page (outside) through fw.
- **Reset to the lesson start** (zone policy, counters at zero):
  ```
  cd ~/labs-main/containerlab/labs/firewall-zones
  ```
  ```
  containerlab redeploy -c -t firewall-zones.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | On fw (Linux, nftables) |
|---|---|
| The policy, with a counter per rule | `nft list table inet fw` |
| Load a policy from a file | `nft -f <file>` (here: `docker exec -i clab-firewall-zones-fw nft -f - < changes/<file>`) |
| The session table (connection tracking) | `conntrack -L` (or `cat /proc/net/nf_conntrack`) |
| Number of sessions | count the lines of `conntrack -L`, or `cat /proc/sys/net/netfilter/nf_conntrack_count` if that file exists |
| Which rule decided each packet | load `changes/trace-on.nft`, then `nft monitor trace` |
| Packets on a zone port, live | `tcpdump -ni eth1 tcp` |
| Wireshark filter | `tcp.port == 80 or tcp.port == 8080` |

`nft list ruleset` also shows a table `ip nat` with a warning: that table belongs to Docker (it makes name lookups work inside the container). Leave it alone; this lab's rules are all in `inet fw`.

The web test used in every exercise prints the HTTP status and the time: `http 200` is a page, **`http 000` is no answer** (here: after the 3-second limit).

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-zones`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. No firewall: fw is only a router.**
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/fw-open.nft
```
```
docker exec clab-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.1.10:8080/
```
```
docker exec clab-firewall-zones-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.1.10:8080/
```
Both `http 200`: the outside host and the dmz server reach the inside host. A router forwards everything it has a route for.

**2. Default deny.**
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/fw-default-deny.nft
```
```
docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.2.20/
```
`http 000 in 3.0 s`: nothing passes, not even inside to outside. Look at the counter:
```
docker exec clab-firewall-zones-fw nft list table inet fw
```
`counter packets 3 ... comment "default deny"`: host-a's SYN and its two retries (one second apart), each counted and dropped. Nothing is sent back, so host-a waits until it gives up. (Sample `fw-1-default-deny.pcapng`: three SYNs on the inside port, no answer.)

**3. Zones and state (the zone policy).**
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/fw-zones.nft
```
Now test each direction:
```
docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.2.20/
```
```
docker exec clab-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.3.30/
```
```
docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.3.30/
```
```
docker exec clab-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.1.10:8080/
```
```
docker exec clab-firewall-zones-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.1.10:8080/
```
`200`, `200`, `200`, then `000` and `000`. Inside reaches outside (rule 3), anyone reaches the dmz web server (rule 4), and nobody starts a connection **into** the inside zone. Now `nft list table inet fw` again: rule 3 counted **1** packet, rule 4 counted **2**, but rule 1 (established) counted about 30: each allowed connection needs only its first packet (the SYN) checked against the zone rules; every later packet, in both directions, matches the session. The default-deny counter rose by 6 (two blocked connections, three SYNs each).

**4. The session table.** Hold a connection open from host-a to host-b for 30 seconds and read fw's table:
```
docker exec -d clab-firewall-zones-host-a sh -c "sleep 30 | nc 10.13.2.20 80"
```
Two commands show the same **session table** (the list of connections the firewall or NAT router has seen). **Try `conntrack -L` first.** It talks to the kernel through a modern interface and works on every lab kernel we have tried, including newer ones (for example Linux 7.0) that do not create the file `/proc/net/nf_conntrack`. If `conntrack` is not installed, or it prints an error such as `Operation failed: invalid parameters`, use the file instead: `cat /proc/net/nf_conntrack`. Either way, each line is one session (addresses, ports, and a state such as `ESTABLISHED`). They are two windows onto the same table, not two different tables.
```
docker exec clab-firewall-zones-fw conntrack -L
```
If that command is missing or errors, use `docker exec clab-firewall-zones-fw cat /proc/net/nf_conntrack` instead. One line says `ESTABLISHED src=10.13.1.10 dst=10.13.2.20 sport=... dport=80 src=10.13.2.20 dst=10.13.1.10 sport=80 dport=...`: the session, with both directions (the second half is what a reply must look like). The other lines are the earlier connections, now `TIME_WAIT`; they expire after two minutes. Count the lines, or read `cat /proc/sys/net/netfilter/nf_conntrack_count` if that file exists on your kernel.

**5. Which rule decided? A packet trace.**
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/trace-on.nft
```
Start the trace in a second terminal. It shows only the lines that name a rule or the policy, and stops by itself after 30 seconds:
```
docker exec -it clab-firewall-zones-fw sh -c "timeout 30 nft monitor trace | grep --line-buffered -E 'inet fw forward (rule|policy)'"
```
In the first terminal:
```
docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.2.20/
```
```
docker exec clab-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.1.10:8080/
```
host-a's first packet is accepted by `... ct state new ... comment "inside -> outside" (verdict accept)`; every later packet of that connection by `ct state established,related ... (verdict accept)`. host-b's SYN to host-a goes through `comment "default deny" (verdict continue)` and then `policy drop`, three times. When the trace has stopped, switch tracing off:
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/trace-off.nft
```

**6. The stateless mistake (the lesson's warning).** A policy without state has to let replies in by port. This one allows requests out to port 80 and "anything from port 80" back in:
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/fw-stateless.nft
```
```
docker exec clab-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.13.2.20/
```
`http 200`: it seems to work. But the sender chooses its source port. From the outside, open a **new** connection to host-a, using source port 80:
```
docker exec clab-firewall-zones-host-b python3 /neo/scripts/sport80-probe.py
```
`NEW connection from source port 80 got through; reply: HTTP/1.0 200 OK`: the outside reached the inside web server. Load the zone policy again and repeat:
```
docker exec -i clab-firewall-zones-fw nft -f - < changes/fw-zones.nft
```
```
docker exec clab-firewall-zones-host-b python3 /neo/scripts/sport80-probe.py
```
`no connection (blocked): timed out`. The stateful firewall knows this SYN starts a new connection from outside, whatever its source port. host-a's own web access (`http 200`) still works.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `fw-1-default-deny.pcapng` | fw:eth1 (inside) | 3 | default deny only: host-a's SYN to 10.13.2.20:80 and its two retries, one second apart; nothing comes back |
| `fw-2-stateful-zones.pcapng` | fw:eth2 (outside) | 15 | the zone policy: host-a's whole web request to host-b (handshake, GET, 200 OK, close), then host-b's SYN to 10.13.1.10:8080 and two retries, which get no answer |
| `fw-3-stateless-hole.pcapng` | fw:eth1 (inside) | 11 | the stateless policy: a new connection from 10.13.2.21 **source port 80** to host-a:8080 arrives inside, completes its handshake and gets the page |

Run right after a deploy, `make-captures.sh` also records the containers' IPv6 start-up traffic (router solicitations, multicast listener reports) and an ARP exchange (box re-run on a fresh deploy: 15 / 17 / 12 frames). The display filter `ip` hides them.

## What this lab does not do

- No commercial firewall: no application identification, user identity, URL filtering or TLS inspection (later lessons), and no vendor syntax. The lesson shows other vendors' commands as text.
- No NAT (see `private-public-nat`) and no IPv6 rules: the lab uses IPv4 only.
- Rules are loaded from files; there is no management GUI.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the web servers start after the addresses). Check that the zone policy is loaded: `docker exec clab-firewall-zones-fw nft list table inet fw` shows five rules. If you loaded another policy, load `changes/fw-zones.nft` again or reset the lab.
2. **`nft -f` says `No such file or directory`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-zones`) so that `changes/...` is found.
3. **`trace-off.nft` says `Error: Could not process rule: No such file or directory`.** Tracing was not on; nothing to do.
4. **The trace prints nothing.** Load `changes/trace-on.nft` first, and send traffic within the 30 seconds the trace runs.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/firewall-zones
```
```
containerlab destroy --cleanup -t firewall-zones.clab.yml
```
`--cleanup` also removes the generated `clab-firewall-zones` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-firewall-zones` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/firewall-zones/clab-firewall-zones
```
Your capture files in your Home folder are not touched.
