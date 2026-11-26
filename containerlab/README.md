# NEO Fundamentals labs (Containerlab kit)

**Kit version:** 1.1.1  **Date:** 2026-11-26  **Status:** current

One download holds every lesson lab. Each video tells you which folder to open.
You run the labs from **VS Code** inside your Ubuntu 24.04 lab VM. New to this? Follow the beginner guide (linked in the video description). It goes step by step with screenshots, from an empty computer to a running lab.

## Lesson index

| Lesson | Folder | What it builds | Images needed | Tested |
|---|---|---|---|---|
| NEO-48 Build Your Own NEO Lab | `labs/ebgp-two-sites/` | Two sites joined by eBGP: Nokia SR Linux (edge-a, AS 65201), FRR (edge-b, AS 65202), two Linux PCs | Free, downloaded automatically | Yes (Ubuntu 24.04, Containerlab 0.83.0, VS Code extension 0.27.0) |

More lessons are added as new folders under `labs/`. This table and the CHANGELOG below list every change.

## How to start a lesson (short version)

1. In VS Code, open the kit folder (**File > Open Folder** > `labs-main` > `containerlab`) and click **Trust**.
2. Click the **Containerlab** icon on the left. Your lesson's `.clab.yml` file is under **Undeployed Local Labs**.
3. Right-click it > **Deploy**. The first deploy downloads the router images (about 3 GB) and can take 5 to 15 minutes.
4. Log in to a device: right-click it under **Running Labs** > **Access** > **Attach Shell**. (edge-a appears twice; the second one is an internal SR Linux helper, so ignore it.)
5. **After you edit a config file**, restart the lab from VS Code's terminal (**Terminal > New Terminal**):
   `cd ~/labs-main/containerlab/labs/<lesson-folder>` then `containerlab redeploy -c -t <lab-file>.clab.yml`
   Don't use **Redeploy (Cleanup)** from the right-click menu; in our tests it closed VS Code.
6. **Stop:** right-click the running lab > **Destroy**.

Wireshark capture: right-click an interface under a running device > **Capture With Wireshark**. You must be in the `wireshark` group (`sudo usermod -aG wireshark $USER`, then log out and back in).
Diagram: `containerlab graph --drawio -t <lab-file>.clab.yml`, then `sudo chown $USER:$USER <lab-file>.clab.drawio`, then click the `.drawio` file to edit it in Draw.io Integration.

## Getting the latest labs

New labs are added over time. Compare the **Kit version** line at the top of this file with the one in the `containerlab` folder on GitHub (github.com/NEO-Fundamentals/labs). If GitHub's is newer:
- **Beginners:** rename your old `labs-main` folder if you want to keep your edits, then on the repository page click **Code > Download ZIP** and unzip `labs-main.zip` to your Home folder.
- **git users:** run `git pull` inside your clone.

## Rules for this kit

- Lab addresses are private only: IPv4 from RFC 1918 (such as 10.x and 192.168.x), management IPv6 from the private ULA range fd00::/8 (the lab uses fd00:172:20:20::/64), and AS numbers from the private range 64512-65534.
- No vendor software is stored here. Every lab uses only free public images (Nokia SR Linux, FRR, network-multitool), which download from the vendors' public registries the first time you deploy. No vendor account is needed.
- Arista EOS and Juniper Junos are compared on screen in the videos only. This kit has no labs for them.

## CHANGELOG

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
