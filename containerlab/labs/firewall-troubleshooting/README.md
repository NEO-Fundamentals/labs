# Lab: Did the firewall drop it? Proving it from both sides

**Folder:** `labs/firewall-troubleshooting/`  **Lab file:** `firewall-troubleshooting.clab.yml`  **Lesson:** NEO-19 Firewall troubleshooting: session lookup, logs, packet capture and flow, and proving whether the firewall dropped it  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables with connection tracking** (the NEO helper image `neo-tools`). Its counters, drop record, packet trace, kernel log lines and session table are real, and so are the captures and the server's logs. It is a Linux packet filter, **not a commercial firewall product**: vendor session browsers, traffic-log viewers and packet-capture screens are not here (the lesson shows them as text). The drop record (a counted set of dropped flows) plays the part of a firewall's traffic log.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: three Linux containers, under 40 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/firewall-troubleshooting/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab assumes you know rules, counters, `ct state` and the session table.

## What this lab builds

```
   host-a (inside client)              fw                     host-b (outside server)
   10.19.1.10  ---- eth1 10.19.1.1          10.19.2.1 eth2 ---- 10.19.2.80
                            nftables + conntrack                web :80, app :8443, web :9100,
                                                                session server :7000, nothing on :9000,
                                                                its own host firewall drops :9100
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking. **eth1 = inside** (10.19.1.1/24), **eth2 = outside** (10.19.2.1/24). Loads `configs/fw-rules.nft` at deploy | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-a | inside client 10.19.1.10/24, gateway fw | same | Attach Shell |
| host-b | outside server 10.19.2.80/24, gateway fw. Web servers on **80**, **8443** ("the app") and **9100**, each with its own access log `/var/log/web_<port>.log`; the session server `tick_server.py` on **7000** (log `/var/log/tick.log`); nothing on **9000**. Its own host firewall (`configs/host-b-rules.nft`) silently drops port **9100** | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**fw's rules** (`configs/fw-rules.nft`, chain `forward`, policy drop), top to bottom:

| Rule (comment) | Match | Verdict |
|---|---|---|
| replies of known sessions | `ct state established,related` | accept |
| no session for this packet | `ct state invalid` | drop |
| web and apps | inside to outside, `tcp dport { 80, 7000, 9000, 9100 } tcp flags syn ct state new` | accept |
| drop record | `update @drops { ip saddr . ip daddr . tcp dport }`: adds the flow to the set `drops`, with a packet counter | (none: goes on) |
| everything else | `log prefix "fw19-drop " counter` | drop |

Port 8443 is not in the list: that is the fault you will prove. fw also uses strict TCP tracking (`nf_conntrack_tcp_loose = 0`).

## Files

- `firewall-troubleshooting.clab.yml` - the lab drawing. Addresses, routes, servers and the two rule files are set by each node's `exec` lines.
- `configs/fw-rules.nft` - fw's rules (above). `configs/host-b-rules.nft` - host-b's own host firewall.
- `changes/change-1-app-8443.nft` - the fix: inserts one rule for 8443 above the drop record. `changes/trace-on.nft` and `changes/trace-off.nft` - packet tracing of host-a's packets to 8443 and of host-b's replies from 7000. Load them with `docker exec -i clab-firewall-troubleshooting-fw nft -f - < changes/<file>`.
- `scripts/session.py` and `scripts/tick_server.py` - one long TCP session: the client sends `tick N` every half second and prints the answer `ok N` (mounted on host-a and host-b as `/neo/scripts/`).
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads fw's deploy rules at the start and again at the end (this empties the drop record), and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `firewall-troubleshooting.drawio` and `firewall-troubleshooting.png` - the prepared diagram.
- `captures/` - four sample captures: `fwts-1-inside.pcapng`, `fwts-1-outside.pcapng`, `fwts-2-change.pcapng`, `fwts-3-beyond.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `firewall-troubleshooting` > right-click `firewall-troubleshooting.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80/
  ```
  It prints `http 200 in ...`: host-a reached host-b's web server on port 80 through fw.
