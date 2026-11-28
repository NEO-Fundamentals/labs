# Lab: Wireshark practice, captures with real faults to filter and read

**Folder:** `labs/wireshark-practice/`  **Lab file:** `wireshark-practice.clab.yml`  **Lesson:** NEO-03 Wireshark for troubleshooting  **Lab version:** 1.0.1 (2026-11-27, kit 1.2.3: zero-window and mid-transfer reset samples re-recorded (one connection each), MTU sample row explained, profile note updated; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.0.0)


This lab is the TCP troubleshooting lab (same three nodes, same six faults) plus a small DNS server on host-b. It is here as its own folder so the Wireshark lesson has everything in one place: the lab, the captures, the display filters and the diagnostic color profile.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/wireshark-practice/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads). You can open the captures in `captures/` without deploying the lab at all.
- **Addresses:** this lab uses 10.0.2.x on its own cables. Your VM's VirtualBox network uses the same range (`ip addr` on the VM shows 10.0.2.15/24 on its main interface). They are separate networks that share a number range; use only the lab addresses in this README in the exercises.

## What this lab builds

```
 host-a                    r1                       host-b
 10.0.2.10/24  ---  FRR router  ---  172.16.100.20/24
 (client)      10.0.2.1  172.16.100.1   (test server on 8080, 8082, 8083, 8085; DNS on 53)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux client. It makes the traffic you capture | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router. It only routes; the MTU fault is set on its link to host-b | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| host-b | Linux server: `scripts/tcp-server.py` plus dnsmasq (DNS for `lab.example`) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `wireshark-practice.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1's addresses. `configs/host-b/dnsmasq.conf` - the DNS server.
- `scripts/tcp-server.py` - the TCP test server. `scripts/faults.sh` - switches the `drop`, `loss` and `mtu` faults. `scripts/make-captures.sh` - records every capture below. Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.
- `wireshark/NEO_Diagnostics_profile.zip` - the diagnostic color profile and filter buttons used in the lesson.
- `wireshark-practice.drawio` and `wireshark-practice.png` - the prepared diagram.
- `captures/` - recorded from this lab on the VM (only the first 200 bytes of each packet are kept, so the files are small): `tcp-lab-run1-normal`, `tcp-fault-drop`, `tcp-fault-reject`, `tcp-fault-loss`, `tcp-fault-zerowin`, `tcp-fault-mtu`, `tcp-fault-midrst`, `dns-rcode` (`.pcapng`). `tcp-fault-zerowin` and `tcp-fault-midrst` were re-recorded for kit 1.2.3 with this lab on a Linux test machine (not the VM), so each holds only its own connection.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `wireshark-practice` > right-click `wireshark-practice.clab.yml` > **Deploy**. Wait for the three green dots, then about 10 more seconds for r1 to load its addresses. Run one lab at a time.
- **Reset (also clears every fault):** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/wireshark-practice
  ```
  ```
  containerlab redeploy -c -t wireshark-practice.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Get the captures

Either open the files already in `captures/`, or record your own. To re-record all of them, in the lab folder:
```
sudo bash scripts/make-captures.sh
```
It asks for your password and takes about two minutes. To record one run by hand, start the capture first, in Ubuntu's Terminal app:
```
sudo containerlab capture --name wireshark-practice --target host-a:eth1 --duration 15s -w - > "$HOME/neo-my-run.pcapng"
```
and generate traffic in a second window, for example:
```
docker exec clab-wireshark-practice-host-a sh -c "nc -w 5 172.16.100.20 8080 | wc -c"
```

## Load the color profile

In Wireshark: **Edit > Configuration Profiles... > Import > From zip file...** and choose `wireshark/NEO_Diagnostics_profile.zip`. Select the **NEO_Diagnostics** profile (bottom-right of the Wireshark window). Faults are warm colors, normal traffic is dark or pale. The toolbar gets buttons: RST, Retrans, ZeroWin, DNS err, High delta, TCP analysis, SYNs. A Delta column shows the gap to the previous packet.

## What to look for in each capture

