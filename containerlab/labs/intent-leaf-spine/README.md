# Lab: Intent-based data-center fabrics

**Folder:** `labs/intent-leaf-spine/`  **Lab file:** `intent-leaf-spine.clab.yml`  **Lesson:** NEO-31 Intent-based data-center fabrics  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** a two-spine, two-leaf fabric and our own tool (`fabric.py`) that renders one config per switch from a small intent file, deploys it, diffs two renders, and validates live state against the intent. This is **not a commercial fabric or intent product**. No SR Linux and no FRR: static routes with two ECMP next hops stand in for the fabric routing protocol (real fabrics run BGP or OSPF, usually with an EVPN-VXLAN overlay). Four SR Linux nodes would not fit the 8 GB lab VM. Deploy uses `docker exec` and `ip -batch` (real tools push over an API or SSH). Validation runs once per command, not on a loop.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: seven Linux containers, about 27 MB together (measured). No SR Linux and no FRR in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/intent-leaf-spine/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0`, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes. The fabric has no addresses until you render and deploy the intent (exercise 2).

## What this lab builds

```
        spine-1                spine-2
         /  \                  /  \
        /    \                /    \
   leaf-1                      leaf-2
   lan0                        lan0     lan1 (after intent v2)
     |                           |        |
  host-a 10.31.10.10      host-b 10.31.10.74   host-c 10.31.10.138
```

Every leaf has a link to every spine. The intent names the spines, the subnet on each leaf, and a pool for the spine–leaf link addresses. The tool works out the /31 addresses, the leaf gateways, and the routes (each leaf reaches the other rack via both spines).

| Node | Role | Address | Open |
|---|---|---|---|
| spine-1, spine-2 | Fabric spines | from the rendered intent (links in 10.31.0.0/24) | Attach Shell |
| leaf-1 | Leaf, subnet 10.31.10.0/26 | gateway 10.31.10.1 on lan0, after deploy | Attach Shell |
| leaf-2 | Leaf, subnet 10.31.10.64/26 (and 10.31.10.128/26 in intent v2) | gateways 10.31.10.65 and, after v2, 10.31.10.129 | Attach Shell |
| host-a | Host on leaf-1 | 10.31.10.10/26, gateway 10.31.10.1 | Attach Shell |
| host-b | Web server on leaf-2 | 10.31.10.74/26, gateway 10.31.10.65 | Attach Shell |
| host-c | Web server on leaf-2 lan1 | 10.31.10.138/26, gateway 10.31.10.129 (path exists after intent v2) | Attach Shell |

## Files

- `intent-leaf-spine.clab.yml` - the lab file (the cabling; the intent is separate).
- `intent-leaf-spine.drawio` and `intent-leaf-spine.png` - the prepared diagram.
- `configs/intent_v1.txt` and `configs/intent_v2.txt` - the two intent files (`key = value` lines).
- `scripts/fabric.py` - render, diff, deploy, validate.
- `scripts/fault.sh` - `1` puts the drift in place on leaf-1 (route via spine-1 only).
- `scripts/make-captures.sh` - records the sample captures again (it also deploys the intent as part of that).
- `captures/` - sample packet captures for the exercises.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `intent-leaf-spine` > right-click `intent-leaf-spine.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal** from the lab folder:
  ```
  docker exec clab-intent-leaf-spine-host-a ip -br addr show eth1
  ```
  It shows `10.31.10.10/26`. The spines and leaves have no lab addresses yet; that is expected until you deploy the intent.
- **Reset to the lesson start** (rendered files can stay; live routes on the switches are gone):
  ```
  cd ~/labs-main/containerlab/labs/intent-leaf-spine
  ```
  ```
  containerlab redeploy -c -t intent-leaf-spine.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/intent-leaf-spine`).

**1. Read the intent and render it.** The intent says what, not how:
```
cat configs/intent_v1.txt
```
```
python3 scripts/fabric.py render configs/intent_v1.txt build
```
```
cat build/leaf-1.conf
```
The intent lists two spines, one subnet on leaf-1, one on leaf-2, and the link-address pool. Render writes one file per switch under `build/`. `leaf-1.conf` has /31 addresses to spine-1 and spine-2, the gateway `10.31.10.1` on `lan0`, and one route to `10.31.10.64/26` with two next hops (one per spine). The lines use `replace`, so a deploy can be run again.

