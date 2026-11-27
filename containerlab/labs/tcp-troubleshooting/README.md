# Lab: TCP troubleshooting, six faults you switch on and off

**Folder:** `labs/tcp-troubleshooting/`  **Lab file:** `tcp-troubleshooting.clab.yml`  **Lesson:** NEO-02 TCP Troubleshooting  **Lab version:** 1.0.0 (2026-11-26)


## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/tcp-troubleshooting/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute, plus about 10 seconds for r1.

## What this lab builds

```
 host-a                    r1                       host-b
 10.0.2.10/24  ---  FRR router  ---  172.16.100.20/24
 (client)      10.0.2.1  172.16.100.1   (test server on ports 8080, 8082, 8083, 8085)
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a | Linux client. It opens the connections and is where you capture | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router. It only routes; the MTU fault is set on its link to host-b | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |
| host-b | Linux server running `scripts/tcp-server.py` (a small Python test server) | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

The test server on host-b starts by itself when the lab starts:

| Port on host-b | What it does | Used for |
|---|---|---|
| 8080 | sends 200,000 bytes, then closes normally | the normal case, the silent drop, packet loss |
| 8081 | **nothing listens** | the refused connection (reset) |
| 8082 | accepts and never reads | the zero window |
| 8083 | sends 30,000 bytes, then resets the connection | the reset in the middle of a session |
| 8085 | reads everything it is sent | the MTU black hole and the port-exhaustion exercise |

## Files

- `tcp-troubleshooting.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1's addresses.
- `scripts/tcp-server.py` - the test server (read it; it is 30 lines).
- `scripts/faults.sh` - switches the `drop`, `loss` and `mtu` faults on and off.
- `scripts/make-captures.sh` - re-records the six sample captures (the lab must be running).
- `tcp-troubleshooting.drawio` and `tcp-troubleshooting.png` - the prepared diagram.
- `captures/` - sample captures recorded from this lab on the VM, to open in Wireshark (only the first 200 bytes of each packet are kept, so the files are small): `tcp-fault-drop`, `tcp-fault-reject`, `tcp-fault-loss`, `tcp-fault-zerowin`, `tcp-fault-mtu`, `tcp-fault-midrst` (`.pcapng`).

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `tcp-troubleshooting` > right-click `tcp-troubleshooting.clab.yml` > **Deploy**. Wait for the three green dots, then about 10 more seconds for r1 to load its addresses. Run one lab at a time.
- **Reset to the lesson start (this also clears every fault):** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/tcp-troubleshooting
  ```
  ```
  containerlab redeploy -c -t tcp-troubleshooting.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below. Keep capture files in your Home folder.

## Check it works

```
docker exec clab-tcp-troubleshooting-host-a ping -c 3 172.16.100.20
```
Three replies. Then the normal case, which downloads 200,000 bytes:
```
docker exec clab-tcp-troubleshooting-host-a sh -c "nc -w 5 172.16.100.20 8080 | wc -c"
```
It prints `200000`.

## How to capture

For every fault: start the capture first, in Ubuntu's Terminal app (not VS Code's terminal), then run the commands in a second Terminal window. Use a new file name each time. The capture records host-a's cable:
```
sudo containerlab capture --name tcp-troubleshooting --target host-a:eth1 --duration 15s -w - > "$HOME/neo-fault1.pcapng"
```
Open the file in Wireshark. Useful filters: `tcp.port == 8080`, `tcp.flags.reset == 1`, `tcp.analysis.retransmission`, `tcp.analysis.zero_window`, `icmp`.

Switch faults on and off from the lab folder (VS Code terminal):
```
cd ~/labs-main/containerlab/labs/tcp-troubleshooting
```

## The six faults

The lesson's method: say what you expected, capture, then compare. In each fault, write down the expected behaviour first.

**1. Silent drop (port 8080).** Switch the filter on, then connect:
```
bash scripts/faults.sh drop on
```
```
docker exec clab-tcp-troubleshooting-host-a nc -w 10 172.16.100.20 8080
```
Nothing prints and nc gives up after 10 seconds. In the capture there is one SYN, sent again about once a second (later every 2 seconds), and nothing ever comes back. Silence is not proof that the server is down: this server is up, and a filter in front of it discarded the packets. Switch it off: `bash scripts/faults.sh drop off`.

