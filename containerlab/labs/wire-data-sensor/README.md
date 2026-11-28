# Lab: Wire data, a passive sensor, and an unknown host

**Folder:** `labs/wire-data-sensor/`  **Lab file:** `wire-data-sensor.clab.yml`  **Lesson:** NEO-28 Wire data and network detection  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** a **passive sensor** sees every frame on a small segment, inventories the hosts that talk, and finds an unknown host. The sensor has no address on the span link and does not forward or block anything; it only records. A real commercial wire-data sensor sits on a **SPAN or TAP**. This lab uses a Linux bridge with MAC learning turned off so every port sees every frame, like a hub. That is a stand-in, not a SPAN session. Commercial wire-data and Cisco SPAN commands are listed as text to compare (`configs/sensor-reference.txt`). No SR Linux in this lab. The sensor records with **tcpdump** (open the files in Wireshark).

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: five Linux containers, about 26 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/wire-data-sensor/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
   client 10.28.1.10 ----+
                         |
   unknown 10.28.1.99 ---+--- hub (Linux bridge, learning off) --- server 10.28.1.20 (web :80)
                         |
   sensor (no IP) -------+     span stand-in: the sensor sees every frame
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| client | 10.28.1.10/24, MAC 02:00:00:28:01:10. The known user; it loads the web page | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| unknown | 10.28.1.99/24, MAC 02:00:00:28:01:99. On the segment from the start, but silent until `scripts/fault.sh 1` starts it talking | same | Attach Shell |
| server | 10.28.1.20/24, MAC 02:00:00:28:01:20; web server on port 80 | same | Attach Shell |
| hub | A Linux bridge with MAC learning turned off and flooding on, so every port sees every frame (a hub, or a SPAN of this segment). That is the stand-in | same | Attach Shell |
| sensor | No IP address on eth1; the interface is promiscuous. It only listens | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64. Each box also has a management interface, eth0 (172.20.20.x), which the lab traffic does not use.

## Files