- **Reset to the lesson start** (deploy rules, counters and drop record empty, no change):
  ```
  cd ~/labs-main/containerlab/labs/firewall-troubleshooting
  ```
  ```
  containerlab redeploy -c -t firewall-troubleshooting.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Where | Command |
|---|---|---|
| Is the server listening? | host-b | `ss -ltn` (a fifth line, on a loopback address, is Docker's name service; ignore it) |
| Does the packet reach the firewall, and does it leave? | fw, both ports at once | `tcpdump -lnni eth1 tcp port 8443` and `tcpdump -lnni eth2 tcp port 8443` |
| Which rule counted it? | fw | `nft list chain ip fw forward` |
| Which flows were dropped? (the drop record) | fw | `nft list set ip fw drops` |
| Which rule decided, packet by packet? | fw | load `changes/trace-on.nft`, then `nft monitor trace` |
| The firewall's log lines | the VM | `sudo dmesg \| grep fw19-drop` (needs the setting in exercise 3) |
| Is there a session? | fw | `conntrack -L | grep <port>` (or `grep <port> /proc/net/nf_conntrack`); count the lines, or `cat /proc/sys/net/netfilter/nf_conntrack_count` if that file exists |
| Did the request reach the server? | host-b | `cat /var/log/web_8443.log` (also `web_80`, `web_9100`, `tick.log`) |
| Is the server itself filtering? | host-b | `nft list table ip host` |

The web test prints the HTTP status and the time: `http 200` is a page; **`http 000 in 3.0 s`** is no answer within the 3-second limit (curl exit code 28): something **dropped** the packets; **`http 000 in 0.000... s`** is an immediate refusal (exit code 7): something **answered** with a reset.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-troubleshooting`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The symptom.**
```
docker exec clab-firewall-troubleshooting-host-b ss -ltn
```
```
docker exec clab-firewall-troubleshooting-host-a ip route
```
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80/
```
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:8443/
```
host-b listens on 80, 8443, 9100 and 7000; host-a's default route is fw (`default via 10.19.1.1`). Port 80 works (`http 200`); **the app on 8443 times out** (`http 000 in 3.0 s`). Same server, same path: something between them treats 8443 differently.

**2. Capture on both sides of the firewall.** Open two more windows and start one capture in each (they stop by themselves after 20 seconds):
```
docker exec clab-firewall-troubleshooting-fw timeout 20 tcpdump -lnni eth1 tcp port 8443
```
```
docker exec clab-firewall-troubleshooting-fw timeout 20 tcpdump -lnni eth2 tcp port 8443
```
Then in the first window:
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:8443/
```
Inside (eth1): `IP 10.19.1.10.<port> > 10.19.2.80.8443: Flags [S]` three times, about one second apart. Outside (eth2): **`0 packets captured`**. The packet reached the firewall and did not leave it. (Samples `fwts-1-inside.pcapng` and `fwts-1-outside.pcapng`, recorded at the same time: the outside one has no TCP at all.)

**3. The firewall's own evidence.**
```
docker exec clab-firewall-troubleshooting-fw nft list chain ip fw forward
```
```
docker exec clab-firewall-troubleshooting-fw nft list set ip fw drops
```
The rule `everything else` counted **6** packets (the six SYNs of exercises 1 and 2), and the drop record holds one flow: `10.19.1.10 . 10.19.2.80 . 8443 counter packets 6`. Now trace one more attempt:
```
docker exec -i clab-firewall-troubleshooting-fw nft -f - < changes/trace-on.nft
```
In a second window (it stops by itself after 30 seconds):
```
docker exec -it clab-firewall-troubleshooting-fw sh -c "timeout 30 nft monitor trace | grep --line-buffered -E 'ip fw forward (rule|policy)'"
```
In the first window, the same curl to 8443 again. Each SYN prints `... comment "drop record" (verdict continue)` and then `log prefix "fw19-drop " counter ... drop comment "everything else" (verdict drop)`: rule, packet and verdict.

**The log lines (optional).** Linux hides log lines from containers unless the VM allows them. Allow them, try once more, read, and switch it back off:
```
sudo sysctl -w net.netfilter.nf_log_all_netns=1
```
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:8443/
```
```
sudo dmesg | grep fw19-drop | tail -3
```
```
sudo sysctl -w net.netfilter.nf_log_all_netns=0
```
Three lines like `fw19-drop IN=eth1 OUT=eth2 ... SRC=10.19.1.10 DST=10.19.2.80 ... PROTO=TCP SPT=... DPT=8443 ... SYN`: what a firewall's traffic log shows for a denied flow. The setting is for the whole VM; the last command puts it back.

**4. Session lookup.** Start a long session (30 ticks, 15 seconds) from host-a to host-b's session server, then look it up on fw while it runs. Tracing is still on, so the trace window (start it again if it has stopped) also shows host-b's replies:
```
docker exec -d clab-firewall-troubleshooting-host-a sh -c "python3 /neo/scripts/session.py 10.19.2.80 7000 30 > /tmp/session.out"
```
Two commands show the same **session table** (the list of connections the firewall or NAT router has seen). **Try `conntrack -L` first.** It talks to the kernel through a modern interface and works on every lab kernel we have tried, including newer ones (for example Linux 7.0) that do not create the file `/proc/net/nf_conntrack`. If `conntrack` is not installed, or it prints an error such as `Operation failed: invalid parameters`, use the file instead: `cat /proc/net/nf_conntrack`. Either way, each line is one session (addresses, ports, and a state such as `ESTABLISHED`). They are two windows onto the same table, not two different tables.
```
docker exec clab-firewall-troubleshooting-fw conntrack -L | grep 7000
```
```
docker exec clab-firewall-troubleshooting-fw conntrack -L | grep 8443
```
If `conntrack` is missing or errors, use `docker exec clab-firewall-troubleshooting-fw grep 7000 /proc/net/nf_conntrack` (and the same for 8443) instead. The 7000 session is there: `ESTABLISHED src=10.19.1.10 dst=10.19.2.80 sport=P dport=7000 src=10.19.2.80 dst=10.19.1.10 sport=7000 dport=P [ASSURED]`, and its replies match `ct state established,related ... comment "replies of known sessions" (verdict accept)` in the trace. **8443 finds nothing** (grep exit code 1): a SYN that the rules drop never becomes a session. After 15 seconds:
```
docker exec clab-firewall-troubleshooting-host-a tail -n 3 /tmp/session.out
```
`tick 30: ok 30`: the session completed. Switch tracing off:
```
docker exec -i clab-firewall-troubleshooting-fw nft -f - < changes/trace-off.nft
```

