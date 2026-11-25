# NEO Lab Setup: build the lab used in NEO Fundamentals

This kit turns one free Ubuntu 24.04 virtual machine (VM) into the lab used across the NEO Fundamentals videos. It also sets up Wireshark and the **NEO_Diagnostics** color profile.

Everything here is free. Every address is a private lab address (RFC 1918). Names are fictional. Run it only on a VM you own, never on a work or school network.

## What you install, and what you run

**In the lab VM, you download one zip and run two scripts. Don't install the kit files one by one.**

1. `scripts/bootstrap-ubuntu-2404.sh` (run it once, step 5) sets up the lab and its tools inside the VM: every lab tool (tcpdump, tshark, FRR, nftables, Open vSwitch and the rest in `TOOLS.md`), the VM's own Wireshark (with `--gui`), capture rights for your user, the NEO_Diagnostics profile, and the `~/neo-lab/captures/` folder.
2. `scripts/verify-lab.sh` (step 6) builds the check lab and makes your capture, inside the VM.

The bootstrap reads `wireshark/NEO_Diagnostics_profile.zip` for you. `diagrams/`, `TOOLS.md` and this README are for reading.

**On your own computer**, you install Wireshark (step 1) for real-world captures of your own traffic, and for opening saved captures such as the ones in each video's folder. The lab runs inside the VM, so its captures are made there, and Wireshark on your computer can't see inside the VM.

## Where everything lives

| | Your own computer | The lab VM |
|---|---|---|
| Wireshark | You install it for real-world captures (step 1) and import the NEO profile (step 3) | The bootstrap installs it with `--gui` and loads the NEO profile (step 5) |
| This kit | The zip you download in step 2 (for the profile) | `~/01_build-your-own-neo-lab` (step 5) |
| Lab captures | WSL2 and UTM Server: copy them here to open them (step 7) | Made here, in `~/neo-lab/captures/` (step 6) |

Do the steps in order.

## What is in this folder

| Path | What it is |
|---|---|
| `scripts/bootstrap-ubuntu-2404.sh` | **Run 1, in the VM.** Installs every free tool the videos use, sets capture permissions, installs the NEO_Diagnostics profile |
| `scripts/verify-lab.sh` | **Run 2, in the VM.** Builds a tiny check lab (two hosts and a router), captures a ping and a TCP handshake, and checks the result |
| `wireshark/NEO_Diagnostics_profile.zip` | The Wireshark color profile used in the videos. The bootstrap loads it in the VM; on your computer you import it (step 3) |
| `diagrams/check-lab-topology.png` / `.svg` | The check lab's topology (to read) |
| `TOOLS.md` | Which tools the bootstrap installs (to read) |

## 1. On your computer: install Wireshark (free), for real-world captures

Wireshark on your own computer captures your computer's real traffic and opens saved capture files. Download it only from the official Download page: <https://www.wireshark.org/download.html>.

- **Windows:** run the Windows x64 (or Arm64) installer and keep the default choices. Leave **Install Npcap** ticked: Npcap is what lets Wireshark capture real traffic on your computer.
- **macOS:** open the macOS disk image and drag Wireshark to Applications. Then open **Install ChmodBPF.pkg** from the same disk image, so Wireshark can capture real traffic on your Mac.
- **Ubuntu desktop:** `sudo apt install wireshark`, answer **Yes** when asked whether non-superusers may capture, then `sudo usermod -aG wireshark $USER` and log out and back in.

Opening saved capture files never needs capture permission. You only need it to capture live traffic on that computer. The lab doesn't use Npcap or ChmodBPF: its captures are made inside the VM (step 6), which Wireshark on your computer can't see into.

## 2. On your computer: download this kit

Download `01_build-your-own-neo-lab.zip` from the link in the video description, then extract it:

- **Windows:** right-click the zip → **Extract All…**
- **macOS:** double-click the zip.

You now have a `01_build-your-own-neo-lab` folder. On your computer you only use its profile (step 3). Nothing in it is installed or run on your computer; the scripts run in the VM.

## 3. On your computer: import the NEO_Diagnostics profile

1. In Wireshark: **Edit → Configuration Profiles…** (the same menu on Windows, macOS and Linux).
2. Click **Import → From Zip File…**, go to your extracted `01_build-your-own-neo-lab` folder, open `wireshark`, and choose `NEO_Diagnostics_profile.zip`.
3. Select **NEO_Diagnostics** in the list and click **OK**. The status bar (bottom right) now says `Profile: NEO_Diagnostics`.

What the colors mean (first matching rule wins):

- **Fault rows** use warm, bright backgrounds with dark text: TCP RST yellow, retransmission orange, TCP zero window coral, DNS error pink. A gap of more than one second before a packet is light blue.
- **TCP** rows are dark (dark grey for SYN and FIN, dark blue for the rest), and **UDP** rows are dark slate. All have light text.
- **ARP** rows are light beige and **ICMP** rows are light lavender, with dark text. They are normal traffic, not faults.

## 4. Make a free Ubuntu 24.04 VM

The lab needs Linux network namespaces, so it runs in an Ubuntu **24.04** LTS VM. The kit checks for 24.04. Newer Ubuntu releases (such as 26.04) are not supported yet, so use the 24.04 image links below, not the newest download on the Ubuntu home page. Give the VM 2 CPUs, 4 GB of memory and 25 GB of disk.

