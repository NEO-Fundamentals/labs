# Lab: Palo Alto style security policy: zones, named rules, default rules and commit

**Folder:** `labs/multivendor-firewall-policy/`  **Lab file:** `multivendor-firewall-policy.clab.yml`  **Lesson:** NEO-41 Multi-vendor firewalls: Palo Alto  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables with connection tracking** (the NEO helper image `neo-tools`). Its policy is **laid out the way PAN-OS builds one**: zones as groups of interfaces, one rulebase of named rules read top to bottom, an address object, the two predefined default rules (`intrazone-default` allow, `interzone-default` deny), a policy-match test and a change that is checked and committed as a whole. The rules, counters, trace and session table are real Linux ones. **There is no Palo Alto firewall here** (no PAN-OS image exists for the kit): the PAN-OS commands are shown as text, in `configs/panos-reference.txt` and in the table below. Rules match **ports**, not applications: PAN-OS App-ID identifies an application whatever its port, which a port match cannot do (the `ngfw-inspection` lab shows application identification).

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: five Linux containers, about 11 MB each (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-firewall-policy/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can; `multivendor-firewall-zones` (the Junos SRX way) is the companion lab.

## What this lab builds

```
   host-a (trust)  10.41.1.10 ---- eth1 10.41.1.1 \                     / eth2 10.41.2.1 ---- host-b (untrust) 10.41.2.20
                                                    fw (zones: trust = eth1 + eth4,                  (plays the Internet)
   host-d (trust)  10.41.4.40 ---- eth4 10.41.4.1 /   untrust = eth2, dmz = eth3)
                                                         eth3 10.41.3.1
                                                              |
                                                        host-c (dmz) 10.41.3.30, web :80, ssh :22
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking, policy laid out like PAN-OS. **Zone trust = eth1 (10.41.1.1/24) and eth4 (10.41.4.1/24)**, zone untrust = eth2 (10.41.2.1/24), zone dmz = eth3 (10.41.3.1/24). Loads `configs/panos-rules.nft` at deploy | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-a | trust host 10.41.1.10/24, gateway fw; web server on port 80 | same | Attach Shell |
| host-d | trust host in a **second subnet**, 10.41.4.40/24, gateway fw; web server on port 80 | same | Attach Shell |
| host-b | untrust host 10.41.2.20/24, gateway fw; web server on port 80 | same | Attach Shell |
| host-c | dmz server 10.41.3.30/24, gateway fw; web server on port 80, SSH server on port 22 | same | Attach Shell |

All addresses are private (RFC 1918). The untrust zone **plays** the Internet; the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The policy** (`configs/panos-rules.nft`), PAN-OS idea by PAN-OS idea:

| PAN-OS idea | PAN-OS (text only, `configs/panos-reference.txt`) | In this lab (nftables on fw) |
|---|---|---|
| Zones | `set zone trust network layer3 [ ethernet1/1 ethernet1/4 ]` | sets `zone-trust` (eth1, eth4), `zone-untrust` (eth2), `zone-dmz` (eth3) |
| Address object | `set address web-srv ip-netmask 10.41.3.30/32` | set `web-srv` |
| Security rules | `set rulebase security rules web-to-dmz from untrust to dmz ... action allow` | chain `security-rules`: rules 1 to 3, top to bottom, first match wins; the name is in each rule's comment |
| Service | `service-http`, or `application-default` (the application's usual port) | `tcp dport 80`, `tcp dport 22` |
| Default rules | `intrazone-default` (allow), `interzone-default` (deny), always after the rulebase | the rules after `jump security-rules` in chain `forward` |
| Rule hit count | the Hit Count column, `show rule-hit-count` | `counter packets ...` on each rule |
| Policy match test | `test security-policy-match from trust to dmz ...` | a packet trace: which rule decided |
| Candidate configuration, validate, commit | edit, `validate full`, `commit` | a change file, `nft -c -f` (check only), `nft -f` (all or nothing) |
| Session | `show session all` | connection tracking (`conntrack -L` first, or `/proc/net/nf_conntrack` if that command is missing) |

The rulebase at the start: **rule 1 allow-outbound** (trust to untrust, anything), **rule 2 web-to-dmz** (untrust to dmz, web-srv, port 80), **rule 3 admin-ssh** (trust to dmz, web-srv, port 22). Then the two default rules.

## Files

- `multivendor-firewall-policy.clab.yml` - the lab drawing. Addresses, routes, web servers and the SSH server are set by each node's `exec` lines.
- `configs/panos-rules.nft` - the policy that fw loads at deploy (above). Loading it again replaces the table `inet pan` as a whole (that is how the exercises are undone).
- `configs/panos-reference.txt` - the same zones and rules in PAN-OS `set` commands, plus the change of exercise 4. **Text only**: nothing loads it.
- `changes/candidate-typo.nft` and `changes/candidate.nft` - the change of exercise 4 (two new rules), once with a typo and once correct.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads the deploy policy again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `multivendor-firewall-policy.drawio` and `multivendor-firewall-policy.png` - the prepared diagram.
- `captures/` - three sample captures: `pan-1-intrazone.pcapng`, `pan-2-interzone-deny.pcapng`, `pan-3-commit.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-firewall-policy` > right-click `multivendor-firewall-policy.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-multivendor-firewall-policy-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.2.20/
  ```
  It prints `http 200 in ...`: host-a (trust) reached host-b's web page (untrust) through fw, by rule 1.
- **Reset to the lesson start** (deploy policy, counters at zero):
  ```
  cd ~/labs-main/containerlab/labs/multivendor-firewall-policy
  ```
  ```
  containerlab redeploy -c -t multivendor-firewall-policy.clab.yml
  ```
  Or, quicker, only the policy: `docker exec clab-multivendor-firewall-policy-fw nft -f /neo/configs/panos-rules.nft`.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | PAN-OS (text only) | Here (on fw) |
|---|---|---|
| Which interfaces are in which zone? | `show zone-protection` / the Zones page | `nft list set inet pan zone-trust` (and `zone-untrust`, `zone-dmz`) |
| The rulebase and its hit counts | `show running security-policy`, `show rule-hit-count` | `nft list chain inet pan security-rules` |
| The default rules and their counts | the two grey rules at the bottom of the Security page | `nft list chain inet pan forward` |
| Which rule decides this traffic? | `test security-policy-match ...` | a trace (exercise 3) |
| Check a change without applying it | `validate full` | `nft -c -f <file>` |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-firewall-policy`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Zones are groups of interfaces; the default rules.**
```
docker exec clab-multivendor-firewall-policy-fw nft list set inet pan zone-trust
```
```
docker exec clab-multivendor-firewall-policy-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.4.40/
```
```
docker exec clab-multivendor-firewall-policy-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.1.10/
```
```
docker exec clab-multivendor-firewall-policy-fw nft list chain inet pan forward
```
Zone trust holds **two** interfaces, `"eth1", "eth4"`. host-a (10.41.1.10) to host-d (10.41.4.40) gets `http 200`, although no rule in the rulebase mentions it: the traffic crosses fw (two subnets) but stays **inside one zone**, and the predefined **`intrazone-default`** rule allows it (`intrazone-default: same zone (trust), allow` counts 1). host-b to host-a gets `http 000`: untrust to trust matches no rule, and **`interzone-default`** denies it (`packets 3`, the three SYNs). Every PAN-OS policy ends with these two rules; they are why "same zone" traffic is allowed and "zone to zone" traffic is denied unless a rule says otherwise. (Samples `pan-1-intrazone.pcapng`, recorded on fw's eth4: host-a's full exchange with host-d; `pan-2-interzone-deny.pcapng`, on fw's eth2: host-b's three unanswered SYNs to host-a, then host-b to host-c by rule 2.)

**2. The rulebase, top to bottom, with hit counts.**
```
docker exec clab-multivendor-firewall-policy-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.3.30/
```
```
docker exec clab-multivendor-firewall-policy-host-a nc -w 2 10.41.3.30 22
```
```
docker exec clab-multivendor-firewall-policy-host-b nc -w 2 10.41.3.30 22
```
```
docker exec clab-multivendor-firewall-policy-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.3.30/
```
```
docker exec clab-multivendor-firewall-policy-fw nft list chain inet pan security-rules
```
host-b reaches host-c's web page (`http 200`, rule 2 web-to-dmz). host-a reaches host-c's SSH server: `nc` prints the server's greeting `SSH-2.0-OpenSSH_9.2p1 ...` (rule 3 admin-ssh). host-b gets nothing on port 22 (rule 3 is for trust only; exit 1 after 2 seconds). And host-a gets `http 000` from host-c's **web** server: rule 2 is from untrust, rule 3 is port 22, so nothing in the rulebase allows trust to dmz on port 80. The hit counts show it: rules 1, 2 and 3 have counted, and the denied requests went to `interzone-default`. A rule is a full sentence: from zone, to zone, source, destination, service, action; change one word and it no longer matches.

**3. Which rule decides? A policy-match test.** PAN-OS answers this with `test security-policy-match`; here a packet **trace** shows each rule the packet meets. Mark traffic from host-a to host-c for tracing:
```
docker exec clab-multivendor-firewall-policy-fw nft add element inet pan trace-these '{ 10.41.1.10 . 10.41.3.30 }'
```
Start the trace in a second terminal (it stops by itself after 20 seconds):
```
docker exec clab-multivendor-firewall-policy-fw sh -c "timeout 20 nft monitor trace | grep --line-buffered -E 'forward rule|security-rules rule|forward policy'"
```
In the first terminal:
```
docker exec clab-multivendor-firewall-policy-host-a curl -s -m 2 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.3.30/
```
For each SYN the trace prints `inet pan forward rule jump security-rules`, then **no line from `security-rules`** (no rule there matched, so the packet came back), then `rule counter ... comment "interzone-default: different zones, deny" (verdict continue)` and `inet pan forward policy drop`. That is the answer PAN-OS would give: `interzone-default`, deny.

**4. A change as a candidate: validate, then commit.** On PAN-OS you edit a **candidate configuration**; nothing changes on the firewall until you **commit**, and a commit that fails validation changes nothing at all. The change here adds two rules at the bottom of the rulebase: rule 4 web-from-trust (trust to dmz, web-srv, port 80) and rule 5 dmz-updates (dmz to untrust, port 80). First the version with a typo, checked only (`-c`):
```
docker exec -i clab-multivendor-firewall-policy-fw nft -c -f - < changes/candidate-typo.nft
```
Now load it for real:
```
docker exec -i clab-multivendor-firewall-policy-fw nft -f - < changes/candidate-typo.nft
```
```
docker exec clab-multivendor-firewall-policy-fw nft list chain inet pan security-rules
```
Both print `Error: No such file or directory; did you mean set 'zone-untrust' in table inet 'pan'?` and point at `@zone-untrsut` in the second rule. The rulebase still has **three** rules: rule 4 had no error, but the file is loaded **all or nothing**, like a commit. Now the corrected file, checked, then committed:
```
docker exec -i clab-multivendor-firewall-policy-fw nft -c -f - < changes/candidate.nft
```
```
docker exec -i clab-multivendor-firewall-policy-fw nft -f - < changes/candidate.nft
```
```
docker exec clab-multivendor-firewall-policy-host-a curl -s -m 2 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.3.30/
```
```
docker exec clab-multivendor-firewall-policy-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.41.2.20/
```
```
docker exec clab-multivendor-firewall-policy-fw nft list chain inet pan security-rules
```
The check prints nothing (no error), the commit prints nothing, and the rulebase now lists rules 1 to 5. host-a reaches host-c's web page (`http 200`, rule 4 counts 1) and host-c reaches host-b's (`http 200`, rule 5). New rules went to the **bottom** of the rulebase, above the default rules, as on PAN-OS; a rule that must win over an earlier one has to be moved up. Run the trace of exercise 3 again if you like: the SYN now ends at `security-rules rule ... "rule 4 web-from-trust ..." (verdict accept)`. (Sample `pan-3-commit.pcapng`, recorded on fw's eth1: host-a's three unanswered SYNs to host-c, the commit, then the full exchange.)

Reset the policy (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `pan-1-intrazone.pcapng` | fw:eth4 (trust, host-d's subnet) | 15 | fw's ARP for host-d, then host-a (10.41.1.10) to host-d (10.41.4.40): the full web exchange, allowed by `intrazone-default` |
| `pan-2-interzone-deny.pcapng` | fw:eth2 (untrust) | 15 | host-b to host-a: three SYNs, no answer (`interzone-default`); host-b to host-c: the full exchange (rule 2) |
| `pan-3-commit.pcapng` | fw:eth1 (trust, host-a) | 15 | host-a to host-c port 80: three SYNs, no answer; after the commit: the full exchange (rule 4) |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic; the display filter `tcp` shows each part.

## What this lab does not do

- **No PAN-OS.** The PAN-OS commands are text to compare; their output is not shown, and real PAN-OS features (App-ID, Content-ID, User-ID, security profiles, Panorama, the web interface, commit locks, rule tags and log forwarding) are not here.
- Rules match ports, not applications (see the note at the top).
- No NAT rules (see `firewall-nat`) and no IPv6 rules: the lab uses IPv4 only.
- A veth pair carries each link; there is no real cable.

Not affiliated with or endorsed by Palo Alto Networks or the netfilter project. Palo Alto, PAN-OS and App-ID are trademarks of Palo Alto Networks. PAN-OS syntax in this folder is text to compare; this lab does not run PAN-OS.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the web servers start after the addresses). Check that the policy is loaded: `docker exec clab-multivendor-firewall-policy-fw nft list chain inet pan security-rules` shows three rules; if not, load it again (see **Start, reset, stop**).
2. **`nft -f` says `No such file or directory` for `changes/...`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/multivendor-firewall-policy`) so that `changes/...` is found.
3. **The rulebase has more than five rules.** `candidate.nft` was loaded twice (each load adds its two rules again). Reset the policy.
4. **The trace prints nothing.** Add the trace element first, and send traffic within the 20 seconds the trace runs.
5. **`nc` to port 22 prints nothing from host-a.** Wait a few seconds after the deploy (the SSH server starts after its keys are made) and try again.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-firewall-policy
```
```
containerlab destroy --cleanup -t multivendor-firewall-policy.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-firewall-policy` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-firewall-policy` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-firewall-policy/clab-multivendor-firewall-policy
```
Your capture files in your Home folder are not touched.

