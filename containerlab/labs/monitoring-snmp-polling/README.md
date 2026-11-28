# Lab: Monitoring and alerting with SNMPv2c

**Folder:** `labs/monitoring-snmp-polling/`  **Lab file:** `monitoring-snmp-polling.clab.yml`  **Lesson:** NEO-27 Monitoring and alerting  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** a Linux poller asks a Linux router (`r1`) for its interface counters and status over **SNMPv2c**, then raises an alert when a link goes down or when traffic in one poll interval crosses a threshold. r1 runs **Net-SNMP** (`snmpd`) and forwards packets between the poller and a web server (`web`). This is Net-SNMP, **not a commercial NMS**: a commercial NMS and SR Linux SNMP commands are listed as text to compare (`configs/nms-reference.txt`). No SR Linux in this lab: Linux snmpd teaches the same here, in a few MB of memory. SNMPv2c sends the community string in the clear; a capture of the poller link will show it.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: three Linux containers, about 26 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/monitoring-snmp-polling/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
   poller                 r1                       web
   10.27.1.10 ---- eth1 10.27.1.1   10.27.2.1 eth2 ---- 10.27.2.20
   SNMPv2c get/walk       snmpd on :161                  web :80, also /big.bin
                          (community "neo")
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| poller | 10.27.1.10/24, gateway 10.27.1.1. Runs `scripts/snmp.py` (Get, Walk, a table of interfaces) and `scripts/poller.py` (a line every 5 seconds, and an ALERT when a test fails) | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| r1 | Linux router and SNMP agent: eth1 10.27.1.1/24 (poller LAN), eth2 10.27.2.1/24 (host LAN). `snmpd` loads `configs/snmpd.conf` at deploy (SNMPv2c, community `neo`, read-only, only from 10.27.1.0/24) | same | Attach Shell |
| web | 10.27.2.20/24, gateway 10.27.2.1; web server on port 80 (`/` and a 200 KB file `/big.bin`, used to generate traffic through r1) | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**OIDs, not names.** An OID is the number that names one SNMP object (for example `.1.3.6.1.2.1.1.5.0` is `sysName`). The usual command is `snmpwalk`; this image does not ship the MIB name files, so the lab uses a small helper that asks by OID (or by a short name the helper already knows). The table below is the same list a MIB file would give you.

| Name | OID | What it is |
|---|---|---|
| `sysName` | `.1.3.6.1.2.1.1.5.0` | the device's name (`r1`) |
| `sysDescr` | `.1.3.6.1.2.1.1.1.0` | a one-line description of the software |
| `sysLocation` | `.1.3.6.1.2.1.1.6.0` | where the device is (`NEO lab`) |
| `ifDescr` | `.1.3.6.1.2.1.2.2.1.2` | interface name (`eth0`, `eth1`, `eth2`; `lo` is there too) |
| `ifAdminStatus` | `.1.3.6.1.2.1.2.2.1.7` | administratively up or down (1 = up, 2 = down) |
| `ifOperStatus` | `.1.3.6.1.2.1.2.2.1.8` | operationally up or down (1 = up, 2 = down) |
| `ifInOctets` | `.1.3.6.1.2.1.2.2.1.10` | bytes received on that interface (32-bit counter) |
| `ifOutOctets` | `.1.3.6.1.2.1.2.2.1.16` | bytes sent on that interface (32-bit counter) |

