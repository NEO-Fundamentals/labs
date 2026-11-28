# Lab: Looking inside the traffic: application, site name and a threat signature

**Folder:** `labs/ngfw-inspection/`  **Lab file:** `ngfw-inspection.clab.yml`  **Lesson:** NEO-16 Next-generation firewall features: application identification, URL filtering, TLS decryption, and threat profiles  **Lab version:** 1.1.0 (2026-11-27)

**What runs and what does not:** the sensor `ids` sits inline between a client and a server, like a bump in the wire, and runs **Suricata** (in the NEO helper image `neo-tools:1.1.0`) in AF_PACKET IPS mode: it copies frames between its two interfaces, identifies each connection's application, reads the HTTP Host header and the TLS server name (SNI), and checks packets for a content signature; in IPS mode it drops what the policy blocks. Its decisions, its log and the dropped packets are real. It is **not a commercial next-generation firewall**: no vendor application database, no URL categories, no signature feed, and **no TLS decryption** (the lesson explains decryption; exercise 4 shows why it exists). The lab still uses a small policy language (`/etc/neo/inspect.rules`); a helper writes the matching Suricata rules and reloads them.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** modest: three Linux containers, about 90 MB together (measured; most of it is Suricata). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/ngfw-inspection/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy uses `ghcr.io/neo-fundamentals/neo-tools:1.0.0` for the client and the server, and `ghcr.io/neo-fundamentals/neo-tools:1.1.0` for ids (Suricata). 1.1.0 is built from `tools/neo-tools` and is not on the public registry yet; load or build that tag before Deploy (see the kit README). After the images are present the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab assumes you know what a firewall rule and a session are.

## What this lab builds

```
   client                         ids                         server
   10.16.1.10  ---- eth1   (no IP addresses)   eth2 ---- 10.16.1.20
                    Suricata (AF_PACKET IPS)                   web :80 (HTTP) and :443 (HTTPS)
                    copies and inspects every frame            SSH on :8443
   one subnet, 10.16.1.0/24: client and server talk directly, through ids
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| ids | inline sensor: **eth1** (client side) and **eth2** (server side) have no IP address; Suricata copies frames between them. Policy `/etc/neo/inspect.rules` (deploy copy: `configs/inspect-start.rules`), log `/var/log/inspect.log`, counters `/run/inspect.stats`. Suricata's own log is `/var/log/suricata/eve.json` | `ghcr.io/neo-fundamentals/neo-tools:1.1.0` | Right-click > **Access** > **Attach Shell** |
| client | 10.16.1.10/24. `news.lab.test` and `games.lab.test` both point to the server (in its `/etc/hosts`) | same | Attach Shell |
| server | 10.16.1.20/24. One web site on port **80** (HTTP) and **443** (HTTPS, a self-signed certificate it makes at deploy), with `index.html` and the test file `download/update.txt`; **SSH on port 8443** | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. The `.test` names are reserved for testing and exist only in this lab. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. The test file "plays" a malicious download: it is one harmless line of text containing the signature `NEO-TEST-THREAT`.

**The policy language** (`/etc/neo/inspect.rules`, one rule per line; a helper writes Suricata rules and reloads them within a second of a change):

| Line | Meaning |
|---|---|
| `mode ids` / `mode ips` | **ids**: log what the rules match, never drop (an IDS, or a firewall profile set to "alert"). **ips**: drop it (an IPS, or a profile set to "block") |
| `block host <name>` / `block sni <name>` | the HTTP Host header, or the TLS server name (SNI), equals `<name>`: a URL filter |
| `block content <text>` | `<text>` appears in one packet's payload: a threat signature |
| `alert app <app>` | the identified application (`http`, `tls`, `ssh`, `unknown`): log it, do not drop |

A blocked connection is dropped from that packet on, in both directions, and stays blocked even after the policy changes.

## Files

- `ngfw-inspection.clab.yml` - the lab drawing. Addresses, the web and SSH servers, the certificate and Suricata are started by each node's `exec` lines.
- `configs/suricata.yaml` - Suricata's lab config (AF_PACKET IPS between eth1 and eth2). `scripts/start-ids.sh` starts Suricata, `scripts/load-policy.py` turns the policy file into Suricata rules, and `scripts/inspect-log.py` writes `/var/log/inspect.log` from Suricata's eve log. `scripts/web_tls.py` - the server's HTTPS site.
- `configs/inspect-start.rules` - ids's policy at deploy: `mode ids`, no rules (visibility only).
- `changes/url-filter-ids.rules`, `changes/url-filter-ips.rules` - exercise 3. `changes/threat.rules` - exercise 4. Load one with `docker exec -i clab-ngfw-inspection-ids sh -c 'cat > /etc/neo/inspect.rules' < changes/<file>`.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads ids's deploy policy at the start and again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `ngfw-inspection.drawio` and `ngfw-inspection.png` - the prepared diagram.
- `captures/` - five sample captures: `ngfw-1-app-id.pcapng`, `ngfw-2-sni-block-client-side.pcapng`, `ngfw-2-sni-block-server-side.pcapng`, `ngfw-3-threat-client-side.pcapng`, `ngfw-3-threat-server-side.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `ngfw-inspection` > right-click `ngfw-inspection.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-ngfw-inspection-client curl -s -m 3 http://news.lab.test/
  ```
  It prints `hello from the lab web server (10.16.1.20)`: the client reached the server through ids.
