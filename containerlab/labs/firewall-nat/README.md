# Lab: NAT on a firewall: source NAT, port forwarding, NAT and the filter, hairpin

**Folder:** `labs/firewall-nat/`  **Lab file:** `firewall-nat.clab.yml`  **Lesson:** NEO-15 NAT on firewalls: source NAT, destination NAT and port forwarding, and how NAT and policy evaluation interact  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables NAT and filtering with connection tracking** (the NEO helper image `neo-tools`). The translations, the session table with both sides of each translation, the counters and the packet trace are real. It is a Linux packet filter, **not a commercial firewall product**: there is no Palo Alto, Fortinet, Cisco or Juniper firewall here, and their NAT policy screens and syntax differ (the lesson shows them as text). The inside switch `sw` is a plain Linux bridge.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: six Linux containers, about 11 MB each or less (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/firewall-nat/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and `ghcr.io/srl-labs/network-multitool:v0.10.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab assumes you know zones, default deny and `ct state`.

## What this lab builds

```
   host-a 10.15.1.10 --+
                       sw ---- eth1 10.15.1.1   fw   10.15.2.1 eth2 ---- host-b 10.15.2.20
   host-d 10.15.1.40 --+       (inside)    nftables NAT   ("public")     web :80, NO default route
   web :8080                                10.15.3.1 eth3               (plays an Internet server)
                                                 |
                                           host-c (dmz) 10.15.3.30, web :80
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking. **eth1 = inside** (10.15.1.1/24), **eth2 = outside** (10.15.2.1/24: this address **plays the firewall's public address**), **eth3 = dmz** (10.15.3.1/24). Loads `configs/fw-start.nft` at deploy: **no NAT and no filtering** | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| sw | the inside switch: a Linux bridge `br0` joining fw, host-a and host-d | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Attach Shell |
| host-a | inside client 10.15.1.10/24, gateway fw | neo-tools | Attach Shell |
| host-d | inside server 10.15.1.40/24, gateway fw; web server on **port 8080** | neo-tools | Attach Shell |
| host-b | outside host 10.15.2.20/24 with **no default route**: like a server on the Internet, it knows nothing about private networks and can only answer addresses in 10.15.2.0/24. Web server on port 80 | neo-tools | Attach Shell |
| host-c | dmz server 10.15.3.30/24, gateway fw; web server on port 80 | neo-tools | Attach Shell |

All addresses are private (RFC 1918). The outside network **plays** the Internet and 10.15.2.1 plays a public address; the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. Each web server writes its access log to `/var/log/web.log`; the first field of each line is the **client address the server saw**.

fw has two tables: `ip fw_nat` (the NAT rules, chains `prerouting` and `postrouting`) and `inet fw` (the filter rules, chain `forward`). The order a new connection's first packet meets them is: **prerouting (destination NAT) > routing > forward (filter) > postrouting (source NAT)**.

## Files

- `firewall-nat.clab.yml` - the lab drawing. Addresses, routes, the bridge and web servers are set by each node's `exec` lines.
- `configs/fw-start.nft` - fw's deploy state: filter `inet fw` with policy accept, and an empty NAT table `ip fw_nat`.
- `changes/` - loaded with `docker exec -i clab-firewall-nat-fw nft -f - < changes/<file>`. Each file replaces one table as a whole (its counters start again at zero):
  - NAT table: `nat-none.nft`, `nat-source.nft` (masquerade), `nat-snat.nft` (snat to a fixed address), `nat-port-forward.nft` (source NAT + 10.15.2.1:8080 to host-c:80), `nat-hairpin-forward.nft` (+ 10.15.2.1:8081 to host-d:8080), `nat-hairpin-fixed.nft` (+ hairpin NAT);
  - filter table: `filter-open.nft`, `filter-wrong.nft`, `filter-right.nft`, `filter-right-hairpin.nft`;
  - `trace-on.nft` and `trace-off.nft` (packet tracing of ports 8080 and 8081).
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute and a half, puts fw back to its deploy state at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `firewall-nat.drawio` and `firewall-nat.png` - the prepared diagram.
- `captures/` - four sample captures: `nat-1-no-nat.pcapng`, `nat-2-source-nat.pcapng`, `nat-3-port-forward.pcapng`, `nat-4-hairpin-broken.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `firewall-nat` > right-click `firewall-nat.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.3.30/
  ```
  It prints `http 200 in ...`: host-a (inside) reached host-c's web page (dmz) through fw. No NAT is needed for that: host-c's gateway is fw.
- **Reset to the lesson start** (no NAT, no filtering, counters at zero):
  ```
  cd ~/labs-main/containerlab/labs/firewall-nat
  ```
  ```
  containerlab redeploy -c -t firewall-nat.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | On fw (Linux, nftables) |
|---|---|
| The NAT rules, with counters | `nft list table ip fw_nat` |
| The filter rules, with counters | `nft list table inet fw` |
| Load a file | `nft -f <file>` (here: `docker exec -i clab-firewall-nat-fw nft -f - < changes/<file>`) |
| The session table, including each translation | `conntrack -L` (or `cat /proc/net/nf_conntrack`); add `| grep 'dport=8080 '` to keep one port |
| Which rule decided each packet | load `changes/trace-on.nft`, then `nft monitor trace` |
| What a server saw | `docker exec clab-firewall-nat-host-b tail -n 1 /var/log/web.log` (also host-c, host-d) |
| Packets on a host, live | `docker exec clab-firewall-nat-host-b tcpdump -nni eth1 tcp port 80` |
| Wireshark filter | `tcp.port == 80 or tcp.port == 8080 or tcp.port == 8081` |

`nft list ruleset` also shows a table `ip nat` with a warning (and lines like `XT target DNAT not found`): that table belongs to Docker (it makes name lookups work inside the container). Leave it alone; this lab's rules are in `ip fw_nat` and `inet fw`.

The web test used in every exercise prints the HTTP status and the time: `http 200` is a page; **`http 000 in 3.0 s`** is no answer within the 3-second limit (curl exit code 28); **`http 000 in 0.0000... s`** fails at once (exit code 7).

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-nat`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. No NAT: the reply has no way back.** Watch host-b's port in a second terminal (it stops by itself after 20 seconds):
```
docker exec clab-firewall-nat-host-b timeout 20 tcpdump -lnni eth1 tcp port 80
```
In the first terminal:
```
docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.20/
```
`http 000 in 3.0 s`. The capture shows `IP 10.15.1.10.<port> > 10.15.2.20.80: Flags [S]` three times and nothing from host-b: the SYN arrived from a private address, and host-b has no route to 10.15.1.0/24, so it cannot answer. (Sample `nat-1-no-nat.pcapng`.)

**2. Source NAT.** Hide the inside behind fw's outside address:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/nat-source.nft
```
Start the capture again in the second terminal, then:
```
docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.20/
```
```
docker exec clab-firewall-nat-host-b tail -n 1 /var/log/web.log
```
`http 200`. The capture shows the whole connection between **10.15.2.1** and 10.15.2.20, and host-b's log line starts with `10.15.2.1`: host-b never sees host-a's real address. (Sample `nat-2-source-nat.pcapng`.) Now look at the translation in fw's session table while a connection is open:
```
docker exec -d clab-firewall-nat-host-a sh -c "sleep 20 | nc 10.15.2.20 80"
```
Two commands show the same **session table** (the list of connections the firewall or NAT router has seen). **Try `conntrack -L` first.** It talks to the kernel through a modern interface and works on every lab kernel we have tried, including newer ones (for example Linux 7.0) that do not create the file `/proc/net/nf_conntrack`. If `conntrack` is not installed, or it prints an error such as `Operation failed: invalid parameters`, use the file instead: `cat /proc/net/nf_conntrack`. Either way, each line is one session (addresses, ports, and a state such as `ESTABLISHED`). They are two windows onto the same table, not two different tables.
```
docker exec clab-firewall-nat-fw conntrack -L | grep 'dport=80 '
```
If `conntrack` is missing or errors, use `docker exec clab-firewall-nat-fw grep 'dport=80 ' /proc/net/nf_conntrack` instead. The `ESTABLISHED` line has two halves: `src=10.15.1.10 dst=10.15.2.20 sport=P dport=80` (the connection as host-a sent it) and `src=10.15.2.20 dst=10.15.2.1 sport=80 dport=P` (what a reply must look like: **to the public address**). That pair is the NAT table entry: replies to 10.15.2.1 are translated back to 10.15.1.10. Then:
```
docker exec clab-firewall-nat-fw nft list table ip fw_nat
```
The masquerade rule counted **2** packets after two connections: only the **first** packet of each connection goes through the NAT rules; every later packet uses the session. `changes/nat-snat.nft` writes the same thing with a fixed address (`snat to 10.15.2.1`); load it and repeat the web test if you like: same log line. Masquerade follows the port's address; snat is for a fixed public address or a pool.

**3. Destination NAT: a port forward.** Publish host-c's web server on 10.15.2.1 port 8080:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/nat-port-forward.nft
```
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8080/
```
```
docker exec clab-firewall-nat-host-c tail -n 1 /var/log/web.log
```
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.3.30/
```
host-b gets `http 200` from 10.15.2.1:8080, and host-c's log starts with **10.15.2.20**: destination NAT changes the destination and keeps the real client address. host-b cannot reach 10.15.3.30 directly (`http 000 in 0.0000... s`, exit 7: no route): the public address is the only way in. `conntrack -L | grep 'dport=8080 '` on fw (or the same `grep` on `/proc/net/nf_conntrack`) shows `src=10.15.2.20 dst=10.15.2.1 ... dport=8080` and `src=10.15.3.30 dst=10.15.2.20 sport=80`. (Sample `nat-3-port-forward.pcapng`: on the dmz side the packets go to 10.15.3.30:80 from 10.15.2.20.)

**4. NAT and the filter rules.** Add a default-deny filter whose port-forward rule is written for the **public** address and port:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/filter-wrong.nft
```
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8080/
```
```
docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.20/
```
```
docker exec clab-firewall-nat-fw nft list table inet fw
```
host-b: `http 000 in 3.0 s`; the rule `WRONG: public address and port` counted **0** and the cleanup counter **3**. host-a: `http 200`, counted by the rule that matches the **private** source 10.15.1.0/24. The filter runs **after** destination NAT and **before** source NAT, so it sees the real server address (10.15.3.30:80) and the real inside client address. Load the corrected filter and try again:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/filter-right.nft
```
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8080/
```
`http 200`; the rule `port forward: real address after DNAT` (`ip daddr 10.15.3.30 tcp dport 80 ct status dnat`) counted 1. `ct status dnat` means "only connections that came in through a port forward": host-b still cannot reach 10.15.3.30 any other way.

**5. Watch the order in a trace.**
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/trace-on.nft
```
Second terminal (it stops by itself after 30 seconds):
```
docker exec -it clab-firewall-nat-fw sh -c "timeout 30 nft monitor trace | grep --line-buffered -E 'fw_nat|inet fw'"
```
First terminal:
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8080/
```
For the first packet, in this order: `ip fw_nat prerouting rule ... dnat to 10.15.3.30:80 ... (verdict accept)`, then `inet fw forward rule iifname "eth2" ip daddr 10.15.3.30 tcp dport 80 ct status dnat ... (verdict accept)`, then `ip fw_nat postrouting policy accept`. Later packets show only `inet fw forward rule ct state established,related ... (verdict accept)`. Switch tracing off when it has stopped:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/trace-off.nft
```

**6. Hairpin NAT.** Publish inside server host-d on 10.15.2.1:8081, for any client, with a filter rule for it:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/nat-hairpin-forward.nft
```
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/filter-right-hairpin.nft
```
```
docker exec clab-firewall-nat-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8081/
```
host-b: `http 200` (host-d's log shows 10.15.2.20). Now host-a, which sits on the same switch as host-d, uses the public address. Watch host-a's port in the second terminal:
```
docker exec clab-firewall-nat-host-a timeout 20 tcpdump -lnni eth1 tcp port 8080 or tcp port 8081
```
```
docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8081/
```
`http 000 in 3.0 s`. Three times: host-a sends `SYN` to `10.15.2.1.8081`; a `SYN-ACK` comes back **straight from `10.15.1.40.8080`** (host-d answers its neighbour directly, not through fw); host-a does not know that connection and sends `R` (reset). (Sample `nat-4-hairpin-broken.pcapng`.) Fix it with hairpin NAT: inside clients that come back in through the public address are also source-NATed, so host-d answers fw:
```
docker exec -i clab-firewall-nat-fw nft -f - < changes/nat-hairpin-fixed.nft
```
```
docker exec clab-firewall-nat-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.15.2.1:8081/
```
```
docker exec clab-firewall-nat-host-d tail -n 1 /var/log/web.log
```
`http 200`, and host-d's log now shows **10.15.1.1** (fw's inside address), not host-a: the price of hairpin NAT is that the server loses the real client address. (Split DNS, which gives inside clients the inside address, avoids hairpin NAT altogether.)

Reset the lab (see **Start, reset, stop**) to go back to the deploy state.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `nat-1-no-nat.pcapng` | host-b:eth1 | 5 | no NAT: host-a's SYN from 10.15.1.10 and two retries; host-b sends nothing back (no route); then an ARP exchange |
| `nat-2-source-nat.pcapng` | host-b:eth1 | 13 | source NAT: the same request from 10.15.2.1, answered (handshake, GET, 200 OK, close) |
| `nat-3-port-forward.pcapng` | fw:eth3 (dmz) | 12 | port forward: host-b asked for 10.15.2.1:8080; on the dmz side the connection is 10.15.2.20 to 10.15.3.30:80 |
| `nat-4-hairpin-broken.pcapng` | host-a:eth1 | 13 | hairpin without hairpin NAT: SYN to 10.15.2.1:8081, SYN-ACK from 10.15.1.40:8080, host-a's RST, three times; then ARP |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic (router solicitations, multicast listener reports) and ARP; the display filter `ip` hides them.

## What this lab does not do

- No commercial firewall: no NAT policy screen, no NAT pools with port blocks, no proxy ARP, no NAT for IPv6 (NPTv6). The lesson shows vendor NAT rules as text.
- One public address only: no pool, no one-to-one (static) NAT of a whole server address. `snat to` with a range would make a pool.
- The "public" address and the "Internet" are private ranges that play those roles.
- No application-level helpers (FTP, SIP), which some firewalls need for protocols that carry addresses inside the data.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the web servers start after the addresses). If you loaded filter files, load `changes/filter-open.nft` (the deploy state) or reset the lab.
2. **`nft -f` says `No such file or directory`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-nat`) so that `changes/...` is found.
3. **Exercise 2 still fails.** Check `nft list table ip fw_nat`: the masquerade rule must be there. Exercise 1's capture may still be running in the second terminal; that does not matter.
4. **Exercise 6: host-b gets `http 000`.** Load **both** `nat-hairpin-forward.nft` and `filter-right-hairpin.nft` (the second adds the filter rule for host-d).
5. **`trace-off.nft` says `No such file or directory`.** Tracing was not on; nothing to do.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/firewall-nat
```
```
containerlab destroy --cleanup -t firewall-nat.clab.yml
```
`--cleanup` also removes the generated `clab-firewall-nat` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-firewall-nat` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/firewall-nat/clab-firewall-nat
```
Your capture files in your Home folder are not touched.

