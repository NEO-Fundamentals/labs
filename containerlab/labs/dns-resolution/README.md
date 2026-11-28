# Lab: how a name becomes an address (DNS recursion, NXDOMAIN and SERVFAIL)

**Folder:** `labs/dns-resolution/`  **Lab file:** `dns-resolution.clab.yml`  **Lesson:** NEO-06 DNS for network engineers  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the lab runs four real DNS servers (BIND 9.20, the DNS server software many companies and ISPs use) and one Linux client. **There are no routers in this lab**, and it never asks the real Internet DNS: it has its own small root server and uses the private-use top-level domain `internal.`.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/dns-resolution/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `internetsystemsconsortium/bind9:9.20` (about 45 MB on disk) and `ghcr.io/neo-fundamentals/neo-tools:1.0.0` (about 260 MB). After that the lab works offline. Keep at least 1 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute. The DNS servers are ready a few seconds after the green dots.

## What this lab builds

```
                                 +--- root  10.6.0.2   (zone ".")
                                 |
 client ------------- resolver --+--- tld   10.6.0.6   (zone "internal.")
 10.6.1.10            10.6.1.53  |
                                 +--- auth  10.6.0.10  (zone "corp.internal.")
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| client | Linux host 10.6.1.10/24. Its DNS server is the resolver (10.6.1.53). Has `dig` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| resolver | Recursive resolver 10.6.1.53 (eth1). It answers the client and finds each answer itself, starting at root. Links: 10.6.0.1 (eth2, to root), 10.6.0.5 (eth3, to tld), 10.6.0.9 (eth4, to auth) | `internetsystemsconsortium/bind9:9.20` | Attach Shell |
| root | Authoritative server 10.6.0.2 for the root zone `.`: it knows only who runs `internal.` | `internetsystemsconsortium/bind9:9.20` | Attach Shell |
| tld | Authoritative server 10.6.0.6 for the top-level domain `internal.`: it knows who runs `corp.internal.` (and a broken entry for `branch.internal.`) | `internetsystemsconsortium/bind9:9.20` | Attach Shell |
| auth | Authoritative server 10.6.0.10 for `corp.internal.`: `www` 10.6.20.80, `mail` 10.6.20.25, `intranet` (an alias of `www`) | `internetsystemsconsortium/bind9:9.20` | Attach Shell |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. The names 10.6.20.80 and 10.6.20.25 point to are only records in the zone; no machine has those addresses, so a ping to them gets no reply. This lab is about the name lookup.

## Files

- `dns-resolution.clab.yml` - the lab drawing.
- `configs/resolver/named.conf` and `configs/resolver/root.hints` - the resolver: recursion on, where the root server is. The root hints are the only thing a resolver must know in advance.
- `configs/root/`, `configs/tld/`, `configs/auth/` - each server's `named.conf` and its zone file (`root.zone`, `internal.zone`, `corp.internal.zone`). Open the zone files: they are short and every line has a comment.
- `scripts/make-captures.sh` - re-records the sample captures. The lab must be running. Run it with `sudo bash scripts/make-captures.sh` from the lab folder; it takes about one minute and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `dns-resolution.drawio` and `dns-resolution.png` - the prepared diagram.
- `captures/` - five sample captures, recorded from this lab: `dns-1-recursion.pcapng`, `dns-2-cached.pcapng`, `dns-3-nxdomain.pcapng`, `dns-4-servfail-lame.pcapng`, `dns-5-servfail-down.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `dns-resolution` > right-click `dns-resolution.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-dns-resolution-client dig +short www.corp.internal
  ```
  It prints `10.6.20.80`. If it prints nothing or `connection timed out`, wait 10 seconds and run it again.
- **Reset to the lesson start:**
  ```
  cd ~/labs-main/containerlab/labs/dns-resolution
  ```
  ```
  containerlab redeploy -c -t dns-resolution.clab.yml
  ```
  To empty only the resolver's cache (it forgets every answer it has learned), run `docker exec clab-dns-resolution-resolver rndc flush`.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | On the client (Linux) | On a BIND server | In Wireshark |
|---|---|---|---|
| Ask the resolver for a name | `dig www.corp.internal` (short answer: `dig +short www.corp.internal`) | - | filter `dns` |
| Ask one server directly, without recursion | - | `dig @10.6.0.2 +norecurse www.corp.internal` (run inside the resolver) | `dns.flags.recdesired == 0` |
| See only failures | read `status:` in the dig header | - | `dns.flags.rcode != 0` (3 = NXDOMAIN, 2 = SERVFAIL, 5 = REFUSED) |
| Empty the resolver's cache | - | `rndc flush` (on the resolver) | - |
| Check a zone file | - | `named-checkzone corp.internal /etc/bind/corp.internal.zone` (on auth) | - |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**). They use `docker exec` so you do not need to open a shell for each device. You can also right-click a device > **Access** > **Attach Shell** and type the part after the container name.