- **Reset to the lesson start** (deploy policy, empty log):
  ```
  cd ~/labs-main/containerlab/labs/ngfw-inspection
  ```
  ```
  containerlab redeploy -c -t ngfw-inspection.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Where | Command |
|---|---|---|
| What did the engine see and decide? | ids | `cat /var/log/inspect.log` (or `tail -n 5 ...`) |
| Mode, number of rules, frames passed and dropped | ids | `cat /run/inspect.stats` |
| Which policy is loaded? | ids | `cat /etc/neo/inspect.rules` |
| Load a policy | the VM | `docker exec -i clab-ngfw-inspection-ids sh -c 'cat > /etc/neo/inspect.rules' < changes/<file>` |
| Fetch a page: status, size and time | client | `curl -s -k -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' <url>` |
| Who answers on port 8443? | client | `timeout 2 nc 10.16.1.20 8443` |

`-k` lets curl accept the server's self-signed certificate. `http 000 ... in 3.0 s` (curl exit code 28) means no answer within the 3-second limit: something **dropped** the packets.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/ngfw-inspection`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. A sensor with no address.**
```
docker exec clab-ngfw-inspection-ids ip -br addr
```
```
docker exec clab-ngfw-inspection-client ping -c 2 -W 1 10.16.1.20
```
```
docker exec clab-ngfw-inspection-client ip neigh show 10.16.1.20
```
```
docker exec clab-ngfw-inspection-server ip -br link show eth1
```
ids's `eth1` and `eth2` are `UP` with **no address** (only its management `eth0` has one). The ping works, and the client's neighbour entry for 10.16.1.20 is **the server's own MAC address**: ids is invisible to both ends, it neither routes nor answers ARP. Every frame still crosses it, so it can inspect, and (in IPS mode) drop.

**2. Application identification: the port does not tell you the application.**
```
docker exec clab-ngfw-inspection-client curl -s -m 3 http://news.lab.test/
```
```
docker exec clab-ngfw-inspection-client curl -s -k -m 3 https://news.lab.test/
```
```
docker exec clab-ngfw-inspection-client timeout 2 nc 10.16.1.20 8443
```
```
docker exec clab-ngfw-inspection-ids cat /var/log/inspect.log
```
The two pages arrive and port 8443 answers with `SSH-2.0-OpenSSH_...` (`nc` then waits until `timeout` ends it after 2 seconds, exit code 124). Wait a second, then read the log. It has one line per connection:
- `flow 10.16.1.10:P -> 10.16.1.20:80 app=http host=news.lab.test`: the site name from the HTTP Host header.
- `flow ... -> 10.16.1.20:443 app=tls sni=news.lab.test`: the content is encrypted, but the **server name travels in clear text** in the TLS ClientHello (in Wireshark: `tls.handshake.extensions_server_name`).
- `flow ... -> 10.16.1.20:8443 app=ssh`: port 8443 is usually HTTPS, but the first bytes say SSH. A port-based rule ("allow 8443") would let SSH through without knowing it; an application rule sees it. The SSH log line may appear only after `nc` has finished.

