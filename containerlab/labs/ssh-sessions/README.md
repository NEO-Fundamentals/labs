# Lab: SSH sessions, and the six places an SSH login can fail

**Folder:** `labs/ssh-sessions/`  **Lab file:** `ssh-sessions.clab.yml`  **Lesson:** NEO-04 SSH: a secure session over TCP  **Lab version:** 1.0.1 (2026-11-27, kit 1.2.3: faults.sh help text, note on the 10.0.2.x range; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.0.0)

**What runs and what does not:** the lab runs a real OpenSSH client (host-a), an FRR router (r1) and a real OpenSSH server (host-b). Nothing is simulated. **There is no Junos or EOS in this lab.** No password is used anywhere: host-a logs in with a key pair that a script makes after Deploy.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/ssh-sessions/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB), `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB) and `ghcr.io/neo-fundamentals/neo-tools:1.0.0` (the NEO helper image, a Debian image with the OpenSSH server, about 257 MB). After that the lab works offline. Keep at least 3 GB of disk free (`df -h ~`).
- **Time:** the first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute, plus about 20 seconds for FRR to apply its address file.
- **Addresses:** this lab uses 10.0.2.x on its own cables. Your VM's VirtualBox network uses the same range (`ip addr` on the VM shows 10.0.2.15/24 on its main interface). They are separate networks that share a number range; use only the lab addresses in this README in the exercises.

## What this lab builds

```
 host-a (SSH client)        r1 (FRR)               host-b (SSH server)
 10.0.2.10/24  --eth1--  10.0.2.1/24 | 172.16.100.1/24  --eth2--  172.16.100.20/24
                       (a router that only forwards)               sshd on port 22
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux host with the OpenSSH client. Address 10.0.2.10/24, route to 172.16.100.0/24 through r1 | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router. 10.0.2.1/24 on eth1, 172.16.100.1/24 on eth2 | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| host-b | Linux host with the OpenSSH server (port 22, keys only, user `labuser`). Address 172.16.100.20/24 | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `ssh-sessions.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1's two addresses. `configs/host-b/sshd_config` - the SSH server settings (keys only, no root login, verbose log).
- `scripts/setup-keys.sh` - run once after each Deploy: makes the key pairs inside the containers (nothing secret is stored in this folder).
- `scripts/faults.sh` - switches each fault on and off on host-b: `refused`, `drop`, `banner`, `hostkey` (and `status`).
- `scripts/silent-listener.py` - a tiny program the `banner` fault uses: it accepts the connection and says nothing.
- `scripts/make-captures.sh` - re-records the sample captures (the lab must be running). Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.
- `ssh-sessions.drawio` and `ssh-sessions.png` - the prepared diagram.
- `captures/` - seven sample captures from host-a's cable (below).

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `ssh-sessions` > right-click `ssh-sessions.clab.yml` > **Deploy**. Wait for the three green dots, then about 20 more seconds: FRR applies its address file a little after the containers start. Then, in VS Code's **Terminal > New Terminal**, one line at a time:
  ```
  cd ~/labs-main/containerlab/labs/ssh-sessions
  ```
  ```
  bash scripts/setup-keys.sh
  ```
  It prints three key fingerprints (`id_lab`, `id_other` and the one host-b accepts). Run `setup-keys.sh` again after every Deploy or redeploy.
- **Reset to the lesson start:**
  ```
  containerlab redeploy -c -t ssh-sessions.clab.yml
  ```
  then run `bash scripts/setup-keys.sh` again. A redeploy gives host-b a new host key, and host-a forgets the old one.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The six checkpoints

An SSH login passes six checkpoints in order. The error message tells you which one failed.

| # | Checkpoint | Fault you switch on | What host-a prints (starts with) | What the capture shows |
|---|---|---|---|---|
| 1 | TCP connection to port 22 | `refused on` | `Connection refused` | SYN, then RST right back |
| 1 | TCP connection to port 22 | `drop on` | `Operation timed out` | SYN again and again, no answer |
| 2 | The server sends its banner | `banner on` | `Connection timed out during banner exchange` | TCP open, the client sends its version, the server never does |
| 3 | Key exchange (both sides agree on algorithms) | client option `KexAlgorithms=diffie-hellman-group1-sha1` | `Unable to negotiate ... no matching key exchange method found` | Both sides send Key Exchange Init, then the connection closes |
| 4 | The server proves who it is (host key) | `hostkey on` | `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Key exchange completes, the client closes after seeing the key |
| 5 | The client proves who it is (user key) | login with the wrong key `id_other` | `Permission denied (publickey).` | Key exchange completes, the key is offered and refused, then the client closes |
| 6 | The session | none | the command runs | Encrypted data both ways |

