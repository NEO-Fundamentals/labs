# Lab: SSH management with strict host-key checking (real OpenSSH), with Junos and EOS shown as text

**Folder:** `labs/multivendor-ssh-management/`  **Lab file:** `multivendor-ssh-management.clab.yml`  **Lesson:** NEO-33 Multi-vendor SSH management  **Lab version:** 1.0.1 (2026-11-27, kit 1.2.3: diagram draws the device as a server; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.0.0)

**What runs and what does not:** the lab runs a real OpenSSH client on a management host (admin-host) and a real OpenSSH server on a Linux device. **Junos and EOS appear only as configuration and command text for comparison (below). They are not run, and there is no Junos or EOS in this lab.** The device stands in for a network device: it is a Linux container, not a router.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/multivendor-ssh-management/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB) and `ghcr.io/neo-fundamentals/neo-tools:1.0.0` (the NEO helper image, a Debian image with the OpenSSH server, about 257 MB). After that the lab works offline. Keep at least 3 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute.

## What this lab builds

```
 admin-host                          device
 192.168.50.10/24  ------ eth1 ------ 192.168.50.1/24
 OpenSSH client, strict checking      OpenSSH server, port 22, user netops
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| admin-host | The management host. 192.168.50.10/24. Its SSH settings never accept an unknown or a changed host key by themselves (`StrictHostKeyChecking yes`) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| device | The managed device. 192.168.50.1/24, sshd listens on that address only, user `netops`, keys only | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. No password is used: admin-host logs in with a key pair that a script makes after Deploy.

## Files

- `multivendor-ssh-management.clab.yml` - the lab drawing.
- `configs/admin-host/strict.conf` - the client rules (strict host-key checking). `configs/device/sshd_config` - the server settings (keys only, no root login, verbose log).
- `scripts/setup-keys.sh` - run once after each Deploy: makes the keys inside the containers (nothing secret is stored in this folder).
- `scripts/device-sshd.sh` - changes the device: `rebuild` (new host key, as if the device had been replaced), `restore`, `stop`, `start`, `fingerprint`.
- `scripts/make-captures.sh` - re-records the sample captures (the lab must be running and `setup-keys.sh` must have run). Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.
- `multivendor-ssh-management.drawio` and `multivendor-ssh-management.png` - the prepared diagram.
- `captures/` - five sample captures from admin-host's cable (below).

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `multivendor-ssh-management` > right-click `multivendor-ssh-management.clab.yml` > **Deploy**. Wait for the two green dots. Then, in VS Code's **Terminal > New Terminal**, one line at a time:
  ```
  cd ~/labs-main/containerlab/labs/multivendor-ssh-management
  ```
  ```
  bash scripts/setup-keys.sh
  ```
  It prints the fingerprints of two keys on admin-host (`id_netops` and `id_old`) and the one key the device accepts. Run it again after every Deploy or redeploy.
- **Reset to the lesson start:**
  ```
  containerlab redeploy -c -t multivendor-ssh-management.clab.yml
  ```
  then run `bash scripts/setup-keys.sh` again.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands, on each system

| Task | Linux / OpenSSH (runs in this lab) | Junos (text only, not run) | EOS (text only, not run) |
|---|---|---|---|
| Turn SSH on | `/usr/sbin/sshd` | `set system services ssh` | `management ssh` (then `no shutdown`) |
| Allow one user key | a line in `~/.ssh/authorized_keys` | `set system login user netops authentication ssh-ed25519 "<public key>"` | `username netops ssh-key ssh-ed25519 <public key>` |
| Who is logged in | `who` | `show system users` | `show users` |
| Remember a device's host key (client side) | `ssh-keyscan` and `known_hosts` | the same OpenSSH client on the management host | the same OpenSSH client on the management host |

The management host in all three cases is an ordinary Linux machine running the OpenSSH client. The host-key rules in the exercises below do not depend on the vendor of the device.

Not affiliated with or endorsed by Juniper or Arista. Junos and EOS syntax is shown for comparison only.

## Exercises

Open admin-host's shell: right-click `admin-host` under **Running Labs** > **Access** > **Attach Shell**. Run the `ssh` lines there. Run the `bash scripts/device-sshd.sh` lines in the VS Code terminal in the lab folder.

**1. An unknown device is refused.** admin-host has never seen this device's host key, and strict checking says to stop:
```
ssh -i /root/.ssh/id_netops netops@192.168.50.1 hostname
```
It stops with `No ED25519 host key is known for 192.168.50.1 and you have requested strict checking.` and `Host key verification failed.` Nothing is wrong with the key or the network: the host key is not trusted yet. The sample `captures/sshmgmt-1-unknown-host.pcapng` shows the key exchange completing and the client then closing the connection.

**2. Add the device the careful way: compare the fingerprint.** On the device, read the fingerprint from the device itself (this stands in for reading it at the device console). In the VS Code terminal:
```
bash scripts/device-sshd.sh fingerprint
```
On admin-host, fetch the key over the network and show its fingerprint:
```
ssh-keyscan -t ed25519 192.168.50.1 > /root/.ssh/known_hosts
```
```
ssh-keygen -lf /root/.ssh/known_hosts
```
The device prints `256 SHA256:... root@device (ED25519)` and the second command prints `256 SHA256:... 192.168.50.1 (ED25519)`. The `SHA256:...` strings must be identical. Only then keep the line. In a real network, the first fingerprint comes from the console or from your inventory, not from the same network path an attacker could sit on.

**3. A login that works.**
```
ssh -i /root/.ssh/id_netops netops@192.168.50.1 hostname
```
It prints `device`, the name of the machine you logged in to. The sample `captures/sshmgmt-2-login-ok.pcapng` shows the whole login: TCP handshake, the version lines, key exchange, then only encrypted packets. See what the device logged:
```
docker exec clab-multivendor-ssh-management-device tail -5 /var/log/sshd.log
```
The first line shows `Accepted publickey for netops from 192.168.50.10 ...` with the fingerprint of the key that was accepted.

**4. An old key is refused.** admin-host also has an old key the device does not know:
```
ssh -i /root/.ssh/id_old netops@192.168.50.1 hostname
```
The message is `netops@192.168.50.1: Permission denied (publickey).` The device and its host key are fine; this key is not on its list. See `captures/sshmgmt-3-old-key.pcapng`.

**5. The device was rebuilt: the host key changed.** In the VS Code terminal give the device a new host key, as if it had been replaced:
```
bash scripts/device-sshd.sh rebuild
```
On admin-host:
```
ssh -i /root/.ssh/id_netops netops@192.168.50.1 hostname
```
The client stops with the large `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` block. It prints the fingerprint of the new key and `Offending ED25519 key in /root/.ssh/known_hosts:2` (line 1 of that file is a comment that `ssh-keyscan` wrote), and ends with `Host key for 192.168.50.1 has changed and you have requested strict checking.` and `Host key verification failed.` A rebuild looks exactly like an attack from the client's side, so do not just delete the old line. Read the new fingerprint at the device (`bash scripts/device-sshd.sh fingerprint`), and only if it is the one you expect remove the old entry and add the new one:
```
ssh-keygen -R 192.168.50.1
```
It prints `# Host 192.168.50.1 found: line 2` and `/root/.ssh/known_hosts updated.` and keeps the old list as `known_hosts.old`.
```
ssh-keyscan -t ed25519 192.168.50.1 > /root/.ssh/known_hosts
```
See `captures/sshmgmt-4-host-key-changed.pcapng`. Put the first host key back with `bash scripts/device-sshd.sh restore` and add it again the same way.

