# Lab: subnets, masks and the default gateway

**Folder:** `labs/subnetting-gateway/`  **Lab file:** `subnetting-gateway.clab.yml`  **Lesson:** NEO-05 IPv4 subnetting and CIDR  **Lab version:** 1.0.0 (2026-11-26)


## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/subnetting-gateway/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads `quay.io/frrouting/frr:containerlab-10.7.1` (about 200 MB) and `ghcr.io/srl-labs/network-multitool` (about 860 MB). After that the lab works offline. Keep at least 2 GB of disk free (`df -h ~`).
- **Time:** The first Deploy takes 2 to 5 minutes (downloads); later Deploys take under a minute, plus about 10 seconds for r1.

## What this lab builds

```
 host-a  10.0.2.130/26 ---+
 host-b  10.0.2.190/26 ---+--- sw1 (Linux bridge) ---+--- r1 (FRR)  10.0.2.129/26 and 10.0.2.65/26
 host-c  10.0.2.66/26  ---+
```

The lesson's practice question: host `10.0.2.130/26`; is `10.0.2.190` in its subnet; could `10.0.2.65` be its gateway? The lab lets you check each answer on real hosts.

| Subnet | Block | Hosts |
|---|---|---|
| `10.0.2.128/26` | network .128, broadcast .191, usable .129-.190 | host-a (.130), host-b (.190, web server on port 8080), r1 (.129, the gateway) |
| `10.0.2.64/26` | network .64, broadcast .127, usable .65-.126 | host-c (.66), r1 (.65, the gateway) |

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| host-a, host-b, host-c | Linux hosts | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| sw1 | A Linux bridge used as a switch | `ghcr.io/srl-labs/network-multitool` | Right-click > **Access** > **Attach Shell** |
| r1 | FRR router, one address in each subnet | `quay.io/frrouting/frr:containerlab-10.7.1` | Right-click > **Access** > **Attach Shell** (opens `vtysh`) |

All IPv4 addresses are private (RFC 1918). Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**One honest shortcut:** both /26 subnets share one switch and one cable to r1, so you can see that the mask, not the wire, decides who counts as "local". Real networks usually give each subnet its own switch segment or VLAN. r1 has ICMP redirects turned off so the hosts keep using the gateway.

## Files