## Exercises

Open host-a's shell: right-click `host-a` under **Running Labs** > **Access** > **Attach Shell**. Run the `ssh` lines there. Run the `bash scripts/faults.sh` lines in the VS Code terminal in the lab folder (cd line above). Each `ssh` line has `BatchMode=yes` so it never waits for a password, and `ConnectTimeout=5` so a hang ends after 5 seconds.

**1. A login that works.** First prove the path, on host-a:
```
ping -c 2 172.16.100.20
```
Two replies (if not, wait 20 more seconds: FRR is still loading). Then log in and run one command on host-b:
```
ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_lab labuser@172.16.100.20 hostname
```
It prints `Warning: Permanently added '172.16.100.20' (ED25519) to the list of known hosts.` (host-a has just learned host-b's host key) and then `host-b`, the name of the machine you logged in to. Run it again: only `host-b`, no warning.
See what host-b saw:
```
docker exec clab-ssh-sessions-host-b tail -5 /var/log/sshd.log
```
The last lines show `Starting session: command for labuser from 10.0.2.10 ...` and then the disconnect (earlier lines of the log name the key that was accepted).

**2. Connection refused (checkpoint 1).** In the VS Code terminal:
```
bash scripts/faults.sh refused on
```
On host-a run the same `ssh` line as step 1 (without `StrictHostKeyChecking`):
```
ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -i /root/.ssh/id_lab labuser@172.16.100.20 hostname
```
It fails at once with `ssh: connect to host 172.16.100.20 port 22: Connection refused`: the host answered that nothing listens on port 22. Switch it back: `bash scripts/faults.sh refused off`.

**3. Operation timed out (checkpoint 1).**
```
bash scripts/faults.sh drop on
```
Run the `ssh` line again. This time it waits the full 5 seconds and prints `ssh: connect to host 172.16.100.20 port 22: Operation timed out`. Nobody answered, so a filter or a dead path is dropping the packets. Compare with step 2: a refusal is an answer, a timeout is silence. Switch back: `bash scripts/faults.sh drop off`.

**4. Banner timeout (checkpoint 2).**
```
bash scripts/faults.sh banner on
```
Run the `ssh` line. The TCP connection opens (so it is not a firewall) but after 5 seconds it prints `Connection timed out during banner exchange` and `Connection to 172.16.100.20 port 22 timed out`: something accepted the connection but is not an SSH server that answers. Switch back: `bash scripts/faults.sh banner off`.

**5. No matching key exchange (checkpoint 3).** No fault to switch on; the client asks for an old method that host-b does not offer:
```
ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o KexAlgorithms=diffie-hellman-group1-sha1 -i /root/.ssh/id_lab labuser@172.16.100.20 hostname
```
The message is `Unable to negotiate with 172.16.100.20 port 22: no matching key exchange method found.` followed by `Their offer:` and the list of methods host-b supports (it begins `sntrup761x25519-sha512,...`). Neither side is broken; they have no algorithm in common.

**6. Host key changed (checkpoint 4).** Step 1 left host-b's key in host-a's list. Give host-b a new key:
```
bash scripts/faults.sh hostkey on
```
Log in with strict checking:
```
ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -i /root/.ssh/id_lab labuser@172.16.100.20 hostname
```
The client stops with the large `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` block. It prints the fingerprint of the new key, and its last two lines are `Host key for 172.16.100.20 has changed and you have requested strict checking.` and `Host key verification failed.` Nothing was wrong with the network: the server's identity is different from the one the client remembered. A real change (a rebuilt device) and a man-in-the-middle look the same here. Check the new key at the server before you trust it: `bash scripts/faults.sh status` prints host-b's key fingerprint. Switch back: `bash scripts/faults.sh hostkey off`.

**7. Permission denied (checkpoint 5).** Log in with the other key, which host-b does not accept:
```
ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -i /root/.ssh/id_other labuser@172.16.100.20 hostname
```
The message is `labuser@172.16.100.20: Permission denied (publickey).` The connection and the server are fine; the key is not on the server's list. The server's log (`docker exec clab-ssh-sessions-host-b tail -4 /var/log/sshd.log`) has a line `Failed publickey for labuser from 10.0.2.10 ...` with the fingerprint of the rejected key, then `Connection closed by authenticating user labuser`.

**8. Capture one login.** In Ubuntu's Terminal app start the capture first (it records for 20 seconds), then run the step 1 `ssh` line on host-a:
```
sudo containerlab capture --name ssh-sessions --target host-a:eth1 --duration 20s -w - > "$HOME/neo-ssh.pcapng"
```
Open `neo-ssh.pcapng` in Wireshark and filter on `ssh`. Find the two Protocol lines (client and server versions), the Key Exchange Init from both sides, and then only encrypted packets.

## Sample captures

All are recorded on host-a's cable and cut to 200 bytes per packet, so Wireshark may say the packet size was limited during capture. That is expected.

| File | Frames | What it shows |
|---|---|---|
| `ssh-1-ok.pcapng` | 51 | A login that works: TCP handshake, version lines, key exchange, encrypted session. Filter `ssh` |
| `ssh-2-refused.pcapng` | 2 | SYN and RST (refused) |
| `ssh-3-timeout.pcapng` | 7 | SYN sent five times with no answer (`tcp.analysis.retransmission`); the last two frames are r1's ARP exchange with host-a |
| `ssh-4-banner-timeout.pcapng` | 7 | TCP opens, the client sends its version, the server stays silent, the client closes after 5 seconds |
| `ssh-5-kex-mismatch.pcapng` | 12 | Both Key Exchange Init messages, then the client closes |
| `ssh-6-hostkey-changed.pcapng` | 19 | Key exchange completes; the client closes because the key changed |
| `ssh-7-permission-denied.pcapng` | 28 | Key exchange completes; the server refuses the key; the client closes |

## Troubleshooting

1. **`setup-keys.sh` says `No such container`.** The lab is not running (or still starting). Run `containerlab inspect --all`, wait for the three nodes, and run it again.
2. **The first `ping` fails.** FRR applies its address file 10 to 20 seconds after the containers start. Wait, then check again. (`scripts/make-captures.sh` waits up to 90 seconds for this and then stops with a message.)
3. **Step 1 says `Permission denied (publickey)`.** You did not run `bash scripts/setup-keys.sh` after the last Deploy, so host-b has no key for `labuser`. Run it and try again.
4. **An answer looks wrong after a fault.** Run `bash scripts/faults.sh status`: it lists what listens on port 22, whether the drop filter is on and host-b's key fingerprint. Switch each fault off with its `off` line, or reset with `containerlab redeploy -c -t ssh-sessions.clab.yml` and `bash scripts/setup-keys.sh`.
5. **`Host key verification failed` before any fault.** Host-a remembers an older host-b (you redeployed without `-c`). In host-a's shell run `ssh-keygen -R 172.16.100.20`.
6. **Deploy cannot pull `ghcr.io/neo-fundamentals/neo-tools:1.0.0`.** Check your internet connection and run Deploy again. The image is public; no login is needed.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/ssh-sessions
```
```
containerlab destroy --cleanup -t ssh-sessions.clab.yml
```
`--cleanup` also removes the generated `clab-ssh-sessions` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-ssh-sessions` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/ssh-sessions/clab-ssh-sessions
```
The keys live only inside the containers and disappear with them. Your capture files in your Home folder are not touched.

## What this lab does not do

- No Junos or EOS device runs here; this lab has none.
- host-a trusts host-b by its key, not by a password. Password logins, SSH certificates and jump hosts are not part of this lab.
- The faults are put on host-b only; r1 just routes.
