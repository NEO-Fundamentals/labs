# Lab: An IPsec tunnel between two sites

**Folder:** `labs/vpn-ipsec-site-to-site/`  **Lab file:** `vpn-ipsec-site-to-site.clab.yml`  **Lesson:** NEO-17 VPNs: IPsec site-to-site and remote access  **Lab version:** 1.0.0 (2026-11-27)

**What runs and what does not:** the two gateways `gw-a` and `gw-b` are Linux containers running **strongSwan** (the IKE daemon, driven with `swanctl`) in the NEO helper image `neo-tools`; the Linux kernel encrypts the traffic (ESP, AES-GCM). The IKE exchange, the security associations, the ESP packets and the proposal mismatch are real. They are Linux VPN gateways, **not a commercial firewall or VPN product**: vendor VPN wizards and monitors are not here (the lesson shows them as text). **Remote-access VPN** (a laptop dialling in) and **WireGuard** are explained in the lesson only; this lab builds one site-to-site tunnel.

## Before you start

- **Where this runs:** the NEO lab virtual machine from the guide (Ubuntu 24.04, 8 GB of memory, 4 CPUs) with Docker, Containerlab, VS Code (with the Containerlab and Draw.io extensions) and Wireshark. Check in Ubuntu's Terminal: `containerlab version` and `docker --version` each print a version number.
- **Memory:** small: four Linux containers and one FRR router, about 100 MB together (measured). No SR Linux in this lab.
- **One lab at a time:** `containerlab inspect --all` should say no containers found. If another lab is running, clean it up first (see **Cleanup** in that lab's README).
- **The lab folder:** `~/labs-main/containerlab/labs/vpn-ipsec-site-to-site/` (see the kit README, "Getting the latest labs").
- **Internet and disk:** the first Deploy downloads the NEO helper image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` and the FRR image, unless an earlier lab already did. After that the lab works offline.
- **Time:** Deploy takes a few seconds. The lab is ready when the check in **Start** passes.

## What this lab builds

```
  site A                                   "Internet"                                    site B
  host-a ---- gw-a ======== IPsec tunnel (ESP) through wan ======== gw-b ---- host-b
  10.17.1.10  10.17.1.1 | 10.17.100.1 -- 10.17.100.2 wan 10.17.200.2 -- 10.17.200.1 | 10.17.2.1  10.17.2.20
              strongSwan                FRR: knows only 10.17.100.0/24              strongSwan  web :80
                                        and 10.17.200.0/24, no site LANs
```

| Node | What it is | Image (free, public) | How you log in |
|---|---|---|---|
| gw-a | site A gateway: Linux router with strongSwan. **eth1 = site A LAN** (10.17.1.1/24), **eth2 = outside** (10.17.100.1/24, default route via wan). Its tunnel settings: `configs/gw-a-swanctl.conf` | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Right-click > **Access** > **Attach Shell** |
| gw-b | site B gateway, the mirror image: eth1 = site B LAN 10.17.2.1/24, eth2 = outside 10.17.200.1/24. `configs/gw-b-swanctl.conf` | same | Attach Shell |
| wan | FRR router that plays the Internet: only its two connected networks, **no route to either site LAN** | `quay.io/frrouting/frr:containerlab-10.7.1` | Attach Shell, then `vtysh` |
| host-a | site A client 10.17.1.10/24, gateway gw-a | `ghcr.io/neo-fundamentals/neo-tools:1.0.0` | Attach Shell |
| host-b | site B server 10.17.2.20/24, gateway gw-b, web page on port 80 | same | Attach Shell |

All addresses are private (RFC 1918); the lab never touches the real Internet. Management IPv6 addresses use the private ULA prefix fd00:172:20:20::/64.

**The tunnel** (both gateways, mirror images; **nothing is loaded at deploy**):

| Setting | Value | Meaning |
|---|---|---|
| IKE version, peers | IKEv2, 10.17.100.1 and 10.17.200.1 | who talks to whom across the Internet |
| Authentication | pre-shared key, IDs `gw-a` and `gw-b` | a lab-only key; real tunnels use a long random key or certificates |
| IKE proposal | `aes256-sha256-modp2048` | protects the IKE conversation itself |
| Child SA `lan-to-lan` | 10.17.1.0/24 to 10.17.2.0/24 | the traffic selectors: which traffic goes into the tunnel |
| ESP proposal | `aes256gcm16-modp2048` | encrypts the site traffic (AES-256-GCM) |
| Start | `start_action = trap` | the first packet for the other site brings the tunnel up |

## Files

- `vpn-ipsec-site-to-site.clab.yml` - the lab drawing. Addresses and routes are set by each node's `exec` lines; each gateway starts the IKE daemon at deploy.
- `configs/gw-a-swanctl.conf`, `configs/gw-b-swanctl.conf` - the tunnel settings (above), mounted as `/etc/swanctl/swanctl.conf`. `configs/strongswan.conf` - the daemon's plugin list and its log file `/var/log/charon.log`. `configs/wan-frr.conf` - wan's two interfaces.
- `changes/gw-b-esp-aes128.conf` - exercise 4: gw-b with a different ESP proposal.
- `scripts/make-captures.sh` - re-records the sample captures. Run it with `sudo bash scripts/make-captures.sh` from the lab folder once the lab is up; it takes about a minute, loads the tunnel on both gateways and leaves it up, and overwrites the samples in `captures/` only when a new recording succeeds (a failed one prints FAIL and the old sample stays).
- `vpn-ipsec-site-to-site.drawio` and `vpn-ipsec-site-to-site.png` - the prepared diagram.
- `captures/` - three sample captures: `vpn-1-ike-esp.pcapng`, `vpn-2-site-b-clear.pcapng`, `vpn-3-proposal-mismatch.pcapng`.

## Start, reset, stop

- **Start:** Containerlab panel > **Undeployed Local Labs** > `labs` > `vpn-ipsec-site-to-site` > right-click `vpn-ipsec-site-to-site.clab.yml` > **Deploy**. Wait for the green dots, then check in VS Code's **Terminal > New Terminal**:
  ```
  docker exec clab-vpn-ipsec-site-to-site-gw-a ping -c 2 -W 1 10.17.200.1
  ```
  `2 received`: gw-a reaches gw-b's outside address across wan.
- **Reset to the lesson start** (no tunnel loaded, gw-b's own settings):
  ```
  cd ~/labs-main/containerlab/labs/vpn-ipsec-site-to-site
  ```
  ```
  containerlab redeploy -c -t vpn-ipsec-site-to-site.clab.yml
  ```
- **Stop:** right-click the running lab > **Destroy**. For a clean stop see **Cleanup** below.

## The commands

| Question | Where | Command |
|---|---|---|
| Which tunnels are configured? | gw-a, gw-b | `swanctl --list-conns` |
| Which tunnels are up (IKE SA and child SA), with packet counts? | gw-a, gw-b | `swanctl --list-sas` |
| Load or reload the settings | gw-a, gw-b | `swanctl --load-all` |
| Bring the tunnel up now, or take it down | gw-a | `swanctl --initiate --child lan-to-lan`, `swanctl --terminate --ike site-to-site` |
| What the kernel will encrypt (policies) and the keys it uses (states) | gw-a, gw-b | `ip xfrm policy`, `ip -s xfrm state` |
| What the daemon did, and why it failed | gw-a, gw-b | `tail -n 30 /var/log/charon.log` |
| Does wan know the site LANs? | wan | `vtysh -c 'show ip route'` |

## Exercises

Run these lines in VS Code's terminal (**Terminal > New Terminal**) from the lab folder (`cd ~/labs-main/containerlab/labs/vpn-ipsec-site-to-site`). You can also right-click a node > **Access** > **Attach Shell** and type the part after the container name.

**1. Without a tunnel the sites cannot talk.**
```
docker exec clab-vpn-ipsec-site-to-site-host-a ping -c 3 -W 1 10.17.2.20
```
```
docker exec clab-vpn-ipsec-site-to-site-host-a traceroute -n -w 1 -q 1 -m 4 10.17.2.20
```
```
docker exec clab-vpn-ipsec-site-to-site-wan vtysh -c 'show ip route'
```
`3 packets transmitted, 0 received`. The traceroute answers at hop 1 (`10.17.1.1`, gw-a) and then only `*`. wan's table has `10.17.100.0/24` and `10.17.200.0/24` and **no 10.17.1.0/24 or 10.17.2.0/24**: gw-a sends the packet to wan (its default route), and wan has nowhere to send a private site address, exactly like the Internet.

**2. Load the tunnel and let traffic bring it up.**
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --load-all
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-b swanctl --load-all
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --list-sas
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a ip xfrm policy
```
Each gateway prints `loaded ike secret 'ike-site-to-site'` and `loaded connection 'site-to-site'`. `--list-sas` prints nothing: the tunnel is configured but not up. The kernel already has the policy `src 10.17.1.0/24 dst 10.17.2.0/24 dir out ... tmpl src 10.17.100.1 dst 10.17.200.1 proto esp ... mode tunnel`: traffic for site B must be wrapped in ESP. Now send traffic:
```
docker exec clab-vpn-ipsec-site-to-site-host-a ping -c 4 -W 1 10.17.2.20
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --list-sas
```
`4 packets transmitted, 3 received`: the **first** ping started the tunnel and was lost while IKE ran; the rest got through. `--list-sas` now shows `site-to-site: #1, ESTABLISHED, IKEv2` with `AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048` (the IKE SA) and `lan-to-lan: #2, reqid 1, INSTALLED, TUNNEL, ESP:AES_GCM_16-256` with `in` and `out` SPIs and packet counts (the child SA), `local 10.17.1.0/24`, `remote 10.17.2.0/24`.

**3. What the Internet sees, and what the site sees.** Watch gw-a's outside port in a second terminal (it stops by itself after 20 seconds):
```
docker exec clab-vpn-ipsec-site-to-site-gw-a timeout 20 tcpdump -lnni eth2
```
In the first terminal:
```
docker exec clab-vpn-ipsec-site-to-site-host-a curl -s -m 3 http://10.17.2.20/
```
```
docker exec clab-vpn-ipsec-site-to-site-host-a traceroute -n -w 1 -q 1 -m 4 10.17.2.20
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a ip -s xfrm state
```
The page arrives (`hello from host-b ...`). On the outside link the capture shows only `IP 10.17.100.1 > 10.17.200.1: ESP(spi=0x...,seq=0x...)` and back: the gateways' addresses, an SPI and a sequence number; **no host addresses, no port 80, no HTTP**. The traceroute now shows three hops, `10.17.1.1`, `10.17.2.1`, `10.17.2.20`: wan is invisible because the packets cross it inside ESP. `ip -s xfrm state` shows two states (one per direction) with `aead rfc4106(gcm(aes))` and growing `lifetime current` byte and packet counts. (Samples, recorded at the same time: `vpn-1-ike-esp.pcapng` on wan's side, `vpn-2-site-b-clear.pcapng` on site B's LAN, where the same pings and the web request are in clear text.)

**4. Break it: a proposal mismatch.** Give gw-b a different ESP proposal (AES-128-GCM only), take the tunnel down and bring it up by hand:
```
docker exec clab-vpn-ipsec-site-to-site-gw-b swanctl --load-conns --file /neo/changes/gw-b-esp-aes128.conf
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --terminate --ike site-to-site
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --initiate --child lan-to-lan
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-b grep -E 'received proposals|configured proposals|no acceptable' /var/log/charon.log
```
gw-a's output includes `parsed IKE_AUTH response 1 [ IDr AUTH N(NO_PROP) ]`, `received NO_PROPOSAL_CHOSEN notify, no CHILD_SA built` and `failed to establish CHILD_SA, keeping IKE_SA`, and swanctl reports `initiate failed: establishing CHILD_SA 'lan-to-lan' failed` (it may print that line first). The IKE SA came up (the IKE proposals still match) but the child SA did not, so no site traffic can pass. gw-b's log says why: `received proposals: ESP:AES_GCM_16_256/...`, `configured proposals: ESP:AES_GCM_16_128/...`, `no acceptable proposal found`. In a capture this is four IKE packets and **no ESP**, and the reason is inside the encrypted part of IKE_AUTH, so only the logs show it (sample `vpn-3-proposal-mismatch.pcapng`). **Fix it** by loading gw-b's own settings again:
```
docker exec clab-vpn-ipsec-site-to-site-gw-b swanctl --load-conns
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --terminate --ike site-to-site
```
```
docker exec clab-vpn-ipsec-site-to-site-gw-a swanctl --initiate --child lan-to-lan
```
```
docker exec clab-vpn-ipsec-site-to-site-host-a ping -c 3 -W 1 10.17.2.20
```
`CHILD_SA lan-to-lan{...} established ... TS 10.17.1.0/24 === 10.17.2.0/24`, `initiate completed successfully`, and `3 received`. Both ends of a tunnel must agree on every proposal and on the traffic selectors.

Reset the lab (see **Start, reset, stop**) to go back to the lesson start.

## Sample captures

Open them in Wireshark with File > Open.

| File | Recorded on | Frames | What it shows |
|---|---|---|---|
| `vpn-1-ike-esp.pcapng` | wan:eth1 (the "Internet", gw-a's side) | 25 | an ARP exchange; `IKE_SA_INIT` and `IKE_AUTH` (request and response each, UDP 500); then only ESP between 10.17.100.1 and 10.17.200.1: three pings and one web request, encrypted |
| `vpn-2-site-b-clear.pcapng` | gw-b:eth1 (site B LAN) | 19 | recorded at the same time: the same three pings and the web request (handshake, `GET /`, `200 OK`, close) in clear text between 10.17.1.10 and 10.17.2.20 |
| `vpn-3-proposal-mismatch.pcapng` | wan:eth1 | 4 | `IKE_SA_INIT` and `IKE_AUTH`, and nothing after: gw-b's IKE_AUTH response carries NO_PROPOSAL_CHOSEN inside its encrypted part |

Wireshark cannot decrypt the ESP packets (the keys are only in the gateways). Run right after a deploy, `make-captures.sh` may also record IPv6 start-up traffic and other ARP exchanges.

## What this lab does not do

- No commercial firewall or VPN product: no VPN wizard, tunnel monitor or vendor proposal names; the lesson shows them as text.
- One site-to-site tunnel with a pre-shared key. No certificates, no NAT between the gateways (so no NAT traversal on UDP 4500), no routing protocol over the tunnel, no redundant tunnels.
- No remote-access VPN and no WireGuard: the lesson explains both.
- No firewall rules on the gateways: everything the tunnel carries is allowed.
- A veth pair carries each link; there is no real cable.

## Troubleshooting

1. **`swanctl` says `connecting to 'unix:///var/run/charon.vici' failed`.** The daemon is not running yet; wait a few seconds after the deploy, or reset the lab.
2. **Exercise 2: every ping is lost.** Load the settings on **both** gateways; the first ping after loading is always lost while the tunnel starts.
3. **Exercise 3: the capture shows ICMP or TCP between 10.17.1.10 and 10.17.2.20.** You are capturing on a LAN port (eth1); use gw-a's **eth2**.
4. **After the fix in exercise 4, pings are still lost.** Run the `--terminate` and `--initiate` lines again; a failed attempt can block the tunnel from starting by itself for about 30 seconds.
5. **`/var/log/charon.log` is empty.** Nothing has happened yet; it fills when a tunnel is loaded or started.

## Cleanup

Do this when you finish the lab, and before you start a different one. In the lab folder:
```
cd ~/labs-main/containerlab/labs/vpn-ipsec-site-to-site
```
```
containerlab destroy --cleanup -t vpn-ipsec-site-to-site.clab.yml
```
`--cleanup` also removes the generated `clab-vpn-ipsec-site-to-site` folder next to the lab file (the menu's **Destroy (Cleanup)** does the same). Check that nothing is left:
```
containerlab inspect --all
```
It reports that no containers were found. If the `clab-vpn-ipsec-site-to-site` folder is still there afterwards (it is owned by root, so VS Code cannot delete it), you can remove that one generated folder yourself. It holds only this lab's generated files, not your lab files:
```
sudo rm -rf ~/labs-main/containerlab/labs/vpn-ipsec-site-to-site/clab-vpn-ipsec-site-to-site
```
Your capture files in your Home folder are not touched.