**6. The SSH service is down.**
```
bash scripts/device-sshd.sh stop
```
```
ssh -i /root/.ssh/id_netops netops@192.168.50.1 hostname
```
It fails at once with `ssh: connect to host 192.168.50.1 port 22: Connection refused`: the device answers on the network, but nothing listens on port 22. `captures/sshmgmt-5-refused.pcapng` is two frames: SYN, then RST. Start it again with `bash scripts/device-sshd.sh start`.

**7. Capture a login.** In Ubuntu's Terminal app start the capture first (15 seconds), then run the step 3 `ssh` line on admin-host:
```
sudo containerlab capture --name multivendor-ssh-management --target admin-host:eth1 --duration 15s -w - > "$HOME/neo-sshmgmt.pcapng"
```
Open it in Wireshark and filter on `ssh`.

## Sample captures

All are recorded on admin-host's cable. The ones with SSH traffic are cut to 200 bytes per packet, so Wireshark may say the packet size was limited during capture. That is expected.

| File | Frames | What it shows |
|---|---|---|
| `sshmgmt-1-unknown-host.pcapng` | 21 | Unknown host key: key exchange, then the client closes |
| `sshmgmt-2-login-ok.pcapng` | 49 | A login that works, then a command |
| `sshmgmt-3-old-key.pcapng` | 28 | The old key is offered and refused |
| `sshmgmt-4-host-key-changed.pcapng` | 19 | Changed host key: the client closes after key exchange |
| `sshmgmt-5-refused.pcapng` | 2 | SYN and RST (SSH service stopped) |

## Troubleshooting

1. **`setup-keys.sh` says `No such container`.** The lab is not running or still starting. Run `containerlab inspect --all`, wait for both nodes, and run it again.
2. **Step 3 says `Permission denied (publickey)`.** You did not run `bash scripts/setup-keys.sh` after the last Deploy, so the device has no key for `netops`. Run it and try again.
3. **Step 1 does not fail; it just logs in.** An earlier step left the device in `known_hosts`. On admin-host run `rm -f /root/.ssh/known_hosts` and try again (this removes only admin-host's list inside the container).
4. **After step 5 the old host key still fails.** Run `bash scripts/device-sshd.sh restore` (the first key comes back), or reset the lab with `containerlab redeploy -c -t multivendor-ssh-management.clab.yml`, run `bash scripts/setup-keys.sh` and start again.
5. **The device refuses the connection after an experiment.** Run `bash scripts/device-sshd.sh start`.
6. **Deploy cannot pull `ghcr.io/neo-fundamentals/neo-tools:1.0.0`.** Check your internet connection and run Deploy again. The image is public; no login is needed.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/multivendor-ssh-management
```
```
containerlab destroy --cleanup -t multivendor-ssh-management.clab.yml
```
`--cleanup` also removes the generated `clab-multivendor-ssh-management` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-multivendor-ssh-management` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/multivendor-ssh-management/clab-multivendor-ssh-management
```
The keys live only inside the containers and disappear with them. Your capture files in your Home folder are not touched.

## What this lab does not do

- No Junos or EOS device runs here; the table above is text.
- The device is a Linux container with an SSH server, not a router. The lesson is about the SSH client side (host-key trust, keys, errors), which is the same for every vendor.
- Passwords, SSH certificates, jump hosts and a TACACS+ or RADIUS login are not part of this lab.
