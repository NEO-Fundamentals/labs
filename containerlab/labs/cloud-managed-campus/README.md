# Lab: Cloud-managed campus networks

**Folder:** `labs/cloud-managed-campus/`  **Lab file:** `cloud-managed-campus.clab.yml`  **Lesson:** NEO-30 Cloud-managed campus networks  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** a stand-in cloud controller (`controller`) and two device agents (`east`, `west`), all our own Python scripts, plus a campus edge, a client and a web server. This is **not a commercial cloud-managed network product**. The controller speaks **plain HTTP**; a real cloud uses TLS with device certificates. The management plane (config and status) goes to the controller; the data plane (client to web) stays on the devices. No SR Linux and no FRR in this lab. An unclaimed serial gets HTTP 403; after you claim it, the agent applies the campus config. If the controller is cut off, forwarding continues with the last config.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: six Linux containers, about 65 MB together (measured; peak after the sample captures). No SR Linux and no FRR in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/cloud-managed-campus/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
 controller 10.30.3.10:8080
        |
      edge 10.30.3.1 / 10.30.1.1
       /                  \
    east                   west
  10.30.1.11             10.30.1.12
    |                      |
  client 10.30.10.10     web 10.30.10.130 :80
```

At deploy, east and west have only an uplink address and a default route (factory state). Their LAN address and the route to the other side of the campus come from the controller after you claim each serial. The client and web are already addressed on those LANs, so they wait until the agents apply the config.

| Node | Role | Address | Open |
|---|---|---|---|
| controller | Stand-in cloud (plain HTTP :8080) | 10.30.3.10/24, gateway 10.30.3.1 | Attach Shell |
| edge | Campus gateway | eth1 10.30.3.1/24, br0 10.30.1.1/24 (east and west) | Attach Shell |
| east | Device agent, serial EAST-7F3K | eth1 10.30.1.11/24; LAN comes from the cloud | Attach Shell |
| west | Device agent, serial WEST-2M9Q | eth1 10.30.1.12/24; LAN comes from the cloud | Attach Shell |
| client | Host behind east | 10.30.10.10/25, gateway 10.30.10.1 | Attach Shell |
| web | Web server behind west | 10.30.10.130/25, gateway 10.30.10.129 | Attach Shell |

Each agent calls **out** to the controller every 2 seconds. It opens no listening port. The controller marks a device offline after 6 seconds without a check-in. A template change bumps the config version for every claimed device.

## Files

- `cloud-managed-campus.clab.yml` - the lab file.
- `cloud-managed-campus.drawio` and `cloud-managed-campus.png` - the prepared diagram.
- `scripts/cloud.py` - the stand-in controller (`serve`, `claim`, `devices`, `template`).
- `scripts/agent.py` - the device agent (runs on east and west at deploy).
- `scripts/fault.sh` - `1` cuts the controller off at the edge; `2` brings the link back.
- `scripts/make-captures.sh` - records the sample captures again.
- `captures/` - sample packet captures for the exercises.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `cloud-managed-campus` > right-click `cloud-managed-campus.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
  ```
  It prints the column header and no devices (nothing is claimed yet). If it prints nothing, wait 5 seconds (the controller is still starting) and try again.
- **Reset to the lesson start** (claims and LAN config are gone; agents start unclaimed again):
  ```
  cd ~/labs-main/containerlab/labs/cloud-managed-campus
  ```
  ```
  containerlab redeploy -c -t cloud-managed-campus.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/cloud-managed-campus`).

**1. Claim the devices.** The agents are already running and, until you claim them, the controller answers 403. Claim both serials, wait a few seconds, then look at an agent log:
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py claim EAST-7F3K east
```
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py claim WEST-2M9Q west
```
```
sleep 3
```
```
docker exec clab-cloud-managed-campus-east cat /var/log/agent.log
```
The claims print `claimed EAST-7F3K as east` and `claimed WEST-2M9Q as west`. The log shows `controller says 403: serial not claimed`, then `applied config v1` and `in sync at v1`.

**2. The controller lists them online.**
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
```
Both show `v1/v1` (applied / latest) and `online`.

**3. The data plane does not go through the cloud.** After the agents apply the config, east has a LAN address and a route to web via west. The client reaches the web server device to device:
```
docker exec clab-cloud-managed-campus-east ip -br addr show eth2
```
```
docker exec clab-cloud-managed-campus-east ip route get 10.30.10.130
```
```
docker exec clab-cloud-managed-campus-client curl -s -m 3 http://10.30.10.130/
```
eth2 has `10.30.10.1/25`. The route to 10.30.10.130 goes `via 10.30.1.12`. The curl prints `hello from web (10.30.10.130)`. (Sample `cmc-1-path.pcapng`, recorded on west's campus uplink: the client's page load.)