| Capture | Cause in the lab | Filter to try | What you see |
|---|---|---|---|
| `tcp-lab-run1-normal` | port 8080, no fault | `tcp.stream eq 0` | handshake, 200,000 bytes, FIN exchange. Expert Info lists two warnings, both in frames 24-26: host-b fills host-a's receive window (`[TCP Window Full]`), host-a advertises a window of 0 (`[TCP ZeroWindow]`, so the **ZeroWin** button and its color match one frame), and about 3 ms later reopens it (`[TCP Window Update]`). The receiving program paused for a moment; the transfer goes on at once. That is normal, not a fault: compare `tcp-fault-zerowin`, where the window stays at 0 |
| `tcp-fault-drop` | filter on host-b discards port 8080 | `tcp.analysis.retransmission` or the **High delta** button | the same SYN again about once a second five times, then after 2 seconds (the wait keeps doubling); no reply |
| `tcp-fault-reject` | nothing listens on 8081 | `tcp.flags.reset == 1` (the **RST** button) | SYN, then an immediate RST,ACK |
| `tcp-fault-loss` | netem loses 25% on host-b | `tcp.analysis.flags`, `tcp.analysis.retransmission` | retransmissions and duplicate ACKs; the transfer still completes |
| `tcp-fault-zerowin` | host-b never reads on 8082 | `tcp.analysis.zero_window` (the **ZeroWin** button) | window drops to 0; host-a's small probes show as `[TCP Keep-Alive]` |
| `tcp-fault-mtu` | r1's link to host-b is MTU 600 | `tcp.analysis.retransmission`, `icmp` | handshake works; the same large data packet repeats, with growing gaps; no ICMP comes back. In the sample the fault was switched off at about 13 s while the recording still ran, so frames 17-37 show the transfer recovering (Dup ACK, Fast Retransmission, then the close). `scripts/make-captures.sh` now switches it off after the recording ends, so a file you record stops before that |
| `tcp-fault-midrst` | host-b resets on 8083 | `tcp.flags.reset == 1` | data, then RST instead of FIN |
| `dns-rcode` | dnsmasq on host-b | `dns.flags.rcode != 0` (the **DNS err** button) | `www.lab.example` answers; `nosuch.lab.example` gives No such name (NXDOMAIN); `www.example.org` is Refused |

Then open **Analyze > Expert Information** on each file and match every entry to a row above (the two short warnings in `tcp-lab-run1-normal` are explained in its row). The method: say what you expect, filter for it, and read the first packet that breaks the expectation.

## Switch faults on and off yourself

From the lab folder: `bash scripts/faults.sh drop on` (and `off`), likewise `loss` and `mtu`. The commands to generate each fault's traffic are in `scripts/make-captures.sh`; the same six faults are explained step by step in the TCP troubleshooting lab (`labs/tcp-troubleshooting/`).

## Troubleshooting

1. **You only want to read the captures.** You do not need to deploy anything: open the files in `captures/` in Wireshark.
2. **The colors look normal after importing the profile.** Select the profile at the bottom right of the Wireshark window (**NEO_Diagnostics**); importing alone does not switch to it. The profile is not needed to read the captures.
3. **`sudo bash scripts/make-captures.sh` fails or `bash scripts/faults.sh` says `No such file`.** Run the lab first (Deploy, then wait about 30 seconds) and run the script from the lab folder: `cd ~/labs-main/containerlab/labs/wireshark-practice`.
4. **A fault stays switched on.** Switch it off with `bash scripts/faults.sh <drop|loss|mtu> off`, or reset with `containerlab redeploy -c -t wireshark-practice.clab.yml`.
5. **`faults.sh` prints `TC classifier not found` or `Specified qdisc kind is unknown`.** That Linux kernel has no traffic-control filters or `netem`, so the `drop`, `loss` and `mtu` faults cannot switch on (and `scripts/make-captures.sh` marks those three captures `FAIL` and keeps the old samples). The NEO VM's Ubuntu kernel has them; run the lab there.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/wireshark-practice
```
```
containerlab destroy --cleanup -t wireshark-practice.clab.yml
```
`--cleanup` also removes the generated `clab-wireshark-practice` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-wireshark-practice` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/wireshark-practice/clab-wireshark-practice
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- The DNS server answers `NXDOMAIN` and `REFUSED`; a SERVFAIL (server failure) is not reproduced here.
- No firewall or middlebox: the silent drop is a filter on host-b, and the mid-session reset comes from host-b.