The last number of an interface OID is the **ifIndex** (the interface's number on this device). eth2, the link toward the web server, is the interface the poller watches. The web server node is named `web` (not `host`): containerlab would attach that link to the Docker host itself if the node were named `host`.

## Files

- `monitoring-snmp-polling.clab.yml` - the lab drawing. Addresses, routes, snmpd and the web server are set by `scripts/start-poller.sh`, `scripts/start-r1.sh` and `scripts/start-web.sh` (each waits until its lab interface exists).
- `configs/snmpd.conf` - r1's SNMP agent. `configs/nms-reference.txt` - a commercial NMS and SR Linux SNMP commands, as text only.
- `scripts/snmp.py` - Get, Walk, and a table of interfaces. `scripts/poller.py` - a line every 5 seconds and an ALERT when a test fails (log `/var/log/poller.log`).
- `scripts/fault.sh` - puts the fault of exercise 3 in place: `bash scripts/fault.sh 1` shuts r1's eth2; `bash scripts/fault.sh 2` brings it back.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes under a minute and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `monitoring-snmp-polling.drawio` and `monitoring-snmp-polling.png` - the prepared diagram.
- `captures/` - three sample captures: `mon-1-interfaces.pcapng`, `mon-2-down-alert.pcapng`, `mon-3-community.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `monitoring-snmp-polling` > right-click `monitoring-snmp-polling.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py get 10.27.1.1 neo sysName
  ```
  It prints `.1.3.6.1.2.1.1.5.0 = r1`. If it prints nothing, wait 5 seconds (snmpd is still starting) and try again.
- **Reset to the lesson start** (eth2 up, no poller left running):
  ```
  cd ~/labs-main/containerlab/labs/monitoring-snmp-polling
  ```
  ```
  containerlab redeploy -c -t monitoring-snmp-polling.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/monitoring-snmp-polling`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Discover the device and its interfaces.**
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py get 10.27.1.1 neo sysName
```
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py get 10.27.1.1 neo sysDescr
```
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py get 10.27.1.1 neo sysLocation
```
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py interfaces 10.27.1.1 neo
```
`sysName` is `r1`, `sysLocation` is `NEO lab`, and `sysDescr` names Linux and Net-SNMP. The table lists `lo`, `eth0` (the management link, which the lab traffic does not use), `eth1` (the poller LAN) and `eth2` (the host LAN). Each is `admin up` and `oper up`. Note eth2's ifIndex and its in-octets and out-octets; you will watch those next. (Sample `mon-1-interfaces.pcapng`, recorded on r1's eth1: SNMP GetNext on UDP port 161.)

**2. Counters move when traffic flows.** Read the table, send a small page through r1, and read it again:
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py interfaces 10.27.1.1 neo
```
```
docker exec clab-monitoring-snmp-polling-poller curl -s -m 3 http://10.27.2.20/
```
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py interfaces 10.27.1.1 neo
```
The curl prints `hello from web (10.27.2.20)`. eth2's in-octets and out-octets are higher on the second reading (the page and its replies passed r1). A commercial NMS graphs those same counters; here you read them twice by hand.

**3. An alert when a link goes down.** Start the poller in this terminal; leave it running. It writes one line every 5 seconds (and the same lines to `/var/log/poller.log`):
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/poller.py --iface eth2 --interval 5 --threshold 20000
```
The first line is a first reading (`ok    eth2 up`). The next lines are `ok    eth2 up, N bytes in 5 s` with a small N. In a second terminal, put the fault in place and watch the poller:
```
bash scripts/fault.sh 1
```
Within about 15 seconds (two or three poll intervals; the SNMP agent caches the interface table for a few seconds) the poller prints `ALERT eth2 ifOperStatus is down`. Confirm it yourself, and that the host is now unreachable:
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py interfaces 10.27.1.1 neo
```
```
docker exec clab-monitoring-snmp-polling-poller curl -s -m 3 -o /dev/null -w 'http %{http_code}\n' http://10.27.2.20/
```
eth2's oper status is `down`; the curl gets `http 000`. Bring the link back and watch the poller return to `ok`:
```
bash scripts/fault.sh 2
```
Stop the poller in the first terminal with Ctrl+C when you have seen the `ok` line again. (Sample `mon-2-down-alert.pcapng`, recorded on r1's eth1: the poller's Gets while eth2 is down.)

**4. An alert when traffic crosses a threshold.** Start the poller again:
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/poller.py --iface eth2 --interval 5 --threshold 20000
```
Wait for a first `ok` line. In a second terminal, pull the 200 KB file (well above 20 000 bytes):
```
docker exec clab-monitoring-snmp-polling-poller curl -s -m 5 -o /dev/null -w 'http %{http_code} %{size_download} bytes\n' http://10.27.2.20/big.bin
```
It prints `http 200 200000 bytes`. Within one interval the poller prints `ALERT eth2 traffic ... bytes in 5 s (threshold 20000)`, then returns to `ok` on the next quiet interval. Stop the poller with Ctrl+C. The threshold is a number you chose: a commercial NMS uses the same idea, with a longer interval and a threshold that fits the link.

**5. The community string is in the clear.** Record a single Get and open it:
```
docker exec clab-monitoring-snmp-polling-poller python3 /neo/scripts/snmp.py get 10.27.1.1 neo sysName
```
Open `captures/mon-3-community.pcapng` in Wireshark (File > Open). The display filter `udp.port == 161` shows the Get and the response. Expand the SNMP layer: the **community** field is `neo`, in the clear, next to `version: version-2c` and the OID for sysName. That is why SNMPv3 exists (a user, authentication, and optional encryption). The SR Linux and commercial-NMS commands for SNMPv3 are in `configs/nms-reference.txt`; this lab does not run SNMPv3. (Sample `mon-3-community.pcapng`, recorded on r1's eth1: one Get of sysName.)

## Sample captures

Open them in Wireshark with File > Open. The display filter `udp.port == 161` shows only SNMP.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `mon-1-interfaces.pcapng` | r1:eth1 (the poller link) | 54 | exercise 1: SNMP GetNext (UDP 161) walking the interface table; replies from 10.27.1.1 |
| `mon-2-down-alert.pcapng` | r1:eth1 | 50 | exercise 3: the poller's Gets while eth2 is down |
| `mon-3-community.pcapng` | r1:eth1 | 2 | exercise 5: one Get of sysName; the community string `neo` is in the clear |

Frame counts move by a few frames from run to run (the walk length depends on how many interfaces the agent lists).

## What this lab does not do

- Not a commercial NMS and not SR Linux: Net-SNMP and a small poller teach the same ideas (inventory, counters, a status alert, a traffic threshold). Vendor commands are text only.
- No SNMPv3 in the running lab (the reference file shows the commands). SNMPv2c is used so that a capture can show the community string.
- The "down" fault is made by `scripts/fault.sh`, not by a real cable pull.

Not affiliated with or endorsed by any monitoring-tool vendor or by the Net-SNMP project. This lab runs Net-SNMP, not a commercial NMS. Vendor commands in this folder are text to compare.

## Troubleshooting

1. **The check in Start prints an error, or nothing.** Wait 5 seconds for snmpd, or reset the lab. `docker exec clab-monitoring-snmp-polling-r1 pgrep -a snmpd` must list `snmpd`.
2. **Exercise 3 never prints ALERT.** Confirm the fault is in place: `docker exec clab-monitoring-snmp-polling-r1 ip -br link show eth2` should say `DOWN`. Wait up to 15 seconds (the agent caches the interface table for a few seconds).
3. **Exercise 4 never prints a traffic ALERT.** Wait for the poller's first `ok` line, then run the `curl` of `/big.bin`. If you start the curl before the first reading, the 200 KB can be folded into that first reading and missed.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/monitoring-snmp-polling
```
```
containerlab destroy --cleanup -t monitoring-snmp-polling.clab.yml
```
`--cleanup` also removes the generated `clab-monitoring-snmp-polling` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-monitoring-snmp-polling` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/monitoring-snmp-polling/clab-monitoring-snmp-polling
```
Your capture files in your Home folder are not touched.