(Sample `ngfw-1-app-id.pcapng`: the three connections.)

**3. A URL filter: first IDS, then IPS.** Log first:
```
docker exec -i clab-ngfw-inspection-ids sh -c 'cat > /etc/neo/inspect.rules' < changes/url-filter-ids.rules
```
```
docker exec clab-ngfw-inspection-client curl -s -k -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' https://games.lab.test/
```
```
docker exec clab-ngfw-inspection-ids tail -n 3 /var/log/inspect.log
```
`http 200, 43 bytes`: the page loads, and the log says `ALERT ... app=tls rule "block sni games.lab.test": would block (mode ids)`. That is how a new filter is usually tried out: watch what it would hit before it hits anything. Now block:
```
docker exec -i clab-ngfw-inspection-ids sh -c 'cat > /etc/neo/inspect.rules' < changes/url-filter-ips.rules
```
```
docker exec clab-ngfw-inspection-client curl -s -k -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' https://games.lab.test/
```
```
docker exec clab-ngfw-inspection-client curl -s -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' http://games.lab.test/
```
```
docker exec clab-ngfw-inspection-client curl -s -k -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' https://news.lab.test/
```
```
docker exec clab-ngfw-inspection-ids tail -n 6 /var/log/inspect.log
```
games.lab.test: `http 000, 0 bytes in 3.0 s`, over HTTPS and over HTTP. news.lab.test (same server, same address, same port): `http 200`. The log shows `BLOCK ... app=tls rule "block sni games.lab.test" (packet from 10.16.1.10 dropped, flow blocked)` and the same for `block host`. The HTTPS block needed **no decryption**: the TCP handshake completed, then ids dropped the ClientHello that named the site, so TLS never started. (Samples `ngfw-2-sni-block-client-side.pcapng`, the ClientHello and its retransmissions, and `ngfw-2-sni-block-server-side.pcapng`, recorded at the same time: the handshake only; the ClientHello never reached the server.)

**4. A threat signature, and why firewalls decrypt TLS.**
```
docker exec -i clab-ngfw-inspection-ids sh -c 'cat > /etc/neo/inspect.rules' < changes/threat.rules
```
```
docker exec clab-ngfw-inspection-client curl -s -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' http://news.lab.test/download/update.txt
```
```
docker exec clab-ngfw-inspection-client curl -s -k -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' https://news.lab.test/download/update.txt
```
```
docker exec clab-ngfw-inspection-client timeout 2 nc 10.16.1.20 8443
```
```
docker exec clab-ngfw-inspection-ids tail -n 6 /var/log/inspect.log
```
- **HTTP:** `http 200, 0 bytes in 3.0 s` (exit 28). The headers arrived (`200`), but the packet that carried the file contained `NEO-TEST-THREAT`, and ids dropped it: `BLOCK ... app=http rule "block content NEO-TEST-THREAT" (packet from 10.16.1.20 dropped, flow blocked)`.
- **HTTPS:** `http 200, 64 bytes`: **the same file got through**. Encrypted, the signature is invisible to the engine; the log has only the `flow ... app=tls sni=news.lab.test` line. This is why next-generation firewalls offer **TLS decryption**: the firewall ends the client's TLS session itself (with a certificate the clients must trust) and opens a second one to the server, so it can inspect the content in between. This lab does not decrypt; the lesson explains how it works and what it costs.
- **SSH:** the banner arrives; the log says `ALERT ... app=ssh rule "alert app ssh": alert`: logged, not blocked. Suricata may print that alert more than once for the same session.

