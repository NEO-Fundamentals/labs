# NEO Fundamentals labs (Containerlab kit)

**Kit version:** 1.2.1  **Date:** 2026-11-26  **Status:** current

One download holds every lesson lab. Each video tells you which folder to open.
You run the labs from **VS Code** inside your Ubuntu 24.04 lab VM. New to this? Follow the beginner guide: **NEO-Containerlab-Beginner-Guide.pdf** (this folder). It goes step by step with screenshots, from an empty computer to a running lab.

**Beginner guide:** `NEO-Containerlab-Beginner-Guide.pdf` (this folder), guide version 1.3.3 for kit 1.2.0 (applies to later 1.2.x kits)

**All labs:** see [LABS.md](LABS.md) for the list with a one-line description of each, or the table below.

## Lesson index

| Lesson | Folder | What it builds | Images needed | Tested |
|---|---|---|---|---|
| NEO-48 Build Your Own NEO Lab | `labs/ebgp-two-sites/` | Two sites joined by eBGP: Nokia SR Linux (edge-a, AS 65201), FRR (edge-b, AS 65202), two Linux PCs | Free, downloaded automatically | Yes (Ubuntu 24.04, Containerlab 0.83.0, VS Code extension 0.28.0, Wireshark 4.2.2) |
| NEO-01 TCP Basics | `labs/tcp-basics/` | A client, an FRR router and a server: a TCP connection that works, one that is refused and one that is silently dropped | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-45 The OSI Model | `labs/osi-http-capture/` | A PC loads a web page by name through one router (DNS and HTTP); capture it and find each layer | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-11 BGP: What It Is, eBGP and iBGP, and Path Choice | `labs/bgp-ebgp-ibgp-path-choice/` | SR Linux (AS 65201) peers with two FRR routers (AS 65202) that also peer with each other; see why one path wins | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-32 Multi-vendor eBGP | `labs/multivendor-ebgp/` | The same eBGP session on SR Linux and FRR side by side (Arista EOS and Juniper Junos shown as text) | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-02 TCP Troubleshooting | `labs/tcp-troubleshooting/` | Six TCP faults you switch on and off: silent drop, refused, packet loss, zero window, MTU black hole, reset in the middle | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-03 Wireshark for troubleshooting | `labs/wireshark-practice/` | The same faults plus a DNS server, with a Wireshark color profile and a table of which filter finds which fault | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0); the color-profile import was not tested |
| NEO-05 IPv4 subnetting and CIDR | `labs/subnetting-gateway/` | Three hosts and an FRR router in two /26 subnets on one switch; same-subnet versus gateway delivery | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |
| NEO-34 Multi-vendor interface addressing and show commands | `labs/multivendor-interfaces/` | Two FRR routers on a /30: read address and state, then break it with a typo and a shutdown (Junos and EOS shown as text) | Free, downloaded automatically | Yes (VirtualBox VM, Ubuntu 24.04, Containerlab 0.83.0) |

More lessons are added as new folders under `labs/`. [LABS.md](LABS.md) and the CHANGELOG below list every change. Each lab's README has **Before you start**, **Troubleshooting** and **Cleanup** sections.

## How to start a lesson (short version)

Type or paste commands **one line at a time**. If the terminal shows `>` and waits, press **Ctrl+C** and paste the single line again.

0. **Get the files:** on github.com/NEO-Fundamentals/labs click the green **Code** button > **Download ZIP** (not the older Getting Started ZIP linked lower on the front page). Extract `labs-main.zip` to your Home folder. This folder is then `~/labs-main/containerlab`.
1. **Check Docker first** (after the setup and one log out / log in). This must work without `sudo`; a header line with no rows is a pass:
   ```
   docker ps
   ```
2. In VS Code, open the kit folder (**File > Open Folder** > `labs-main` > `containerlab`) and click **Trust**. Trust only this folder, not your whole Home folder.
3. Click the **Containerlab** icon on the left. Your lesson's `.clab.yml` file is under **Undeployed Local Labs** (for NEO-48: `labs/ebgp-two-sites/ebgp-two-sites.clab.yml`).
4. Right-click it > **Deploy**. The first deploy downloads the router images (about 3 GB) from the internet and can take 5 to 15 minutes. After that, lab traffic stays on the virtual links inside the VM. **Then wait about a minute** before you ping: green dots don't mean BGP is up yet. Checkpoint (in Ubuntu's Terminal): the line below must show `1` under State/PfxRcd for neighbor 10.0.12.1.
   ```
   docker exec clab-ebgp-two-sites-edge-b vtysh -c "show bgp summary"
   ```
