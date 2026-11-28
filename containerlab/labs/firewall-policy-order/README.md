# Lab: Policy rules: order, objects, shadowed and broad rules, logging

**Folder:** `labs/firewall-policy-order/`  **Lab file:** `firewall-policy-order.clab.yml`  **Lesson:** NEO-14 Security policy rules: order, objects and groups, shadowed and overly broad rules, and logging  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the firewall `fw` is a Linux router running **nftables with connection tracking** (the NEO helper image `neo-tools`). Its rule order, named sets (objects), counters, drop record and kernel log lines are real. It is a Linux packet filter, **not a commercial firewall product**: there is no Palo Alto, Fortinet, Cisco or Juniper firewall here, and their policy screens and syntax differ (the lesson shows them as text). The layout is the one from `firewall-zones` (NEO-13), with its own addresses.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: four Linux containers, about 11 MB each (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/firewall-policy-order/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.
- **Do `firewall-zones` first** if you can: this lab assumes you know zones, default deny and `ct state`.

## What this lab builds

```
   host-a (inside)                fw                  host-b (outside)
   10.14.1.10  ---- eth1 10.14.1.1    10.14.2.1 eth2 ---- 10.14.2.20
   web :8080                nftables + conntrack          web :80  (plays the Internet)
                           10.14.3.1 eth3
                                 |
                           host-c (dmz)
                           10.14.3.30 and 10.14.3.31, web :80
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| fw | Linux router with nftables and connection tracking. **eth1 = inside** (10.14.1.1/24), **eth2 = outside** (10.14.2.1/24), **eth3 = dmz** (10.14.3.1/24). Loads `configs/policy-v1.nft` at deploy | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| host-a | inside host 10.14.1.10/24, gateway fw; web server on **port 8080** | same | Attach Shell |
| host-b | outside host 10.14.2.20/24, gateway fw; web server on port 80 | same | Attach Shell |
| host-c | dmz server with two addresses, 10.14.3.30/24 and 10.14.3.31/24 (two "servers" for the objects exercise), gateway fw; web server on port 80 | same | Attach Shell |

All addresses are private (RFC 1918). The outside zone **plays** the Internet; the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**Policy v1** (`configs/policy-v1.nft`), read top to bottom; the first rule with a verdict that matches decides:

| Rule | Match | Verdict | Meaning |
|---|---|---|---|
| replies | `ct state established,related` | accept | packets of connections already allowed |
| R10 | `iifname "eth1" oifname "eth2" ct state new` | accept | inside may start connections to outside |
| R20 | `oifname "eth3" ip daddr @web_servers tcp dport { 80, 443 } ct state new` | accept | anyone may reach the web servers (the object `web_servers` = { 10.14.3.30 }) on 80 and 443 |
| R30 | `iifname "eth2" ip saddr 10.14.2.20 oifname "eth3" tcp dport 80` | drop | meant to keep host-b away from the dmz web servers |
| cleanup | `counter` + chain `policy drop` | (count, then drop) | default deny |

The rules only touch traffic that **passes through** fw (the `forward` hook); the hosts and fw themselves are not filtered.

## Files

- `firewall-policy-order.clab.yml` - the lab drawing. Addresses, routes and web servers are set by each node's `exec` lines.
- `configs/policy-v1.nft` - policy v1, loaded by fw at deploy.
- `changes/` - loaded with `docker exec -i clab-firewall-policy-order-fw nft -f - < changes/<file>`:
  - `policy-v1.nft` (back to v1), `policy-v2-reordered.nft` (R30 moved above R20) and `policy-v3-logging.nft` (v2 with a drop record and a log rule at the cleanup step) each replace the table `inet fw` as a whole, so all counters start again at zero;
  - `any-any.nft` inserts one "temporary" accept-everything rule at the top; `reject-toward-inside.nft` adds a reject rule at the end. These two change the loaded policy instead of replacing it.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads policy v1 again at the end, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `firewall-policy-order.drawio` and `firewall-policy-order.png` - the prepared diagram.
- `captures/` - three sample captures: `fwpol-1-shadowed.pcapng`, `fwpol-2-reordered.pcapng`, `fwpol-3-drop-then-reject.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `firewall-policy-order` > right-click `firewall-policy-order.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-firewall-policy-order-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.2.20/
  ```
  It prints `http 200 in ...`: host-a (inside) reached host-b's web page (outside) through fw.
- **Reset to the lesson start** (policy v1, counters at zero):
  ```
  cd ~/labs-main/containerlab/labs/firewall-policy-order
  ```
  ```
  containerlab redeploy -c -t firewall-policy-order.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Task | On fw (Linux, nftables) |
|---|---|
| The policy, with a counter per rule | `nft list table inet fw` |
| The rules with their handles (numbers used to delete or insert one rule) | `nft -a list chain inet fw forward` |
| Delete one rule | `nft delete rule inet fw forward handle <number>` |
| Show an object (named set) | `nft list set inet fw web_servers` |
| Add a member to an object | `nft add element inet fw web_servers '{ <address> }'` |
| Load a policy from a file | `nft -f <file>` (here: `docker exec -i clab-firewall-policy-order-fw nft -f - < changes/<file>`) |
| The drop record (policy v3) | `nft list set inet fw denied` |
| The kernel log lines (policy v3; see exercise 6) | on the VM: `sudo dmesg \| grep fw14-deny` |
| Wireshark filter | `tcp.port == 80 or tcp.port == 8080` |

`nft list ruleset` also shows a table `ip nat` with a warning: that table belongs to Docker (it makes name lookups work inside the container). Leave it alone; this lab's rules are all in `inet fw`.

The web test used in every exercise prints the HTTP status and the time: `http 200` is a page; **`http 000 in 3.0 s`** is no answer within the 3-second limit (curl exit code 28); **`http 000 in 0.000... s`** is an immediate refusal (exit code 7).

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-policy-order`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Read the policy and its object.**
```
docker exec clab-firewall-policy-order-fw nft list table inet fw
```
```
docker exec clab-firewall-policy-order-fw nft list set inet fw web_servers
```
Five rules in the order of the table above, each with `counter packets 0` except `replies` and R10 (the Start check). The set `web_servers` holds one address, `10.14.3.30`. R20 does not name an address; it names the object.

**2. First match wins: a shadowed rule.** R30 says "drop host-b to the dmz web". Test it:
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30/
```
```
docker exec clab-firewall-policy-order-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30/
```
```
docker exec clab-firewall-policy-order-fw nft list chain inet fw forward
```
Both `http 200`. R20 counted **2** packets (one SYN from host-b, one from host-a) and R30 counted **0**: host-b's SYN matched R20 first and was accepted, so R30 was never reached. A rule that can never match because a broader rule above it already decides is **shadowed**. (Sample `fwpol-1-shadowed.pcapng`: host-b's whole web request on the dmz side.)

**3. Fix the order.** Policy v2 is the same five rules with R30 **above** R20:
```
docker exec -i clab-firewall-policy-order-fw nft -f - < changes/policy-v2-reordered.nft
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30/
```
```
docker exec clab-firewall-policy-order-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30/
```
```
docker exec clab-firewall-policy-order-fw nft list chain inet fw forward
```
host-b: `http 000 in 3.0 s`, R30 counted **3** (the SYN and two retries). host-a: still `http 200`, R20 counted 1. The rule set did not change, only the order. Put specific rules (deny host-b) above general ones (allow everyone). (Sample `fwpol-2-reordered.pcapng`: host-b's three SYNs on the outside port, no answer.)

**4. Objects: change the group, not the rules.** A second web server, 10.14.3.31, is not in the object yet:
```
docker exec clab-firewall-policy-order-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.31/
```
`http 000`: no rule allows it. Add it to the object:
```
docker exec clab-firewall-policy-order-fw nft add element inet fw web_servers '{ 10.14.3.31 }'
```
```
docker exec clab-firewall-policy-order-host-a curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.31/
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.31/
```
host-a: `http 200` (R20 now covers .31). host-b: `http 000`: R30 (above R20 since exercise 3) blocks host-b to any dmz port 80. `nft list set inet fw web_servers` now shows `{ 10.14.3.30, 10.14.3.31 }`. Every rule that uses the object changed at once; no rule was edited.

**5. An overly broad rule: "temporary" any-any.**
```
docker exec -i clab-firewall-policy-order-fw nft -f - < changes/any-any.nft
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
```
docker exec clab-firewall-policy-order-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30/
```
All three `http 200`: the outside and the dmz now reach the inside host, and R30 no longer stops host-b. List the chain with handles:
```
docker exec clab-firewall-policy-order-fw nft -a list chain inet fw forward
```
The TEMP rule is first and counts every packet (box: 36); the rules below it stop counting. Each line ends with `# handle <number>`; the TEMP rule's handle was **9** on the box (use the number you see). Delete exactly that rule:
```
docker exec clab-firewall-policy-order-fw nft delete rule inet fw forward handle 9
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
`http 000` again. A broad rule high in the list quietly undoes every rule below it.

**6. Logging the cleanup rule.** Policy v3 is v2 plus two lines at the end: every denied TCP flow is recorded in the set `denied` (the lab's **drop record**: source, destination, port and a packet count, kept for an hour), and a `log` rule writes one kernel log line per denied packet with the prefix `fw14-deny`.
```
docker exec -i clab-firewall-policy-order-fw nft -f - < changes/policy-v3-logging.nft
```
Three attempts that no rule allows:
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
```
docker exec clab-firewall-policy-order-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:22/
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.3.30:8443/
```
```
docker exec clab-firewall-policy-order-fw nft list set inet fw denied
```
Three entries, one per flow: `10.14.2.20 . 10.14.1.10 . 8080`, `10.14.3.30 . 10.14.1.10 . 22` and `10.14.2.20 . 10.14.3.30 . 8443`, each `counter packets 3`. The log rule counted 9. (host-b to 10.14.3.30 port 80 would not appear: R30 drops it before the cleanup step. A firewall logs what the rule that decides is set to log.)

**Kernel log (optional).** Linux hides log lines from containers unless the VM allows them. Allow them, try once more, read the log, and switch it back off:
```
sudo sysctl -w net.netfilter.nf_log_all_netns=1
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
```
sudo dmesg | grep fw14-deny | tail -3
```
```
sudo sysctl -w net.netfilter.nf_log_all_netns=0
```
Three lines like `fw14-deny IN=eth2 OUT=eth1 ... SRC=10.14.2.20 DST=10.14.1.10 ... PROTO=TCP SPT=... DPT=8080 ... SYN`: the same flow, as a firewall's traffic log shows it (in, out, source, destination, port). The setting is for the whole VM; the last command puts it back.

**7. Drop or reject.** With drop, host-b waits for the timeout:
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
`http 000 in 3.0 s`. Add a reject rule toward inside at the end of the chain and try again from outside and from the dmz:
```
docker exec -i clab-firewall-policy-order-fw nft -f - < changes/reject-toward-inside.nft
```
```
docker exec clab-firewall-policy-order-host-b curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
```
docker exec clab-firewall-policy-order-host-c curl -s -m 3 -o /dev/null -w 'http %{http_code} in %{time_total} s\n' http://10.14.1.10:8080/
```
Both `http 000 in 0.0001 s` (curl exit 7): fw answered the SYN with a TCP reset at once. Reject is quicker for your own users to diagnose; drop gives a scanner nothing. host-b to 10.14.3.30 still waits 3 s: R30 drops before the reject rule is reached. (Sample `fwpol-3-drop-then-reject.pcapng`: three silent SYNs, then one SYN answered by `RST, ACK`. The reset carries host-a's address as its source: fw sends it **as if** from the destination.)

Reset the lab (see **Start, reset, stop**) to go back to policy v1.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `fwpol-1-shadowed.pcapng` | fw:eth3 (dmz) | 16 | policy v1: host-b's whole web request to 10.14.3.30 (handshake, GET, 200 OK, close) reaches the dmz although R30 says drop; then an ARP exchange |
| `fwpol-2-reordered.pcapng` | fw:eth2 (outside) | 3 | policy v2: host-b's SYN to 10.14.3.30:80 and two retries, one second apart; nothing comes back |
| `fwpol-3-drop-then-reject.pcapng` | fw:eth2 (outside) | 5 | policy v3: host-b's SYN to 10.14.1.10:8080 and two retries (dropped, silence); then, with `reject-toward-inside.nft` added, a new SYN answered at once by `RST, ACK` |

Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic (router solicitations, multicast listener reports) and ARP; the display filter `ip` hides them.

## What this lab does not do

- No commercial firewall: no policy GUI, no rule hit-count screen, no shadow-rule analyser, no application or user objects. The lesson shows vendor screens as text. Rule hit counts here are nftables counters.
- Logging is the kernel log (one line per packet) plus a counted drop record; there is no log server, no session-end log and no log search. The kernel log needs the VM setting shown in exercise 6.
- No NAT (see `firewall-nat`) and no IPv6 rules: the lab uses IPv4 only.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **The check in Start says `http 000`.** Wait 10 seconds and try again (the web servers start after the addresses). Check that policy v1 is loaded: `docker exec clab-firewall-policy-order-fw nft list table inet fw` shows the set and five rules. If you loaded another policy, load `changes/policy-v1.nft` again or reset the lab.
2. **`nft -f` says `No such file or directory`.** Run it from the lab folder (`cd ~/labs-main/containerlab/labs/firewall-policy-order`) so that `changes/...` is found.
3. **`nft delete rule ... handle 9` says `No such file or directory`.** The handle is different in your run: list the chain with `nft -a` and use the number at the end of the TEMP line.
4. **`sudo dmesg | grep fw14-deny` prints nothing.** Check that policy v3 is loaded and that `sudo sysctl net.netfilter.nf_log_all_netns` says `1` **before** you send the traffic.
5. **Exercise 4 gives `http 200` for host-b to 10.14.3.31.** Policy v1 is loaded (R30 is still shadowed there). Load `changes/policy-v2-reordered.nft` (exercise 3) first.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/firewall-policy-order
```
```
containerlab destroy --cleanup -t firewall-policy-order.clab.yml
```
`--cleanup` also removes the generated `clab-firewall-policy-order` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-firewall-policy-order` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/firewall-policy-order/clab-firewall-policy-order
```
Your capture files in your Home folder are not touched.