- `subnetting-gateway.clab.yml` - the lab drawing.
- `configs/r1-frr.conf` - r1's two addresses.
- `scripts/subnets.py` - a subnet calculator (network, broadcast, usable range, "is this address in the same subnet?").
- `scripts/make-captures.sh` - re-records the sample capture (the lab must be running).
- `subnetting-gateway.drawio` and `subnetting-gateway.png` - the prepared diagram.
- `captures/subnet-same-and-other.pcapng` - sample capture from host-a's cable.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `subnetting-gateway` > right-click `subnetting-gateway.clab.yml` > **Deploy**. Wait for the five green dots, then about 10 more seconds for r1 to load its addresses. Run one lab at a time.
- **Reset to the lesson start:** in VS Code, **Terminal > New Terminal**:
  ```
  cd ~/labs-main/containerlab/labs/subnetting-gateway
  ```
  ```
  containerlab redeploy -c -t subnetting-gateway.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## Check it works

```
docker exec clab-subnetting-gateway-host-a ping -c 2 10.0.2.190
```
```
docker exec clab-subnetting-gateway-host-a ping -c 2 10.0.2.66
```
Both answer. The first stays inside the /26; the second goes through r1.

## Exercises

Predict the answer first, then run the command.

**1. Do the address maths.** In the lab folder:
```
python3 scripts/subnets.py 10.0.2.130/26 10.0.2.190 10.0.2.65
```
It prints network `.128`, broadcast `.191`, usable `.129-.190`, and says `.190` is IN the subnet and `.65` is NOT. A /26 has 6 host bits, so blocks of 64 start at .0, .64, .128 and .192.

**2. Same subnet: sent directly.** On host-a, ask which way a packet to host-b goes:
```
docker exec clab-subnetting-gateway-host-a ip route get 10.0.2.190
```
There is no `via`: host-a delivers directly, so it asks ARP for host-b itself. See it:
```
docker exec clab-subnetting-gateway-host-a ip neigh
```

**3. Other subnet: sent to the gateway.**
```
docker exec clab-subnetting-gateway-host-a ip route get 10.0.2.66
```
This one says `via 10.0.2.129`. host-a ARPs for the router (.129), not for host-c, and sends the packet to the router's MAC address. Check: `docker exec clab-subnetting-gateway-host-a ip neigh` lists .129 but not .66.

**4. Capture it.** In Ubuntu's Terminal app start the capture first, then in another window run the pings:
```
sudo containerlab capture --name subnetting-gateway --target host-a:eth1 --duration 12s -w - > "$HOME/neo-subnets.pcapng"
```
```
docker exec clab-subnetting-gateway-host-a ip neigh flush all
```
```
docker exec clab-subnetting-gateway-host-a ping -c 2 10.0.2.190
```
```
docker exec clab-subnetting-gateway-host-a ping -c 2 10.0.2.66
```
In Wireshark (filter `arp || icmp`): an ARP request for 10.0.2.190 (the destination itself), then another for 10.0.2.129 (the gateway). For the ping to host-c, the IP destination is 10.0.2.66 but the Ethernet destination is r1's address. The sample file `captures/subnet-same-and-other.pcapng` shows this.

**5. A gateway must be in your own subnet.** `10.0.2.65` is in the other block, so host-a cannot use it:
```
docker exec clab-subnetting-gateway-host-a ip route replace default via 10.0.2.65
```
Linux refuses: `Error: Nexthop has invalid gateway.` Put the right one back: `docker exec clab-subnetting-gateway-host-a ip route replace default via 10.0.2.129`.

**6. Change a mask and watch who counts as local.** On host-c, widen the mask from /26 to /24:
```
docker exec clab-subnetting-gateway-host-c sh -c "ip addr del 10.0.2.66/26 dev eth1; ip addr add 10.0.2.66/24 dev eth1"
```
Now `ip route get 10.0.2.130` on host-c shows no `via`: host-c believes host-a is on its own subnet and would ARP for it directly. Ping host-a from host-c (`docker exec clab-subnetting-gateway-host-c ping -c 2 10.0.2.130`). It still works here, because both subnets share one switch: host-c now ARPs for host-a directly instead of using the gateway. In a network with one subnet per segment this ping would fail. Capture on host-a and compare the Ethernet addresses of the request and the reply. Undo with `containerlab redeploy -c -t subnetting-gateway.clab.yml`.

**7. Web server on host-b.** From both hosts:
```
docker exec clab-subnetting-gateway-host-a curl -s -o /dev/null -w "%{http_code}\n" http://10.0.2.190:8080/
```
```
docker exec clab-subnetting-gateway-host-c curl -s -o /dev/null -w "%{http_code}\n" http://10.0.2.190:8080/
```
Both print `200`; host-a reaches it directly and host-c through its gateway (.65).

## Troubleshooting

1. **The first ping to the gateway or to host-c fails right after Deploy.** r1 (FRR) loads its addresses about 10 seconds after the green dots. Wait, then ping again.
2. **A ping inside the /26 works but a ping to the other subnet fails.** Traffic to the other subnet needs a default gateway on the host (.129 for host-a and host-b, .65 for host-c). Check `docker exec clab-subnetting-gateway-host-a ip route`; if the default route is missing or wrong, reset with `containerlab redeploy -c -t subnetting-gateway.clab.yml`.
3. **You removed or changed a host's gateway (an exercise) and cannot get it back.** Reset with `containerlab redeploy -c -t subnetting-gateway.clab.yml`; every host gets its original address and gateway again.
4. **`python3 scripts/subnets.py` says `No such file`.** Run it from the lab folder: `cd ~/labs-main/containerlab/labs/subnetting-gateway`, then `python3 scripts/subnets.py 10.0.2.130/26`. It runs on the VM, not in a container.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/subnetting-gateway
```
```
containerlab destroy --cleanup -t subnetting-gateway.clab.yml
```
`--cleanup` also removes the generated `clab-subnetting-gateway` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-subnetting-gateway` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's saved configs, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/subnetting-gateway/clab-subnetting-gateway
```
Your capture files in your Home folder are not touched.

## What this lab does not do

- Both subnets share one switch (see above), and the /30 and /31 router-link examples in the lesson are explained with `scripts/subnets.py`, not built as links.
