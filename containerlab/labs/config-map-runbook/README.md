# Lab: Network maps and runbooks from configs

**Folder:** `labs/config-map-runbook/`  **Lab file:** `config-map-runbook.clab.yml`  **Lesson:** NEO-29 Network maps and runbooks from configs  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** four Linux containers (c, x, y, web) and two of our own scripts: `netmap.py` builds a map from stored configs only, and `runbook.py` runs a read-only live check. This is **not a commercial mapping product**. No SR Linux and no FRR in this lab: the scripts read and apply `ip -batch` lines, and the lab stays small. A **planted gap** is already in y's stored config: there is no route back to c's subnet. The runbook never changes anything; a person adds the missing route by hand, then updates the stored file after review.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: four Linux containers, about 23 MB together (measured; peak on a fresh deploy). No SR Linux and no FRR in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/config-map-runbook/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
 c 10.29.1.10 ---- x 10.29.1.1         y 10.29.2.1 ---- web 10.29.2.20 :80
                   10.29.12.1 -------- 10.29.12.2
```

| Node | Role | Address | Open |
|---|---|---|---|
| c | Client | 10.29.1.10/24, gateway 10.29.1.1 | Attach Shell |
| x | Linux router | eth1 10.29.1.1/24, eth2 10.29.12.1/30; route to 10.29.2.0/24 via y | Attach Shell |
| y | Linux router, planted gap | eth1 10.29.12.2/30, eth2 10.29.2.1/24; **no** route back to 10.29.1.0/24 | Attach Shell |
| web | Web server | 10.29.2.20/24, gateway 10.29.2.1 | Attach Shell |

The mapper's rule is simple: two addresses in the same subnet are a link. That is a guess from the configs, not a proof (a switch in the middle would not show). It traces a path with longest-prefix match, in both directions, from the stored files only. The runbook reaches each container with `docker exec` (real tools use SSH or an API with a read-only account).

## Files

- `config-map-runbook.clab.yml` - the lab file.
- `config-map-runbook.drawio` and `config-map-runbook.png` - the prepared diagram.
- `configs/c.conf`, `x.conf`, `y.conf`, `web.conf` - stored configs as `ip -batch` lines, applied as written at deploy.
- `scripts/netmap.py` - the mapper (`links` and `path`).
- `scripts/runbook.py` - the read-only runbook and the drift check.
- `scripts/fault.sh` - `1` puts the planted gap back on y; `2` applies the live fix on y (the stored file is not changed).
- `scripts/make-captures.sh` - records the sample captures again.
- `captures/` - sample packet captures for the exercises.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `config-map-runbook` > right-click `config-map-runbook.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal** from the lab folder:
  ```
  python3 scripts/netmap.py links configs
  ```
  It prints three links (c–x on 10.29.1.0/24, x–y on 10.29.12.0/30, y–web on 10.29.2.0/24).
- **Reset to the lesson start** (y's return route is gone again; the stored files are unchanged):
  ```
  cd ~/labs-main/containerlab/labs/config-map-runbook
  ```
  ```
  containerlab redeploy -c -t config-map-runbook.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/config-map-runbook`).

**1. Map the links from the configs.** The mapper never talks to the live devices. It only reads the files:
```
python3 scripts/netmap.py links configs
```
It lists three links from shared subnets: c–x, x–y and y–web. A shared subnet is a guess, not a proof.

**2. Trace both directions from the configs.** The forward path should arrive; the return path should break at y (the planted gap):
```
python3 scripts/netmap.py path configs c 10.29.2.20
```
```
python3 scripts/netmap.py path configs web 10.29.1.10
```
The first command ends `web: is 10.29.2.20  -> arrived`. The second ends `y: no route to 10.29.1.10  -> path breaks here`. The map already shows the fault, before you send a packet.

**3. Run the live runbook.** It is read-only. It checks interfaces, the forward path, the return path, and a TCP probe (2 s timeout):
```
python3 scripts/runbook.py c 10.29.2.20 80
```
Steps 1 and 2 PASS. Step 3 FAIL at y (`Network is unreachable`). Step 4 FAIL (`TimeoutError`). These routers have no management default route, so a missing lab route is not hidden. (Sample `cmap-1-no-return.pcapng`, recorded on web: c's pings arrive and the replies leave; y sends `ICMP net 10.29.1.10 unreachable`. Only one unreachable may appear: the kernel rate-limits them.)

**4. Fix it live, then see the drift.** Add the missing route on y by hand (this is not the runbook; a person types it). Then run the runbook again:
```
docker exec clab-config-map-runbook-y ip route add 10.29.1.0/24 via 10.29.12.1
```
```
python3 scripts/runbook.py c 10.29.2.20 80
```
All four steps PASS, and step 4 prints `connected`. The page would load now (`curl` from c prints `hello from web (10.29.2.20)`). The stored config still has the gap:
```
python3 scripts/netmap.py path configs web 10.29.1.10
```
```
python3 scripts/runbook.py drift
```
The model still breaks at y. The drift check reports that y has a live route that is not in `y.conf`. (Sample `cmap-2-fixed.pcapng`, recorded on web: c loads the page after the live fix.)

**5. Update the record.** After review, the route goes into the stored file. Make a working copy and add the line, as a person would after approving the change, then check the model and the drift:
```
mkdir -p configs_after
```
```
cp -a configs/. configs_after/
```
```
echo 'route add 10.29.1.0/24 via 10.29.12.1' >> configs_after/y.conf
```
```
python3 scripts/netmap.py path configs_after web 10.29.1.10
```
```
CONF=configs_after python3 scripts/runbook.py drift
```
The model's return path now arrives, and the drift check PASSES. The approved change is to update the record, not to leave a live-only fix. `configs_after` is a working copy next to the lab files; it is not applied at deploy.

## Sample captures

Open them in Wireshark with File > Open. The display filters `icmp` and `tcp.port == 80` each show one kind of frame.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `cmap-1-no-return.pcapng` | web:eth1 | 6 | exercise 3: c's echo requests arrive and the replies leave; y sends `ICMP net 10.29.1.10 unreachable` (only one may appear) |
| `cmap-2-fixed.pcapng` | web:eth1 | 13 | exercise 4: after the live fix, c loads `GET /` and web answers 200 |

Frame counts move by a few frames from run to run (IPv6 router solicitations right after a fresh deploy, and ARP timing).

## What this lab does not do

- Not a commercial mapping or runbook product: the two scripts are ours, and the README says so.
- The mapper models IPv4 static routes and connected subnets only. It ignores filters, NAT and switches.
- The runbook never changes a device. The live fix is typed by a person on y.
- Collection over SSH or an API is not run; `docker exec` stands in for it.

## Troubleshooting

1. **The check in Start prints nothing.** The lab may still be starting: wait 5 seconds and try again, or reset the lab. Run the command from the lab folder so `scripts/` and `configs/` are found.
2. **Step 3 of the runbook PASSES before you add the route.** The live fix is still in place. Put the gap back with `bash scripts/fault.sh 1`, or reset the lab.
3. **`runbook.py` cannot reach a container.** Confirm the lab is deployed: `docker exec clab-config-map-runbook-y ip route` should print y's table.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh <n>`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/config-map-runbook
```
```
containerlab destroy --cleanup -t config-map-runbook.clab.yml
```
`--cleanup` also removes the generated `clab-config-map-runbook` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-config-map-runbook` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/config-map-runbook/clab-config-map-runbook
```
Your capture files in your Home folder are not touched.