5. Log in to a device: right-click it under **Running Labs** > **Access** > **Attach Shell**. (edge-a appears twice; the second one is an internal SR Linux helper, so ignore it.)
6. **After you edit a config file**, restart the lab with a clean redeploy in VS Code's terminal (**Terminal > New Terminal**), one line at a time:
   ```
   cd ~/labs-main/containerlab/labs/<lesson-folder>
   ```
   ```
   containerlab redeploy -c -t <lab-file>.clab.yml
   ```
   `-c` throws away the routers' saved configs so your edit is used. Don't use **Redeploy (Cleanup)** from the right-click menu; in our tests it closed VS Code.
7. **After a VM restart** (Ubuntu shows the login screen first), check that every device has a green dot before anything else. edge-b (FRR) is always the one left stopped. Run `containerlab redeploy -t <lab-file>.clab.yml` (no `-c`) in the lab folder; that keeps the saved configs. It prints two long red `ERRO container ... edge-b exited` blocks first. That's expected; it still succeeds. Wait about a minute for BGP, then re-check.
8. **Stop:** right-click the running lab > **Destroy**. Plain **Destroy** leaves the folder Containerlab generated for the lab (`clab-<lab-name>`, owned by root); **Destroy (Cleanup)** removes it. Your lab files and your capture files in Home stay either way.

**Wireshark capture (main method): record to a file, then open it.** In Ubuntu's Terminal app (not VS Code), for example:
```
sudo containerlab capture --name ebgp-two-sites --target edge-b:eth1 --duration 45s -w - > "$HOME/neo-wan-test.pcapng"
```
The terminal stays quiet for 45 seconds; that's normal. While it runs, ping from a second Terminal window. Then open Wireshark, **File > Open...** > Home > `neo-wan-test.pcapng`, and filter on `icmp`: the file holds about 14 frames (ARP, BGP keepalives, LLDP and IPv6 router solicitation too), and the filter shows exactly the 6 pings. Use a new file name each time, and keep captures in Home, never inside the generated `clab-*` folder. You need the `wireshark` group (`sudo usermod -aG wireshark $USER`, then log out and back in).
Optional shortcut: right-click an interface under a running device > **Capture With Wireshark**. On some systems the Wireshark window crashes at once (a GLib "antialiasing" error); if so, use the file method.

Diagram: `containerlab graph --drawio -t <lab-file>.clab.yml`, then `sudo chown $USER:$USER <lab-file>.clab.drawio`, then click the `.drawio` file to edit it in Draw.io Integration.

## Getting the latest labs

New labs are added over time. Compare the **Kit version** line at the top of this file with the one in the `containerlab` folder on GitHub (github.com/NEO-Fundamentals/labs). If GitHub's is newer:
- **Beginners:** rename your old `labs-main` folder if you want to keep your edits, then on the repository page click **Code > Download ZIP** and unzip `labs-main.zip` to your Home folder.
- **git users:** run `git pull` inside your clone.

## Rules for this kit

- Lab addresses are private only: IPv4 from RFC 1918 (such as 10.x and 192.168.x), management IPv6 from the private ULA range fd00::/8 (the lab uses fd00:172:20:20::/64), and AS numbers from the private ranges 64512-65534 and 4200000000-4294967294. The documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, 2001:db8::/32, 3fff::/20) are never used.
- No vendor software is stored here. Every lab uses only free public images (Nokia SR Linux, FRR, network-multitool), which download from the vendors' public registries the first time you deploy. No vendor account is needed.
- Arista EOS and Juniper Junos are compared on screen in the videos only. This kit has no labs for them.

## CHANGELOG

### 1.2.1 (2026-11-26)
- Four more labs: `tcp-troubleshooting` (NEO-02), `wireshark-practice` (NEO-03), `subnetting-gateway` (NEO-05) and `multivendor-interfaces` (NEO-34). They were tested on a VirtualBox VM with real sample captures. The Wireshark color-profile import (`wireshark-practice/wireshark/NEO_Diagnostics_profile.zip`) was not tested in the Wireshark window.
- [LABS.md](LABS.md) and the lesson index list nine labs. The beginner guide is unchanged (1.3.3).

