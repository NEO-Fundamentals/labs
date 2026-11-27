# Lab: TCP connections that work, get refused, and fail silently

**Folder:** `labs/tcp-basics/`  **Lab file:** `tcp-basics.clab.yml`  **Lesson:** NEO-01 TCP Basics  **Lab version:** 1.0.1 (2026-11-26; README: Before you start, Troubleshooting and Cleanup sections added, diagram re-rendered. Lab file and configs unchanged)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/tcp-basics/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute.

## What this lab builds

```
 host-a                    r1                       host-b
 10.0.2.10/24  ---  FRR router  ---  172.16.100.20/24
 (client)      10.0.2.1  172.16.100.1   (server, port 9000 when you start a listener)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux client. It opens the connections | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router. It only routes; in Run 3 it also drops packets on purpose | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| host-b | Linux server. No service runs until you start one (Run 1) | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

## Files

- `tcp-basics.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1's addresses.
- `tcp-basics.drawio` and `tcp-basics.png` - the prepared diagram.
- `captures/` - sample captures recorded from this lab, to open in Wireshark: `tcp-run1-normal.pcapng`, `tcp-run2-refused.pcapng`, `tcp-run3-silent-drop.pcapng`.
- `scripts/make-captures.sh` - re-records those three files (the lab must be running).

## Start, reset, stop

Type or paste commands one line at a time.

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `tcp-basics` > right-click `tcp-basics.clab.yml` > **Deploy**. Wait for the three green dots (under a minute once the images are downloaded). Run one lab at a time.
- **Reset to the lesson start:** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/tcp-basics
  ```
  ```
  containerlab redeploy -c -t tcp-basics.clab.yml
  ```
- **After a VM restart:** check host-a, r1 and host-b all have green dots; if one is stopped, run `containerlab redeploy -t tcp-basics.clab.yml` in the lab folder.
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below. Keep capture files in your Home folder.

## Check it works

```
docker exec clab-tcp-basics-host-a ping -c 3 172.16.100.20
```
Three replies.

## The three runs (main method)

For every run: start the capture first, in Ubuntu's Terminal app (not VS Code's terminal), then run the commands in a second Terminal window. Use a new file name each time. The capture records host-a's cable:
```
sudo containerlab capture --name tcp-basics --target host-a:eth1 --duration 10s -w - > "$HOME/neo-run1.pcapng"
```
The terminal stays quiet while it records; that's normal. Open the file in Wireshark > **File > Open...** > Home. Useful filters: `tcp`, `tcp.flags.syn == 1`, and the columns `tcp.seq` and `tcp.ack` (right-click a field > **Apply as Column**).

**Run 1, a normal connection.** Start a listener on host-b, then connect from host-a:
```
docker exec -d clab-tcp-basics-host-b sh -c 'echo "hello from host-b" | nc -l -p 9000'
```
```
docker exec clab-tcp-basics-host-a nc -w 3 172.16.100.20 9000
```
host-a prints `hello from host-b` and, after its 3-second idle timeout, ends. In the capture: SYN, SYN-ACK, ACK (the three-way handshake); then host-b's 18-byte data packet (sequence 1 to 19) and host-a's ACK of 19; then the FIN exchange. Click the SYN-ACK: its acknowledgment number is host-a's starting sequence number plus 1.

**Run 2, refused.** Nothing is listening on port 9000 any more. Run the connect line again:
```
docker exec clab-tcp-basics-host-a nc -w 3 172.16.100.20 9000
```
It ends at once, printing nothing (exit status 1). In the capture, with the `tcp` filter, there are two packets: the SYN, and an immediate reply with `RST, ACK`. A reset is the server saying "no one is listening here".

**Run 3, silent drop.** Make r1 throw away every packet for host-b without answering:
```
docker exec clab-tcp-basics-r1 ip route add blackhole 172.16.100.20/32
```
```
docker exec clab-tcp-basics-host-a nc -w 9 172.16.100.20 9000
```
After 9 seconds it gives up. Use `--duration 14s` for this capture. In the file you see the same SYN (same sequence number) sent again and again, with no reply at all: about once a second at first, then the gaps grow. That is a retransmission, and silence is the symptom of a drop somewhere on the path. Put it back:
```
docker exec clab-tcp-basics-r1 ip route del blackhole 172.16.100.20/32
```

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | Run 1 above, then open the capture with `tcp` | Handshake, one data packet, ACK, FIN exchange. The ACK number is always the next byte the receiver expects | Nothing to undo |
| E2 | Run 2 above (listener stopped), open with `tcp` | SYN answered by `RST, ACK` within a fraction of a millisecond | Nothing to undo |
| E3 | Run 3 above, open with `tcp.flags.syn == 1` | One SYN repeated with the same sequence number and no SYN-ACK; Wireshark marks the repeats as retransmissions | `docker exec clab-tcp-basics-r1 ip route del blackhole 172.16.100.20/32` |
| E4 | Compare Run 2 and Run 3: which one has a packet from host-b? | Refused has a reply (RST), silent drop has none. "Something answered" versus "nothing answered" is the first question to ask when a connection fails | Nothing to undo |

## Troubleshooting

1. **Run 1 prints nothing, or `nc` ends at once with no text.** The listener on host-b serves one connection and then exits. Start it again (the `docker exec -d ... nc -l -p 9000` line) right before each connect.
2. **Run 2 hangs instead of ending at once.** The blackhole route from Run 3 is still on r1, so the SYN is dropped instead of refused. Remove it: `docker exec clab-tcp-basics-r1 ip route del blackhole 172.16.100.20/32`.
3. **`ip route add blackhole` says `File exists`.** You already added it. Delete it with the `ip route del blackhole ...` line, then add it again.
4. **The first ping fails right after Deploy.** r1 (FRR) loads its addresses 10 to 20 seconds after the green dots. Wait and ping again.
5. **The capture file has no packets.** Start the capture first, in Ubuntu's Terminal app with `sudo` and `--target host-a:eth1`, then run the commands in a second window while it records.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/tcp-basics
```
```
containerlab destroy --cleanup -t tcp-basics.clab.yml
```
`--cleanup` also removes the generated `clab-tcp-basics` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-tcp-basics` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/tcp-basics/clab-tcp-basics
```
Your capture files in your Home folder are not touched.

## Concept comparison (not part of this lab)

A real firewall that silently discards the SYN looks exactly like Run 3 from the client's side, and a firewall that rejects it looks like Run 2. The lab uses a router blackhole route to make the same effect without any firewall software.