**2. Deploy and validate.** Push every rendered file, then compare live state with the intent, then load a page:
```
python3 scripts/fabric.py deploy build
```
```
sleep 2
```
```
python3 scripts/fabric.py validate configs/intent_v1.txt
```
```
docker exec clab-intent-leaf-spine-host-a curl -s -m 3 http://10.31.10.74/
```
Deploy prints `deployed` for each of the four switches. Validate prints 7 checks, 0 FAIL (all spine–leaf links up; each leaf reaches the other rack via both spines; each spine reaches each rack via the right leaf). The curl prints `hello from host-b (10.31.10.74)`. (Sample `ils-1-ecmp.pcapng`, recorded on leaf-1's two spine links: the page load.)

**3. Drift: a hand change leaves traffic working and validation failing.** Put the fault in place (leaf-1's route to the other rack now goes via spine-1 only):
```
bash scripts/fault.sh 1
```
```
docker exec clab-intent-leaf-spine-host-a curl -s -m 3 http://10.31.10.74/
```
```
python3 scripts/fabric.py validate configs/intent_v1.txt
```
The curl still works. Validate reports 1 FAIL: leaf-1's route is `via spine-1` and the intent wants `spine-1, spine-2`. The path still works, but leaf-1 has lost half of its paths and is one spine failure from an outage. Fix it by redeploying leaf-1's rendered file (not by typing the route back by hand):
```
python3 scripts/fabric.py deploy build leaf-1
```
```
python3 scripts/fabric.py validate configs/intent_v1.txt
```
Validate returns to 7 checks, 0 FAIL. (Sample `ils-2-drift.pcapng`: the page still loads after the hand change.)

**4. One intent line becomes four device changes.** Review the intent diff, render the new intent, review the config diff, then deploy:
```
diff -u configs/intent_v1.txt configs/intent_v2.txt
```
```
python3 scripts/fabric.py render configs/intent_v2.txt build2
```
```
python3 scripts/fabric.py diff build build2
```
The intent change is one line: leaf-2 also has `10.31.10.128/26` (host-c's subnet). The config diff has 4 changed lines (the new gateway on leaf-2 `lan1`, and a route on leaf-1, spine-1 and spine-2). Review the diff before you deploy: a wrong intent deploys everywhere.
```
python3 scripts/fabric.py deploy build2
```
```
sleep 2
```
```
python3 scripts/fabric.py validate configs/intent_v2.txt
```
```
docker exec clab-intent-leaf-spine-host-a curl -s -m 3 http://10.31.10.138/
```
Validate prints 10 checks, 0 FAIL. The curl prints `hello from host-c (10.31.10.138)`. (Sample `ils-3-new-subnet.pcapng`: host-a loads host-c's page after the new subnet is deployed.)

## Sample captures

Open them in Wireshark with File > Open. The display filter `tcp.port == 80` shows the page loads.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `ils-1-ecmp.pcapng` | leaf-1:to-spine-1 and to-spine-2 | 16 | exercise 2: host-a loads host-b's page across the fabric |
| `ils-2-drift.pcapng` | leaf-1:to-spine-1 and to-spine-2 | 12 | exercise 3: the same page still loads after the route is reduced to one next hop |
| `ils-3-new-subnet.pcapng` | leaf-1:to-spine-1 and to-spine-2 | 12 | exercise 4: host-a loads host-c's page after intent v2 |

Frame counts move by a few frames from run to run (IPv6 router solicitations, ARP timing, and which spine ECMP chooses).

## What this lab does not do

- Not a vendor fabric or intent product: the tool is our own script, and the README says so.
- Static ECMP routes stand in for BGP or OSPF. There is no overlay (no EVPN-VXLAN).
- Validation runs once per command, not continuously. Change approval and rollback are not run.
- Deploy uses `docker exec` and `ip -batch`, not an API or SSH.

## Troubleshooting

1. **The check in Start prints nothing.** host-a's interface may still be coming up: wait 5 seconds and try again, or reset the lab.
2. **Deploy fails, or validate says links are down.** Wait a few seconds after Deploy for the veths, then deploy again (`replace` is safe to run again).
3. **`diff: ...` from the system `diff` command in exercise 4.** That is expected: `diff -u` prints the one changed intent line and exits 1. The next commands still run; `fabric.py diff` is a different command and prints `4 changed lines`.
4. **`fault.sh` says `permission denied ... docker.sock`.** Your user cannot use Docker without sudo yet: log out and in again after the guide's Docker step, or run `sudo bash scripts/fault.sh 1`.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/intent-leaf-spine
```
```
containerlab destroy --cleanup -t intent-leaf-spine.clab.yml
```
`--cleanup` also removes the generated `clab-intent-leaf-spine` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-intent-leaf-spine` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/intent-leaf-spine/clab-intent-leaf-spine
```
Your capture files in your Home folder are not touched.