### 1.2.0 (2026-11-26)
- Four new labs, each a self-contained folder under `labs/` (lab file, diagram, configs, scripts, sample captures and README): `tcp-basics` (NEO-01), `osi-http-capture` (NEO-45), `bgp-ebgp-ibgp-path-choice` (NEO-11) and `multivendor-ebgp` (NEO-32). [LABS.md](LABS.md) lists them.
- `labs/ebgp-two-sites` 1.1.4: diagram labels were added to the lab file so hosts draw as hosts and the diagram files are prepared. Nodes, addresses, links and configs unchanged. 1.1.5: README only. The BGP keepalive in exercise E4 is now "about every 30 s" (hold time 90 s, keepalive one third of it); the old text said about 60 s. A sample capture, `captures/ebgp-keepalive.pcapng`, shows it.
- Every lab README now has **Before you start**, **Troubleshooting** (lab-specific failures and fixes) and **Cleanup** (`containerlab destroy --cleanup`). Each lab has a prepared `.drawio` and `.png` diagram; port labels now show the full interface name (for example `ethernet-1/1`) at 11 px or larger, and no label or link sits on top of another.
- New `tools/` folder for lab authors: `neo_diagram.py` (makes the diagram), `neo_lint.py` (checks a lab: Containerlab schema, private IPv4 only, private AS numbers, `fd00::/8` management IPv6, documentation ranges rejected), a sample, and the optional helper image `neo-tools`.
- Beginner guide 1.3.3: the keepalive text in the optional exercises ("about every 30 seconds") is corrected. Nothing else in the guide changed.
- AS numbers accepted in the kit rules now include 4200000000-4294967294; documentation address ranges are named as not allowed.

### 1.1.3 (2026-11-26)
- Beginner guide 1.3.2 (`NEO-Containerlab-Beginner-Guide.pdf`), after a full beginner walkthrough on VirtualBox 7.2.22 with Containerlab 0.83.0, extension 0.28.0 and Wireshark 4.2.2:
  - Wireshark: the main method now records to a file in Home (`containerlab capture ... --duration ... -w - > file`) and opens it in Wireshark. The right-click **Capture With Wireshark** is an optional shortcut (it can crash the viewer).
  - New checks: `docker ps` without sudo before VS Code; all four devices after a VM restart, with `redeploy` without `-c` for recovery.
  - Exact download steps (green Code > Download ZIP, `~/labs-main/containerlab`), trust only the lab folder, Destroy vs Destroy (Cleanup), one command per line.
- Checked again step by step on a real VirtualBox VM: wait about a minute after Deploy (BGP checkpoint `1`); after a VM restart edge-b is always the stopped device and the recovery redeploy's red `ERRO` blocks are expected; plain Destroy leaves the root-owned `clab-<lab-name>` folder, Destroy (Cleanup) removes it; start the wrong-AS capture right after the clean redeploy (75 seconds is long enough to catch a retry). OPEN and NOTIFICATION lines repeat while the routers keep retrying; your count and times will differ.
- This README and `labs/ebgp-two-sites/README.md` updated to match. Lab file and router configs unchanged.

### 1.1.2 (2026-11-26)
- Added the beginner guide PDF: `NEO-Containerlab-Beginner-Guide.pdf` (this folder).

### 1.1.1 (2026-11-26)
- READMEs now mention the management IPv6 ULA prefix (`fd00:172:20:20::/64`) next to the RFC 1918 IPv4 addresses.

### 1.1.0 (2026-11-26)
- Renamed lab: `labs/neo-48-ebgp/` is now `labs/ebgp-two-sites/` (folder, lab file `ebgp-two-sites.clab.yml` and its `name:`). Containers are now called `clab-ebgp-two-sites-*`. If you have the old lab running, destroy it before you download this version.
- The lab file now sets its management network (`mgmt:`): IPv4 172.20.20.0/24 and IPv6 fd00:172:20:20::/64 (private ULA range), instead of Containerlab's default IPv6 range.
- One FRR check command everywhere: `show bgp summary`.
- Status line no longer says "in review".

### 1.0.0 (2026-11-26)
- Download is the repository ZIP (Code > Download ZIP): `labs-main.zip` unpacks to `labs-main/containerlab/`.
- Kit runs from VS Code with the Containerlab extension (deploy, Attach Shell, Capture With Wireshark, Destroy).
- Editing a config: restart with `containerlab redeploy -c` in VS Code's terminal (the extension's Redeploy (Cleanup) is not recommended).
- Added the draw.io diagram steps (`containerlab graph --drawio` + `chown`).
- `labs/neo-48-ebgp/README.md`: login steps corrected (Attach Shell opens `vtysh` / `sr_cli` directly), duplicate edge-a explained.
- Arista add-on lab removed from the kit (needs a vendor account per viewer).

### 1.0.0-draft (2026-11-25)
- First Containerlab kit. Added `labs/neo-48-ebgp/` (SR Linux + FRR eBGP lab, four exercises).
