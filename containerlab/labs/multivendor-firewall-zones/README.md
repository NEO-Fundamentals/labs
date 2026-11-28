# Lab: Junos SRX style firewall: security zones and zone-pair policies

**Folder:** `labs/multivendor-firewall-zones/`  **Lab file:** `multivendor-firewall-zones.clab.yml`  **Lesson:** NEO-40 Multi-vendor firewalls: Junos SRX  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables with connection tracking** (the NEO helper image `neo-tools`). Its policy is **laid out the way a Junos SRX builds one**: interfaces in security zones, one policy list per zone pair ("from-zone trust to-zone untrust"), an address book, host-inbound traffic per zone and a default deny. The zones, policies, counters and session table are real Linux ones. **There is no Junos SRX here** (and no Junos image in the kit): the Junos commands are shown as text, in `configs/srx-reference.conf` and in the table below, to compare with what the Linux firewall does.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: four Linux containers, about 11 MB each (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-firewall-zones/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab uses the same three zones and assumes you know `ct state` and the session table.

## What this lab builds

```
   host-a (trust)                 fw                   host-b (untrust)
   10.40.1.10  ---- eth1 10.40.1.1    10.40.2.1 eth2 ---- 10.40.2.20
   web :8080          zone trust        zone untrust      web :80  (plays the Internet)
                            10.40.3.1 eth3  zone dmz
                                  |
                            host-c (dmz)
                            10.40.3.30, web :80
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking, policy laid out like an SRX. **eth1 = zone trust** (10.40.1.1/24), **eth2 = zone untrust** (10.40.2.1/24), **eth3 = zone dmz** (10.40.3.1/24). Loads `configs/srx-zones.nft` at deploy | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-a | trust host 10.40.1.10/24, gateway fw; web server on **port 8080** | same | Attach Shell |
| host-b | untrust host 10.40.2.20/24, gateway fw; web server on port 80 | same | Attach Shell |
| host-c | dmz server 10.40.3.30/24, gateway fw; web server on port 80 | same | Attach Shell |

All addresses are private (RFC 1918). The untrust zone **plays** the Internet; the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The policy** (`configs/srx-zones.nft`), SRX idea by SRX idea:

| SRX idea | Junos (text only, `configs/srx-reference.conf`) | In this lab (nftables on fw) |
|---|---|---|
| Security zones | `set security zones security-zone trust interfaces ge-0/0/1.0` | eth1 = trust, eth2 = untrust, eth3 = dmz; the map `zone_pair` uses the interface names |
| Zone-pair policies | `set security policies from-zone untrust to-zone dmz policy web-in ...` | one chain per zone pair (`from-untrust-to-dmz`), entered through `zone_pair`; its rules are the policies, top to bottom |
| Address book | `set security address-book global address web-server 10.40.3.30/32` | the set `web-server` |
| Application | `application junos-http` | `tcp dport 80` |
| Default policy | `set security policies default-policy deny-all` | no zone pair or no policy matched: `default-policy deny-all` counter, then the chain's `policy drop` |
| Host-inbound traffic | `set security zones security-zone trust host-inbound-traffic system-services ping` | chain `input`: the set `ping-zones` (only eth1 at the start), and only to the address of the interface the ping arrives on |
| Flow session | `show security flow session` | connection tracking: `ct state established,related accept`; see the table with `conntrack -L` first, or `/proc/net/nf_conntrack` if that command is missing |
| Hit counts | `show security policies hit-count` | the `counter packets ...` on each rule (`nft list table inet srx`) |

At the start there are three zone pairs with policies: **trust to untrust** (`allow-out`: anything), **untrust to dmz** (`web-in`: web to web-server only) and **trust to dmz** (`web-trust`: the same). Every other direction (untrust to trust, dmz to anywhere) has **no policy at all**, so the default policy denies it.

## Files

- `multivendor-firewall-zones.clab.yml` - the lab drawing. Addresses, routes and web servers are set by each node's `exec` lines.
- `configs/srx-zones.nft` - the policy that fw loads at deploy (above). Loading it again replaces the table `inet srx` as a whole (that is how the exercises are undone).
- `configs/srx-reference.conf` - the same policy in Junos `set` commands, plus the two changes of exercises 3 and 4. **Text only**: nothing loads it.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads the deploy policy again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `multivendor-firewall-zones.drawio` and `multivendor-firewall-zones.png` - the prepared diagram.
- `captures/` - three sample captures: `srx-1-zone-pairs.pcapng`, `srx-2-host-inbound.pcapng`, `srx-3-new-zone-pair.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-firewall-zones` > right-click `multivendor-firewall-zones.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.2.20/
  ```
  It prints `http 200 in ...`: host-a (trust) reached host-b's web page (untrust) through fw.
- **Reset to the lesson start** (deploy policy, counters at zero):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-firewall-zones
  ```
  ```
  containerlab redeploy -c -t multivendor-firewall-zones.clab.yml
  ```
  Or, quicker, only the policy: `docker exec clab-multivendor-firewall-zones-fw nft -f /neo/configs/srx-zones.nft`.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | SRX (text only) | Here (on fw) |
|---|---|---|
| Which zone pairs have policies? | `show security policies` | `nft list map inet srx zone_pair` |
| The policies and their hit counts | `show security policies hit-count` | `nft list table inet srx` |
| The session table | `show security flow session` | `conntrack -L | grep 10.40` (or `grep 10.40 /proc/net/nf_conntrack` if `conntrack` is missing) |
| What may reach the firewall itself? | `show security zones` (host-inbound) | `nft list chain inet srx input` and `nft list set inet srx ping-zones` |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-firewall-zones`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Zone pairs: a direction without a policy is denied.**
```
docker exec clab-multivendor-firewall-zones-fw nft list map inet srx zone_pair
```
```
docker exec clab-multivendor-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.2.20/
```
```
docker exec clab-multivendor-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.1.10:8080/
```
```
docker exec clab-multivendor-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.3.30/
```
```
docker exec clab-multivendor-firewall-zones-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.2.20/
```
```
docker exec clab-multivendor-firewall-zones-fw nft list table inet srx
```
The map lists three zone pairs: `"eth1" . "eth2"` (trust to untrust), `"eth2" . "eth3"` (untrust to dmz) and `"eth1" . "eth3"` (trust to dmz). host-a to host-b: `http 200` (policy `allow-out`). host-b to host-a: `http 000` after 3 s: untrust to trust is not in the map, so no policy is even looked at and the **default policy** denies it. host-b to host-c: `http 200` (policy `web-in`). host-c to host-b: `http 000`: dmz to untrust has no policy either. In the table, `allow-out`, `web-in` and the default policy have counted: `default-policy deny-all` shows 6 packets (three SYNs from each denied request). On an SRX the same question is `show security policies hit-count`, and the answer is the same: **a policy belongs to one direction between two zones**, and a zone pair without policies is closed. (Sample `srx-1-zone-pairs.pcapng`, recorded on fw's untrust port: the full web exchange with host-a, host-b's three unanswered SYNs to host-a, then the exchange with host-c.)

**2. The flow session: replies need no policy.**
```
docker exec clab-multivendor-firewall-zones-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.2.20/
```
```
docker exec clab-multivendor-firewall-zones-fw conntrack -L | grep 10.40
```
If that command is missing or errors, use `docker exec clab-multivendor-firewall-zones-fw grep 10.40 /proc/net/nf_conntrack` instead. The `/proc` file is the same session table, but some kernels (including Ubuntu 24.04 with kernel 7.0) do not provide it. `conntrack -L` asks the kernel another way and works on those kernels too.

Each line is one session, with both directions: `src=10.40.1.10 dst=10.40.2.20 ... dport=80` and the reply `src=10.40.2.20 dst=10.40.1.10 sport=80 ...`, state `TIME_WAIT` (finished, kept for a short while) and `[ASSURED]`. host-b's answers travelled untrust to trust, the direction with no policy, and passed: they matched an existing session (`flow session: part of an allowed session`). An SRX does the same: the policy is checked for the **first packet** of a session, and `show security flow session` lists the session with its in and out halves.

**3. Host-inbound traffic: pinging the firewall itself.**
```
docker exec clab-multivendor-firewall-zones-host-a ping -c 2 -W 1 10.40.1.1
```
```
docker exec clab-multivendor-firewall-zones-host-b ping -c 2 -W 1 10.40.2.1
```
host-a's pings to fw's trust address are answered; host-b's pings to fw's untrust address are not (`2 packets transmitted, 0 received`). Traffic **to** the firewall itself is not covered by the zone-pair policies: an SRX allows it per zone (`host-inbound-traffic`), and only trust allows ping here. Allow ping in the untrust zone (SRX: `set security zones security-zone untrust host-inbound-traffic system-services ping`):
```
docker exec clab-multivendor-firewall-zones-fw nft add element inet srx ping-zones '{ "eth2" }'
```
```
docker exec clab-multivendor-firewall-zones-host-b ping -c 2 -W 1 10.40.2.1
```
```
docker exec clab-multivendor-firewall-zones-host-b ping -c 2 -W 1 10.40.1.1
```
Now host-b's pings to 10.40.2.1 are answered, but its pings to **10.40.1.1** (fw's trust address) still are not: host-inbound traffic is decided by the zone the packet **arrives** in, and it only answers for the address of that interface. Reaching another zone's interface address would need more than this setting; on an SRX you would not normally open it. (Sample `srx-2-host-inbound.pcapng`: two unanswered pings, the change, two answered.)

**4. Add a zone pair: dmz to untrust.** host-c needs to fetch web pages from the Internet side (software updates, say). In SRX terms: a new policy `dmz-updates` from-zone dmz to-zone untrust, application junos-http. Here it is a new chain, one policy in it, and a new entry in the zone-pair map:
```
docker exec clab-multivendor-firewall-zones-fw nft add chain inet srx from-dmz-to-untrust
```
```
docker exec clab-multivendor-firewall-zones-fw nft add rule inet srx from-dmz-to-untrust tcp dport 80 counter accept comment '"policy dmz-updates: any any junos-http, permit"'
```
```
docker exec clab-multivendor-firewall-zones-fw nft add element inet srx zone_pair '{ "eth3" . "eth2" : jump from-dmz-to-untrust }'
```
```
docker exec clab-multivendor-firewall-zones-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.2.20/
```
```
docker exec clab-multivendor-firewall-zones-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.40.1.10:8080/
```
host-c now gets `http 200`, and `nft list chain inet srx from-dmz-to-untrust` shows `packets 1` on the new policy. Untrust to trust is still closed (`http 000`): opening one direction between two zones never opens the other. (Sample `srx-3-new-zone-pair.pcapng`, recorded on fw's dmz port: host-c's three unanswered SYNs, then, after the change, the full exchange.)

Reset the policy (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `srx-1-zone-pairs.pcapng` | fw:eth2 (untrust) | 27 | host-a to host-b (trust to untrust): a full web exchange; host-b to host-a:8080 (untrust to trust, no policy): three SYNs, no answer; host-b to host-c (untrust to dmz, `web-in`): a full web exchange |
| `srx-2-host-inbound.pcapng` | fw:eth2 (untrust) | 6 | two pings from host-b to fw's own 10.40.2.1, no reply; after ping is allowed in untrust, two pings with replies |
| `srx-3-new-zone-pair.pcapng` | fw:eth3 (dmz) | 15 | host-c to host-b (dmz to untrust): three SYNs, no answer; after `dmz-updates` is added: the full exchange |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic; the display filters `tcp` and `icmp` show each part.

## What this lab does not do

- **No Junos SRX.** The Junos commands are text to compare; their output is not shown, and real SRX features (screens, security logs, NAT rule sets, application identification, routing instances, chassis cluster) are not here.
- No global policies, no policy scheduling, no logging to a log server; counters stand in for `hit-count`.
- No NAT (see `firewall-nat`) and no IPv6 rules: the lab uses IPv4 only.
- A veth pair carries each link; there is no real cable.

Not affiliated with or endorsed by Juniper Networks or the netfilter project. Junos and SRX are trademarks of Juniper Networks. Junos syntax in this folder is text to compare; this lab does not run Junos.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the web servers start after the addresses). Check that the policy is loaded: `docker exec clab-multivendor-firewall-zones-fw nft list map inet srx zone_pair` shows three entries; if not, load it again (`nft -f /neo/configs/srx-zones.nft`, see **Start, reset, stop**).
2. **`nft add chain` says `File exists`, or `add element` says `File exists`.** Exercise 4 (or 3) was already done; reset the policy and start the exercise again.
3. **host-b's ping to 10.40.2.1 was answered before exercise 3.** The change from an earlier try is still there: reset the policy.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-firewall-zones
```
```
containerlab destroy --cleanup -t multivendor-firewall-zones.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-firewall-zones` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-firewall-zones` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-firewall-zones/clab-multivendor-firewall-zones
```
Your capture files in your Home folder are not touched.