- `wire-data-sensor.clab.yml` - the lab drawing. Addresses, the hub, the web server and the sensor's promiscuous flag are set by each node's `exec` lines.
- `configs/sensor-reference.txt` - a commercial wire-data tool and Cisco SPAN commands, as text only.
- `scripts/unknown.py` - the unknown host's traffic: `GET /admin` to the web server, every two seconds (the server answers 404).
- `scripts/fault.sh` - puts the fault of exercise 3 in place: `bash scripts/fault.sh 1` starts that traffic; `bash scripts/fault.sh 2` stops it.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes under a minute, starts and stops the unknown host's traffic, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `wire-data-sensor.drawio` and `wire-data-sensor.png` - the prepared diagram.
- `captures/` - three sample captures: `wd-1-client-page.pcapng`, `wd-2-unknown-host.pcapng`, `wd-3-both.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `wire-data-sensor` > right-click `wire-data-sensor.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-wire-data-sensor-client curl -s -m 3 http://10.28.1.20/
  ```
  It prints `hello from server (10.28.1.20)`.
- **Reset to the lesson start** (the unknown host is silent again):
  ```
  cd ~/labs-main/containerlab/labs/wire-data-sensor
  ```
  ```
  containerlab redeploy -c -t wire-data-sensor.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/wire-data-sensor`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. The sensor sees the client's page.** In a second terminal, start a live view on the sensor (it stops by itself after 8 seconds, or stop it with Ctrl+C):
```
docker exec clab-wire-data-sensor-sensor timeout 8 tcpdump -lni eth1 tcp port 80
```
In the first terminal, load the page:
```
docker exec clab-wire-data-sensor-client curl -s -m 3 http://10.28.1.20/
```
It prints `hello from server (10.28.1.20)`. tcpdump on the sensor shows the TCP handshake, the client's `GET /`, and the server's reply, even though none of those frames is addressed to the sensor's MAC (`02:00:00:28:01:50`). That is the point of a SPAN, a TAP, or this hub stand-in: the sensor is not in the path, and it still sees both directions. Stop tcpdump in the second terminal with Ctrl+C. (Sample `wd-1-client-page.pcapng`, recorded on the sensor: the known client's page load.)

**2. Inventory the hosts that talk.** Open `captures/wd-1-client-page.pcapng` in Wireshark (File > Open). Use Statistics > Endpoints (or the display filter `http`) and write down every IPv4 address and MAC address you see on the segment.
Write this down as the known inventory (it is also what the sample capture shows):
```
echo "known inventory: 10.28.1.10 (client, 02:00:00:28:01:10) and 10.28.1.20 (server, 02:00:00:28:01:20)"
```
The known inventory is two devices: the client 10.28.1.10 (`02:00:00:28:01:10`) and the server 10.28.1.20 (`02:00:00:28:01:20`). A commercial wire-data tool builds the same list from the wire, often with a guessed role or name. 10.28.1.99 is already on the segment, but it has not talked, so it is not in this inventory yet.

**3. Find the unknown host.** Put the fault in place, then watch the sensor:
```
bash scripts/fault.sh 1
```
```
docker exec clab-wire-data-sensor-sensor timeout 6 tcpdump -lni eth1 tcp port 80
```
A new address appears: `10.28.1.99` (`02:00:00:28:01:99`) talking to the server on port 80. That address was not in the inventory of exercise 2. The server answers, but the request is not the known client's `GET /`. (Sample `wd-2-unknown-host.pcapng`, recorded on the sensor: the unknown host's requests.)

**4. What is it doing?** Look at the payload, then compare it with the known client in one capture:
```
docker exec clab-wire-data-sensor-sensor timeout 6 tcpdump -lni eth1 -A tcp port 80
```
```
docker exec clab-wire-data-sensor-client curl -s -m 3 http://10.28.1.20/
```
The unknown host repeats `GET /admin HTTP/1.1` and the server answers `404`. The known client still uses `GET /` and gets `200`. A commercial wire-data tool would show the new device, the conversation, and the unusual path next to the known one. Stop the unknown host when you have seen both:
```
bash scripts/fault.sh 2
```
(Sample `wd-3-both.pcapng`, recorded on the sensor: the known `GET /` and the unknown `GET /admin` in one file. In Wireshark, `http.request.uri == "/admin"` shows only the unknown host.)

## Sample captures

Open them in Wireshark with File > Open. The display filters `tcp.port == 80`, `http`, and `http.request.uri == "/admin"` each show one kind of frame.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `wd-1-client-page.pcapng` | sensor:eth1 | 12 | exercise 1: the known client (10.28.1.10) loads `GET /` and the server (10.28.1.20) answers 200 |
| `wd-2-unknown-host.pcapng` | sensor:eth1 | 51 | exercise 3: the unknown host (10.28.1.99) repeats `GET /admin` and the server answers 404 |
| `wd-3-both.pcapng` | sensor:eth1 | 59 | exercise 4: both conversations in one file |

Frame counts move by a few frames from run to run (TCP acknowledgements, and how many `/admin` requests fall inside the recording).

## What this lab does not do

- Not an ExtraHop product and not a switch SPAN: a Linux bridge with learning turned off is the stand-in, and the README says so. Vendor commands are text only.
- The sensor does not block or inject traffic. It only records.
- The unknown host's traffic is started by `scripts/fault.sh`, not by a real compromise.

Not affiliated with or endorsed by any network-detection vendor or by Cisco Systems. This lab is not an ExtraHop product and does not run a switch SPAN. Vendor commands in this folder are text to compare. ExtraHop, Cisco and SPAN are trademarks of their owners.

## Troubleshooting

1. **The check in Start prints nothing.** The web server may still be starting: wait 5 seconds and try again, or reset the lab.
2. **tcpdump on the sensor shows no frames when the client curls.** Confirm the hub is flooding: `docker exec clab-wire-data-sensor-hub bridge link show` should say `learning off` on each port, and `docker exec clab-wire-data-sensor-sensor ip -d link show eth1` should mention `PROMISC`.
3. **Exercise 3 shows no 10.28.1.99.** Confirm the fault is in place: `docker exec clab-wire-data-sensor-unknown pgrep -af unknown.py` should list the script. Run `bash scripts/fault.sh 1` again and wait two seconds.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/wire-data-sensor
```
```
containerlab destroy --cleanup -t wire-data-sensor.clab.yml
```
`--cleanup` also removes the generated `clab-wire-data-sensor` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-wire-data-sensor` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/wire-data-sensor/clab-wire-data-sensor
```
Your capture files in your Home folder are not touched.