| Your computer | Free VM software | Ubuntu 24.04 image |
|---|---|---|
| Windows 10/11 or an Intel Mac | VirtualBox (<https://www.virtualbox.org/>) | <https://releases.ubuntu.com/24.04/>: the newest `ubuntu-24.04.x-desktop-amd64.iso` |
| Windows 10/11 (no VM window needed) | WSL2: in PowerShell run `wsl --install -d Ubuntu-24.04` | Comes with the command |
| Apple Silicon Mac (M1 and later) | UTM (<https://mac.getutm.app/>, free download from the website) | <https://cdimage.ubuntu.com/releases/24.04/release/>: the newest `ubuntu-24.04.x-live-server-arm64.iso` |

**VirtualBox:**

1. Click **New** and pick the 24.04 `.iso`.
2. Turn **off** unattended installation. In VirtualBox 7.1 and 7.2, untick **Install OS Using Unattended Installation**. In 7.0, tick **Skip Unattended Installation**. Unattended installation can create a user that cannot use `sudo`, and every script here needs `sudo`.
3. Start the VM and click through the Ubuntu installer. The account you create there is an administrator and can use `sudo`.

**WSL2:** the user name you create on first start can use `sudo`.

**UTM Server:** the account you create in the server installer can use `sudo`.

## 5. In the VM: get the kit and run the bootstrap

Open a terminal in the VM:

- **Ubuntu Desktop:** the Terminal app.
- **WSL2:** the Ubuntu app.
- **UTM Server:** the VM window.

Then run:

```
wget https://github.com/NEO-Fundamentals/labs/raw/main/getting-started/01_build-your-own-neo-lab.zip
python3 -m zipfile -e 01_build-your-own-neo-lab.zip .
cd 01_build-your-own-neo-lab
sudo bash scripts/bootstrap-ubuntu-2404.sh --gui
```

(`python3 -m zipfile -e` extracts the zip. It works on every 24.04 image, including the ones without `unzip`.)

The bootstrap is the only install step. Don't install the kit files one by one: this one command sets up the lab and its tools inside the VM (every tool in `TOOLS.md`, the VM's Wireshark with `--gui`, capture rights, the NEO_Diagnostics profile, and `~/neo-lab/captures/`).

On WSL2 and UTM Server, leave off `--gui`; you will open the captures with Wireshark on your computer instead (step 7). The script is safe to run again. With `--gui` it also installs Wireshark in the VM and loads the NEO_Diagnostics profile there. When it finishes, **log out and back in** (WSL2: close the Ubuntu window and open it again) so the capture permission takes effect.

## 6. In the VM: run the check lab

```
cd ~/01_build-your-own-neo-lab
sudo bash scripts/verify-lab.sh
```

It builds three namespaces (host A, router R1, host B) inside the VM, captures at host A, sends three pings and one short TCP connection, and prints a PASS or FAIL line for each check. It ends with `RESULT: PASS` and the name of the capture file, saved in `~/neo-lab/captures/`.

The lab stays up so you can explore it, for example `sudo ip netns exec neo-a ping -c 2 172.16.100.20`. Remove it with `sudo bash scripts/verify-lab.sh --teardown`, or reboot the VM.

## 7. Open the capture in Wireshark

- **Ubuntu Desktop VM (VirtualBox):** in the VM's Wireshark, **File → Open…**, go to `neo-lab/captures` in your home folder, and choose the newest `neo-verify-….pcap`.
- **WSL2:** in Wireshark on Windows, **File → Open…** and type `\\wsl$\Ubuntu-24.04\home\<your-user>\neo-lab\captures` in the file name box.
- **UTM Server:** in the VM, run `ip -br address` to find its address. Then, in the Mac's Terminal, run `scp <your-user>@<vm-address>:neo-lab/captures/*.pcap ~/Downloads/` and open the file in Wireshark on your Mac.

Check that the status bar shows `Profile: NEO_Diagnostics`. You should see 16 packets: 2 ARP, 6 ICMP (three requests and three replies) and 8 TCP (the SYN, SYN-ACK, ACK handshake, the data, and the close). Try the display filter `tcp.port == 8080`.

Some values differ from one VM to the next (ports, sequence-number raw values, timestamps, time to live). The packet types and their order are what matter.

## 8. Each video's files

Every video with a lab or a capture has its own folder in this repository, grouped by playlist (`<playlist>/NN_<lesson>/`, where NN is the video's place in that playlist), with its captures, configs and a topology diagram. This kit is `getting-started/01_build-your-own-neo-lab/`. The video description links straight to it.

## Stay safe

- Lab only: run the scripts in a VM you own.
- Never capture on a network you don't own or don't have permission to capture on.
- Every address here is private (RFC 1918). None of them is a real internet address.

## Tested

On 24 November 2026, both scripts were run in two Ubuntu 24.04 amd64 systems, each in a container without systemd, not a booted VM:

- a minimal 24.04 system;
- the filesystem of the official `ubuntu-24.04.5.1-desktop-amd64.iso` (default install), unpacked.

Runs:

- the zip extract command above;
- the bootstrap, with and without `--gui` (first run and re-run);
- the check lab: PASS with 16 packets, and a second run correctly refuses while the first lab is still up.

Package versions seen: Wireshark/TShark 4.2.2, FRR 8.4.4, tcpdump 4.99.4, nftables 1.0.9, Open vSwitch 3.3.9, iproute2 6.1.0.

Not tested: a booted VM, VirtualBox itself, the ARM64 image, WSL2, and the `--teardown` option.
