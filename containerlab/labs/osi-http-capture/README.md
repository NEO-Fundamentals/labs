# Lab: the OSI model with one web page

**Folder:** `labs/osi-http-capture/`  **Lab file:** `osi-http-capture.clab.yml`  **Lesson:** NEO-45 The OSI Model  **Lab version:** 1.0.2 (2026-11-27, kit 1.2.3: DNS sample description, note on the 10.0.2.x range; network-multitool pinned to v0.10.0 (same image); `make-captures.sh` needs sudo and keeps the old sample if a recording fails. Previous: 1.0.1)

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/osi-http-capture/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool:v0.10.0` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute.
- **Addresses:** this lab uses 10.0.2.x on its own cables. Your VM's VirtualBox network uses the same range (`ip addr` on the VM shows 10.0.2.15/24 on its main interface). They are separate networks that share a number range; use only the lab addresses in this README in the exercises.

## What this lab builds

```
 pc                       r1                         srv
 10.0.2.10/24  ---  FRR router  ---  172.16.100.80/24
 (the client)   10.0.2.1  172.16.100.1   web server (port 80) + DNS server (port 53)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| pc | Linux client. It asks DNS for `www.osi-lab.example`, then loads the page | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router. It only routes between the two LANs | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| srv | Linux server running a web server (nginx) and a DNS server (dnsmasq) | `ghcr.io/srl-labs/network-multitool:v0.10.0` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. The name `www.osi-lab.example` is fictional (`.example` is reserved for examples) and only the lab's own DNS server knows it.

## Files

- `osi-http-capture.clab.yml` - the lab drawing: which devices, which cables.
- `configs/r1-frr.conf` - r1's addresses.
- `configs/srv/index.html` - the web page srv serves.
- `configs/srv/dnsmasq.conf` - srv's DNS answer for `www.osi-lab.example`.
- `osi-http-capture.drawio` and `osi-http-capture.png` - the prepared diagram.
- `captures/` - sample captures recorded from this lab, to open in Wireshark: `osi-http-ok.pcapng` (the page load, E1), `osi-http-refused.pcapng` (web server stopped, E2) and `osi-dns-down.pcapng` (DNS server stopped, E3).
- `scripts/make-captures.sh` - re-records those three files (the lab must be running). Run it from the lab folder with `sudo bash scripts/make-captures.sh` (it asks for your password). It overwrites a sample in `captures/` only when the new recording succeeds; a failed one prints `FAIL` and the old sample stays.

## Start, reset, stop

Type or paste commands one line at a time.

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `osi-http-capture` > right-click `osi-http-capture.clab.yml` > **Deploy**. Wait for all three dots to turn green (under a minute once the images are downloaded). Run one lab at a time.
- **Reset to the lesson start:** in VS Code, **Terminal > New Terminal**, then:
  ```
  cd ~/labs-main/containerlab/labs/osi-http-capture
  ```
  ```
  containerlab redeploy -c -t osi-http-capture.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below. Keep capture files in your Home folder.
- **After a VM restart:** check that pc, r1 and srv all have green dots. If any is stopped, run `containerlab redeploy -t osi-http-capture.clab.yml` in the lab folder.

## Check it works

In VS Code's terminal (or right-click pc > **Attach Shell**):
```
docker exec clab-osi-http-capture-pc dig +short www.osi-lab.example
```
It prints `172.16.100.80`. Then:
```
docker exec clab-osi-http-capture-pc curl -s http://www.osi-lab.example/
```
It prints a short web page that says "osi-lab web server".

## Capture the page load (main method)

In Ubuntu's Terminal app (not VS Code's terminal), record the PC's cable for 20 seconds:
```
sudo containerlab capture --name osi-http-capture --target pc:eth1 --duration 20s -w - > "$HOME/neo-osi-http.pcapng"
```
The terminal stays quiet while it records; that's normal. In a second Terminal window, load the page once:
```
docker exec clab-osi-http-capture-pc curl -s http://www.osi-lab.example/
```
When the first prompt comes back, open Wireshark > **File > Open...** > Home > `neo-osi-http.pcapng`. Use a new file name each run.

What you should see, in this order (18 packets in the whole sample file): two DNS questions and their answers, one for the IPv6 address (AAAA, which gets no address back) and one for the IPv4 address (A, answered with 172.16.100.80) (filter `dns`), the TCP three-way handshake (filter `tcp.port == 80`), an HTTP GET and a `200 OK` (filter `http`), then the TCP close. Click the GET packet and open the packet details: Ethernet II (layer 2), Internet Protocol (3), Transmission Control Protocol (4), Hypertext Transfer Protocol (7). The DNS packets are UDP instead of TCP.

## Exercises

| # | Do this | What you should see | Put it back |
|---|---|---|---|
| E1 | Run the capture above while pc loads the page; open it with `dns`, then `tcp.port == 80`, then `http` | DNS answer 172.16.100.80; handshake; GET and 200 OK | Nothing to undo |
| E2 | Stop the web server: `docker exec clab-osi-http-capture-srv nginx -s stop`. Start a new capture, then run the `curl` line again with `-sS` instead of `-s` (`docker exec clab-osi-http-capture-pc curl -sS http://www.osi-lab.example/`) | curl shows no page and prints `Failed to connect ... Could not connect to server`; in the file, the SYN from pc is answered by a packet with `RST, ACK`: layer 4 says "nothing is listening on port 80" while layers 1 to 3 work fine | `docker exec clab-osi-http-capture-srv nginx` |
| E3 | Stop the DNS server: `docker exec clab-osi-http-capture-srv pkill dnsmasq`. Run the same `curl -sS` line again | `Could not resolve host`; no TCP packets at all, because the name never turned into an address (an application-layer problem). In a capture you see the DNS question and an ICMP "port unreachable" reply | `docker exec clab-osi-http-capture-srv dnsmasq --conf-file=/etc/neo/dnsmasq.conf` |

## Troubleshooting

1. **`dig` or `curl` times out or prints nothing right after Deploy.** r1 loads its addresses about 10 to 20 seconds after the green dots, and srv starts nginx and dnsmasq a few seconds after that. Wait half a minute and retry.
2. **`dig +short www.osi-lab.example` prints nothing.** The name exists only on the lab's own DNS server (srv, 172.16.100.80). You probably ran E3 (DNS stopped) and did not put it back: use the **Put it back** step in the exercise table, or reset with `containerlab redeploy -c -t osi-http-capture.clab.yml`.
3. **`curl` says connection refused, though the name resolves.** You ran E2 (web server stopped) and did not put it back. Use its **Put it back** step or reset with `redeploy -c`.
4. **The capture file is empty or has no DNS or HTTP packets.** Start the capture first in Ubuntu's Terminal (not VS Code's terminal) with `sudo`, record `pc:eth1`, and run the `curl` in a second window while it records. Use a new file name each time.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/osi-http-capture
```
```
containerlab destroy --cleanup -t osi-http-capture.clab.yml
```
`--cleanup` also removes the generated `clab-osi-http-capture` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-osi-http-capture` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/osi-http-capture/clab-osi-http-capture
```
Your capture files in your Home folder are not touched.

## Concept comparison (not part of this lab)

The same page load on a physical network crosses a switch and a router with the same layers. Only the cables and the device models differ.