**1. Ask the resolver.**
```
docker exec clab-dns-resolution-client dig www.corp.internal
```
Read three parts of the answer. The header line says `status: NOERROR`, and the flags line has `rd` (the client asked for recursion: "find it for me") and `ra` (the resolver offers recursion). The `ANSWER SECTION` has `www.corp.internal. 300 IN A 10.6.20.80`: the name, how many seconds it may be cached (300), and the address. The last lines say `SERVER: 10.6.1.53#53(10.6.1.53) (UDP)`: the question went to the resolver over UDP port 53. Now an alias:
```
docker exec clab-dns-resolution-client dig +short intranet.corp.internal
```
It prints two lines, `www.corp.internal.` and `10.6.20.80`: `intranet` is a CNAME (another name for `www`), and the resolver followed it for you.

**2. Walk the tree yourself, one server at a time.** The client cannot reach the other servers, so run `dig` inside the resolver. `+norecurse` asks each server for what it knows itself, without looking anything up:
```
docker exec clab-dns-resolution-resolver dig @10.6.0.2 +norecurse www.corp.internal
```
root does not know the address. Its `ANSWER` count is 0, and the `AUTHORITY SECTION` says `internal. 3600 IN NS ns.tld-servers.internal.` with the address `10.6.0.6` in the `ADDITIONAL SECTION`: "ask the server for `internal.`". That is a **referral**. Ask the server it named:
```
docker exec clab-dns-resolution-resolver dig @10.6.0.6 +norecurse www.corp.internal
```
Another referral: `corp.internal. 3600 IN NS ns1.corp.internal.`, address `10.6.0.10`. Ask that one:
```
docker exec clab-dns-resolution-resolver dig @10.6.0.10 +norecurse www.corp.internal
```
Now the `ANSWER SECTION` has `10.6.20.80`, and the flags line has `aa`: an **authoritative answer**, from the server that owns the zone. This is exactly what the resolver did for you in exercise 1.

**3. Watch the resolver walk the tree.** Empty its cache first, so it has to ask everyone again:
```
docker exec clab-dns-resolution-resolver rndc flush
```
In Ubuntu's Terminal app start the capture first. It records all four of the resolver's cables into one file for 8 seconds:
```
sudo containerlab capture --name dns-resolution --target resolver:eth1,eth2,eth3,eth4 --duration 8s -w - > "$HOME/neo-dns-walk.pcapng"
```
Then, within the 8 seconds, in VS Code's terminal:
```
docker exec clab-dns-resolution-client dig www.corp.internal
```
Open the file in Wireshark and type `dns` in the filter bar. The sample `captures/dns-1-recursion.pcapng` shows the order (Wireshark shows the cable in the frame details as the interface name, for example `resolver:eth2`):

- frame 1: the client's question to the resolver (eth1)
- frames 2 to 5: the resolver asks root (eth2). Frame 3 is an extra question, `NS <Root>`: the resolver checks the list of root servers it was given (this is called priming). Frame 4 is root's referral to `ns.tld-servers.internal` (10.6.0.6)
- frames 6 and 7: the question to tld (eth3) and its referral to `ns1.corp.internal` (10.6.0.10)
- frames 8 and 9: the question to auth (eth4) and the answer `10.6.20.80`
- frame 10: the resolver's answer to the client (eth1)
- frames 11 to 18: ARP between the neighbours; ignore them

Every question the resolver sends upstream carries the full name `www.corp.internal`. (This lab turns off "QNAME minimisation", a privacy feature that makes a resolver send root and the TLD server only the part of the name they need. Real resolvers usually have it on.)

**4. Ask again: the cache.** Run the same question again (and capture it the same way if you like):
```
docker exec clab-dns-resolution-client dig www.corp.internal
```
The answer is the same, but the TTL is now below 300 (it counts down) and `Query time:` is about 0 msec. The resolver answered from its cache and asked nobody. In the sample `captures/dns-2-cached.pcapng` the only DNS frames are the question and answer on eth1 (frames 9 and 10); the other frames are ARP.

**5. A name that does not exist: NXDOMAIN.**
```
docker exec clab-dns-resolution-client dig nothere.corp.internal
```
The header says `status: NXDOMAIN` ("no such name"), the `ANSWER` count is 0, and the `AUTHORITY SECTION` has the zone's SOA record. The `30` in front of the SOA tells resolvers how long they may remember that the name does not exist. NXDOMAIN is a real answer from the server that owns the zone: the name is not there. The DNS system worked. In the sample `captures/dns-3-nxdomain.pcapng` the resolver goes straight to auth (frames 2 and 3, Wireshark says `No such name`), because it already knows from exercise 3 where `corp.internal.` lives.