**5. The change, and the proof that it worked.** Add one rule for the app, above the drop record:
```
docker exec -i clab-firewall-troubleshooting-fw nft -f - < changes/change-1-app-8443.nft
```
```
docker exec clab-firewall-troubleshooting-fw nft list chain ip fw forward
```
The new rule `change 1: app on 8443` sits fourth, with `counter packets 0`. Start the two captures again (exercise 2), then:
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:8443/
```
```
docker exec clab-firewall-troubleshooting-host-b cat /var/log/web_8443.log
```
`http 200`. Both captures now show the whole connection (SYN, SYN-ACK, ACK, request, answer, close). host-b's 8443 log has **exactly one line**, `10.19.1.10 - - [...] "GET / HTTP/1.1" 200 -`: none of the earlier attempts ever reached the server. The new rule counted 1; `everything else` did not rise. (Sample `fwts-2-change.pcapng`.)

**6. When it is not the firewall.** Capture on eth2 (outside) again, ports 9000 and 9100:
```
docker exec clab-firewall-troubleshooting-fw timeout 20 tcpdump -lnni eth2 tcp port 9000 or tcp port 9100
```
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:9000/
```
```
docker exec clab-firewall-troubleshooting-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.19.2.80:9100/
```
```
docker exec clab-firewall-troubleshooting-fw nft list chain ip fw forward
```
```
docker exec clab-firewall-troubleshooting-host-b nft list table ip host
```
```
docker exec clab-firewall-troubleshooting-host-b cat /var/log/web_9100.log
```
- **9000:** `http 000 in 0.000... s` (exit 7). The capture shows the SYN **leaving** fw and host-b answering `Flags [R.]` (reset): fw passed it; the server refused it because nothing listens.
- **9100:** `http 000 in 3.0 s`. The capture shows the SYN leaving fw three times and no answer. fw's `web and apps` counter rose by 4 (one 9000 SYN, three 9100 SYNs) and `everything else` did **not** change. host-b's host firewall counted `packets 3`, and host-b's 9100 log is empty. fw passed it; something **beyond** fw dropped it.

(Sample `fwts-3-beyond.pcapng`: the 9000 SYN and its reset, then three 9100 SYNs.) The method: capture on both sides, read the counters and the drop record, look up the session, then check the server's own log and filter before blaming the firewall.

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `fwts-1-inside.pcapng` | fw:eth1 (inside) | 7 | host-a's SYN to 10.19.2.80:8443 and two retries; an ARP exchange between them |
| `fwts-1-outside.pcapng` | fw:eth2 (outside) | 4 | recorded at the same time: **no TCP at all**; only an ARP exchange between fw and host-b |
| `fwts-2-change.pcapng` | fw:eth2 (outside) | 12 | after the change: the whole connection to 8443 (handshake, GET, 200 OK, close) |
| `fwts-3-beyond.pcapng` | fw:eth2 (outside) | 5 | port 9000: SYN and host-b's `RST, ACK`; port 9100: three SYNs, no answer |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic and other ARP exchanges; the display filter `tcp` shows only the connections.

## What this lab does not do

- No commercial firewall: no session browser, traffic-log viewer or built-in packet capture with stage filters; the lesson shows vendor screens as text. Here the same questions are answered with `tcpdump`, counters, a drop record, `nft monitor trace` and the session table (`conntrack -L`, or `/proc/net/nf_conntrack` if that file exists).
- The kernel log needs the VM setting in exercise 3; there is no log server and no log search.
- One firewall, one path; no NAT (see `firewall-nat`) and no asymmetric routing.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the servers start after the addresses).
2. **8443 already works in exercise 1.** The change is still loaded from an earlier run: reset the lab.
3. **`nft -f` says `No such file or directory`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-troubleshooting`) so that `changes/...` is found.
4. **The trace prints nothing.** Load `changes/trace-on.nft` first, and send traffic within the 30 seconds the trace runs.
5. **`conntrack -L | grep 7000` (or `grep 7000 /proc/net/nf_conntrack`) finds nothing.** The session lasts 15 seconds; start it again and look it up at once.
6. **`sudo dmesg | grep fw19-drop` prints nothing.** Check that `sudo sysctl net.netfilter.nf_log_all_netns` says `1` **before** you send the traffic.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/firewall-troubleshooting
```
```
containerlab destroy --cleanup -t firewall-troubleshooting.clab.yml
```
`--cleanup` also removes the generated `clab-firewall-troubleshooting` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-firewall-troubleshooting` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/firewall-troubleshooting/clab-firewall-troubleshooting
```
Your capture files in your Home folder are not touched.