**4. One template change reaches every device.**
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py template lan_mtu 1400
```
```
sleep 3
```
```
docker exec clab-cloud-managed-campus-east ip link show eth2
```
```
docker exec clab-cloud-managed-campus-west ip link show eth2
```
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
```
The template command prints `now version 2`. Both LAN links show `mtu 1400`. The device list is `v2/v2` for both. A real rollout stages a change on a few devices first; this lab applies it everywhere at once.

**5. The cloud is cut off; forwarding continues.** Put the fault in place, wait long enough for the controller to mark the devices offline (6 seconds without a check-in), then test the page and the list:
```
bash scripts/fault.sh 1
```
```
sleep 9
```
```
docker exec clab-cloud-managed-campus-client curl -s -m 3 http://10.30.10.130/
```
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
```
The curl still prints `hello from web (10.30.10.130)`. The list shows both devices `offline`. A change made while they are offline stays pending until they check in again:
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py template lan_mtu 1450
```
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
```
The list shows `v2/v3` and `offline`. Bring the link back and wait for a check-in:
```
bash scripts/fault.sh 2
```
```
sleep 4
```
```
docker exec clab-cloud-managed-campus-controller python3 /neo/scripts/cloud.py devices
```
```
docker exec clab-cloud-managed-campus-east cat /var/log/agent.log
```
The list returns to `v3/v3` `online`. The agent log shows `controller unreachable (...); keep v2`, then `applied config v3`. (Sample `cmc-2-outage.pcapng`: the page still loads while the controller is cut off. Sample `cmc-3-poll.pcapng`, recorded on the controller link: the agent polls over plain HTTP.)

**6. The cloud never connects in.** From the controller, a connection to east is refused; east has no listening socket:
```
docker exec clab-cloud-managed-campus-controller python3 -c 'import socket,sys; s=socket.socket(); s.settimeout(2)
try:
 s.connect(("10.30.1.11", 443)); print("connected")
except Exception as e:
 print(type(e).__name__)'
```
```
docker exec clab-cloud-managed-campus-east ss -ltn
```
It prints `ConnectionRefusedError`. `ss -ltn` shows no listener on the campus or LAN addresses. A loopback listener, if one appears, is Docker's internal name server, not an agent socket.

## Sample captures

Open them in Wireshark with File > Open. The display filters `tcp.port == 80` and `tcp.port == 8080` each show one kind of frame.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `cmc-1-path.pcapng` | west:eth1 | 62 | exercise 3: the client loads `GET /` from web, on the campus path, not through the controller |
| `cmc-2-outage.pcapng` | west:eth1 | 20 | exercise 5: the same page load while the controller link is down |
| `cmc-3-poll.pcapng` | controller:eth1 | 97 | an agent check-in over plain HTTP to port 8080 (a real cloud would use TLS) |

Frame counts move by a few frames from run to run (IPv6 router solicitations, ARP timing, and how many 2 s polls fall in the window).

## What this lab does not do

- Not a vendor cloud product: the controller and agents are our own scripts, and the README says so.
- The controller speaks plain HTTP, not TLS, and there is no certificate or zero-touch discovery (DHCP/DNS).
- Staged rollout, RBAC and cloud-only features (for example cloud sign-in) are not run.

## Troubleshooting

1. **The check in Start prints nothing or connection refused.** The controller may still be starting: wait 5 seconds and try again, or reset the lab.
2. **After the claim, the client cannot reach web.** Wait a few more seconds for both agents to apply v1 (`docker exec clab-cloud-managed-campus-east cat /var/log/agent.log` should say `applied config v1`). Confirm east has `10.30.10.1` on eth2.
3. **Exercise 5 still shows `online`.** Wait the full 9 seconds after `fault.sh 1`; the controller marks a device offline only after 6 seconds without a check-in.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/cloud-managed-campus
```
```
containerlab destroy --cleanup -t cloud-managed-campus.clab.yml
```
`--cleanup` also removes the generated `clab-cloud-managed-campus` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-cloud-managed-campus` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/cloud-managed-campus/clab-cloud-managed-campus
```
Your capture files in your Home folder are not touched.