**6. A broken delegation: SERVFAIL.** The tld server says `branch.internal.` is run by `ns1.branch.internal` at 10.6.0.10, but that server (auth) was never set up for it:
```
docker exec clab-dns-resolution-client dig www.branch.internal
```
The header says `status: SERVFAIL`: the resolver could not get an answer from anyone. SERVFAIL means "the lookup failed", not "the name does not exist". In the sample `captures/dns-4-servfail-lame.pcapng`, tld refers the resolver to 10.6.0.10 (frame 3), auth answers `Refused` (frame 5), and the resolver sends `Server failure` to the client (frame 6). Frames 7 to 12 are the resolver trying to learn more about `ns1.branch.internal` afterwards, also refused. The resolver's log says it too:
```
docker logs clab-dns-resolution-resolver 2>&1 | grep REFUSED
```
It prints lines such as `REFUSED unexpected RCODE resolving 'www.branch.internal/A/IN': 10.6.0.10#53`. A server that is named in a delegation but does not serve the zone is called a **lame delegation**.

**7. The authoritative server is down: SERVFAIL again.** Pause auth (it stops answering, like a server that crashed):
```
docker pause clab-dns-resolution-auth
```
```
docker exec clab-dns-resolution-client dig +timeout=15 +tries=1 mail.corp.internal
```
After about 10 seconds the answer is `status: SERVFAIL`, with the line `; EDE: 22 (No Reachable Authority)` (an extended error: the resolver could reach no server for that zone), and `Query time:` about 10000 msec. In the sample `captures/dns-5-servfail-down.pcapng` the resolver sends the question to 10.6.0.10 again and again with no reply, then answers `Server failure` (the last frame). Now start auth again (do not forget this step):
```
docker unpause clab-dns-resolution-auth
```
```
docker exec clab-dns-resolution-client dig +short mail.corp.internal
```
It prints `10.6.20.25`. Compare exercises 5, 6 and 7: NXDOMAIN is an answer ("no such name"); SERVFAIL is a failure ("I could not find out"), and the reason is in the resolver's log or in a capture of its upstream cables.

## Sample captures

All are cut to 200 bytes per packet and hold the four resolver cables (`resolver:eth1,eth2,eth3,eth4`) in one file. Open them in Wireshark with File > Open and filter on `dns`.

| File | Frames | What it shows |
|---|---|---|
| `dns-1-recursion.pcapng` | 18 | The full walk after `rndc flush`: client question, root (with the priming query), tld, auth, answer; then ARP |
| `dns-2-cached.pcapng` | 10 | The same question answered from the cache: one question and one answer on eth1, nothing upstream (the rest is ARP) |
| `dns-3-nxdomain.pcapng` | 4 | `nothere.corp.internal`: auth answers `No such name` with its SOA, the resolver passes it on |
| `dns-4-servfail-lame.pcapng` | 12 | `www.branch.internal`: tld refers to 10.6.0.10, which answers `Refused`; the client gets `Server failure` |
| `dns-5-servfail-down.pcapng` | 32 | auth paused: repeated questions to 10.6.0.10 with no reply, then `Server failure` to the client after about 10 seconds |

## What this lab does not do

- No real Internet names: the root and `internal.` exist only in this lab. `dig` for a real name such as a public website returns NXDOMAIN or SERVFAIL here, which is expected.
- No DNSSEC: signatures are off, because the lab root is not the real root.
- No IPv6 answers (AAAA records) and no DNS over TCP, TLS or HTTPS; UDP port 53 only.
- QNAME minimisation is off on purpose (see exercise 3).

## Troubleshooting

1. **`dig` says `connection timed out; no servers could be reached`.** The resolver is not running yet or the lab is not deployed. Run `containerlab inspect --all`; all five containers must be `running`. Wait 10 seconds after the green dots and try again.
2. **Every answer is SERVFAIL, even for `www.corp.internal`.** auth may still be paused from exercise 7: run `docker unpause clab-dns-resolution-auth`. If that says it is not paused, run `docker logs clab-dns-resolution-resolver 2>&1 | tail` and read the last lines.
3. **Exercise 3's capture has no root or tld frames.** The resolver still had the answer in its cache. Run `docker exec clab-dns-resolution-resolver rndc flush`, start the capture again, then ask.
4. **The capture is empty.** Start the capture first, then run `dig` within the 8 seconds. The target must name the resolver's cables: `resolver:eth1,eth2,eth3,eth4`.
5. **`rndc flush` prints an error instead of nothing.** The resolver makes its own control key a few seconds after the lab starts; wait 10 seconds and try again. If it still fails, redeploy the lab (see **Start, reset, stop**).
6. **You edited a zone file and nothing changed.** BIND reads the zone files when it starts. Redeploy the lab, and check the file first with `docker exec clab-dns-resolution-auth named-checkzone corp.internal /etc/bind/corp.internal.zone`.

## Cleanup

Do this when you finish the lab, and before you start a different one. First make sure auth is not paused (`docker unpause clab-dns-resolution-auth`; an error that it is not paused is fine). In the lab folder:
```
cd ~/labs-main/containerlab/labs/dns-resolution
```
```
containerlab destroy --cleanup -t dns-resolution.clab.yml
```
`--cleanup` also removes the generated `clab-dns-resolution` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-dns-resolution` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/dns-resolution/clab-dns-resolution
```
Your capture files in your Home folder are not touched.