**2. Refused (port 8081).** Nothing listens on this port:
```
docker exec clab-tcp-troubleshooting-host-a nc -w 3 172.16.100.20 8081
```
It ends at once. The capture has two packets: the SYN and an immediate `RST, ACK`. The address is reachable; something answering for it said no. (The RST here comes from host-b itself. A filter that rejects would look the same at the client; a TTL difference between the RST and host-b's other packets is a hint, not proof.)

**3. Packet loss (port 8080).** Real random loss from netem on host-b:
```
bash scripts/faults.sh loss on
```
```
docker exec clab-tcp-troubleshooting-host-a sh -c "nc -w 10 172.16.100.20 8080 | wc -c"
```
It still prints `200000` (TCP recovers) but takes longer. In the capture look for `tcp.analysis.retransmission`, duplicate ACKs and `tcp.analysis.fast_retransmission`. On host-b, `ss -ti` shows the retransmit counters. Switch it off: `bash scripts/faults.sh loss off`.

**4. Zero window (port 8082).** host-a sends 3 MB to a server that accepts the connection and never reads:
```
docker exec clab-tcp-troubleshooting-host-a sh -c "head -c 3000000 /dev/zero | nc -w 8 172.16.100.20 8082"
```
The transfer stalls. In the capture host-b's ACKs advertise a window that shrinks to 0 (`tcp.analysis.zero_window`), and host-a sends small zero-window probes. The network is fine; the receiver is the limit. A traceroute would not help. To see the receiver's queue: `docker exec clab-tcp-troubleshooting-host-b ss -tn` (a large `Recv-Q`).

**5. MTU black hole (port 8085).** r1's link to host-b drops to MTU 600, and a filter on r1 drops only its "fragmentation needed" messages (ICMP type 3, code 4) on the way to host-a, so host-a never hears them. Other ICMP, such as ping replies, still gets through:
```
bash scripts/faults.sh mtu on
```
```
docker exec clab-tcp-troubleshooting-host-a sh -c "head -c 100000 /dev/zero | nc -w 10 172.16.100.20 8085"
```
The handshake works and small packets work, but the big data packets vanish and host-a keeps retransmitting the same one (`seq 1:9449`) with growing gaps. No ICMP message comes back: r1 does send `fragmentation needed` (ICMP type 3, code 4), but the fault's filter drops it before it reaches host-a. Check the size limit with a ping that may not fragment: `docker exec clab-tcp-troubleshooting-host-a ping -c 2 -M do -s 1000 172.16.100.20` fails with `2 packets transmitted, 0 received, 100% packet loss` (a 1028-byte packet is larger than 600), while `-s 500` gets both replies (`2 received`): the filter drops only the "fragmentation needed" messages, not the echo replies. Switch it off: `bash scripts/faults.sh mtu off`.

**6. Reset in the middle of a session (port 8083).** The server sends 30,000 bytes, waits a second, then aborts:
```
docker exec clab-tcp-troubleshooting-host-a sh -c "nc -w 5 172.16.100.20 8083 | wc -c"
```
host-a receives the 30,000 bytes, then a `RST` arrives instead of the normal FIN exchange. A normal close is FIN, FIN, ACK; a RST is an abort. (In the lesson the reset can also come from a firewall or other middlebox in the path. Here host-b sends it, because the lab has no middlebox.)

## Exercise: port exhaustion (port 8085)

Limit host-a to ten local ports, then open sixteen short connections that host-a closes first:
```
docker exec clab-tcp-troubleshooting-host-a sysctl -w net.ipv4.ip_local_port_range="40000 40009"
```
```
docker exec clab-tcp-troubleshooting-host-a sh -c 'for i in $(seq 16); do echo hi | nc -w 1 172.16.100.20 8085; echo "try $i exit $?"; done'
```
```
docker exec clab-tcp-troubleshooting-host-a ss -tan state time-wait
```
About ten connections succeed and the rest fail because every local port is in TIME-WAIT (the closing side holds the four-tuple for 60 seconds). The limit is on the client, not the path. Restore it with `containerlab redeploy -c -t tcp-troubleshooting.clab.yml`.

## Troubleshooting

1. **`bash scripts/faults.sh ...` says `No such file` or `docker: command not found`.** Run it from the lab folder on the VM: `cd ~/labs-main/containerlab/labs/tcp-troubleshooting`, then `bash scripts/faults.sh drop on`.
2. **A fault seems to do nothing.** Each fault has its own port: `drop` and `loss` and `mtu` act on port 8080 (switch them on first), 8081 is closed, 8082 never reads and 8083 resets mid-transfer. Test the fault's own port. Switch a fault off with `off`, or reset everything with `containerlab redeploy -c -t tcp-troubleshooting.clab.yml`.
3. **The first ping fails right after Deploy.** r1 (FRR) loads its addresses 10 to 20 seconds after the green dots. Wait and ping again.
4. **The zero-window test (port 8082) looks different the second time.** The test server on host-b never reads and keeps every earlier connection open. Reset with `containerlab redeploy -c -t tcp-troubleshooting.clab.yml` (this also clears every fault) before you run it again.
5. **The capture file is empty.** Start the capture first, in Ubuntu's Terminal app with `sudo` and `--target host-a:eth1`, then run the test in a second window while it records.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/tcp-troubleshooting
```
```
containerlab destroy --cleanup -t tcp-troubleshooting.clab.yml
```
`--cleanup` also removes the generated `clab-tcp-troubleshooting` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-tcp-troubleshooting` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/tcp-troubleshooting/clab-tcp-troubleshooting
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- No delay fault (the long-delay case in the lesson is explained, not run). You can add one yourself: `docker exec clab-tcp-troubleshooting-host-b tc qdisc add dev eth1 root netem delay 200ms`.
- No firewall or middlebox: the silent drop is a filter on host-b, and the mid-session reset comes from host-b. A real path would have these in a firewall or router.