(Samples `ngfw-3-threat-server-side.pcapng`, the file leaving the server and being retransmitted, and `ngfw-3-threat-client-side.pcapng`, recorded at the same time: only the headers arrive.)

**5. A classic inline-sensor problem: checksum offload.** Switch transmit checksum offload back **on** at the client (the lab switches it off at deploy):
```
docker exec clab-ngfw-inspection-client ethtool -K eth1 tx on
```
```
docker exec clab-ngfw-inspection-client ping -c 2 -W 1 10.16.1.20
```
Watch the server's port in a second terminal (it stops after 3 packets or 20 seconds):
```
docker exec clab-ngfw-inspection-server timeout 20 tcpdump -lvnni eth1 -c 3 tcp port 80
```
In the first terminal:
```
docker exec clab-ngfw-inspection-client curl -s -m 3 -o /dev/null -w 'http %{http_code}, %{size_download} bytes in %{time_total} s\n' http://news.lab.test/
```
The ping still works, but the web request fails (`http 000 ... in 3.0 s`), and the server's capture shows the client's SYNs with **`cksum 0x... (incorrect -> 0x...)`**. With offload on, the client's kernel leaves the TCP checksum for the network card to fill in; between two containers nobody ever fills it in, which is fine as long as the frame goes straight to the other kernel. Suricata, however, picks the frame up and sends it again as raw bytes, so the server receives a TCP segment with a wrong checksum and drops it. (Ping is not affected: ICMP checksums are always computed in software.) Inline sensors on virtual machines and containers hit this all the time. Switch it off again:
```
docker exec clab-ngfw-inspection-client ethtool -K eth1 tx off
```
The same request now gives `http 200`.

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `ngfw-1-app-id.pcapng` | ids:eth1 (client side) | 34 | HTTP to news.lab.test (`http.host`), HTTPS to news.lab.test (the ClientHello with `SNI=news.lab.test`, then encrypted data), and the SSH banner from port 8443 |
| `ngfw-2-sni-block-client-side.pcapng` | ids:eth1 (client side) | 9 | the handshake to port 443, the ClientHello with `SNI=games.lab.test`, and its retransmissions, never answered |
| `ngfw-2-sni-block-server-side.pcapng` | ids:eth2 (server side) | 3 | recorded at the same time: the handshake only; the ClientHello never arrives |
| `ngfw-3-threat-client-side.pcapng` | ids:eth1 (client side) | 12 | `GET /download/update.txt`, the `200 OK` headers, then nothing: the client gives up after 3 seconds and its `FIN` is retransmitted |
| `ngfw-3-threat-server-side.pcapng` | ids:eth2 (server side) | 12 | recorded at the same time: the headers **and** the body with the signature, then the server's retransmissions of the body |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic; the display filter `tcp` shows only the connections.

## What this lab does not do

- No commercial NGFW: Suricata does the inspection, with a handful of lab rules, not a vendor application database, URL categories, reputation or signature feeds, or a sandbox; the lesson shows vendor screens as text.
- **No TLS decryption.** Exercise 4 shows the gap that decryption closes.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start prints nothing.** Wait 5 seconds and try again; if it still fails, look at `/var/log/suricata/start.log` and `/var/log/ids-start.log` on ids and reset the lab.
2. **A blocked site stays blocked after loading another policy.** Connections that were blocked stay blocked; a new connection (run curl again) follows the new policy.
3. **Every web request fails, ping works.** Checksum offload is on somewhere (exercise 5): run `ethtool -K eth1 tx off` on client and server.
4. **The log has no line for a connection.** The engine logs a connection when its first data arrives; a connection that sent no data (only a handshake) has no line.
5. **`cat > /etc/neo/inspect.rules` says `No such file or directory` for `changes/...`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/ngfw-inspection`).

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/ngfw-inspection
```
```
containerlab destroy --cleanup -t ngfw-inspection.clab.yml
```
`--cleanup` also removes the generated `clab-ngfw-inspection` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-ngfw-inspection` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/ngfw-inspection/clab-ngfw-inspection
```
Your capture files in your Home folder are not touched.

