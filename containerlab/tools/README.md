# NEO lab tools (for lab authors; viewers do not need these)

| File | What it does |
|---|---|
| `neo_diagram.py` | Makes a lab's prepared `.drawio` and `.png`: runs `clab2drawio`, applies `neo-role` shapes (firewall, load balancer, server, sensor), LAG ovals (`neo-lag`; one oval per bundle, also for a host bundle to two switches), subnet text (`neo-net`), capture badges (`neo-capture`) and a second label line (`neo-note`), then renders the PNG with draw.io desktop. Port chips show the full interface name from the lab file (for example `ethernet-1/1`) at 11 px. The layout step places every chip, node name, subnet text and badge so that none touches another box or a link, and prints a `layout:` warning if it cannot. Usage: `NEO_DRAWIO_BIN=/path/to/drawio neo_diagram.py <lab>/<lab>.clab.yml` (the PNG needs draw.io desktop, found through `NEO_DRAWIO_BIN` or `PATH`; `xvfb-run` is used when present) |
| `neo_lint.py` | Checks lab folders (or one `.clab.yml` file) against the Containerlab 0.83 JSON schema and the lab rules: folder, file and `name:` agree (a lighter `<lab>-lite.clab.yml` file keeps `name: <lab>`); every node has `graph-icon`; node kinds are `nokia_srlinux`, `frr` or `linux` (so SR Linux and FRR are the only network operating systems), at most 2 SR Linux nodes; mgmt IPv6 inside `fd00::/8`; every IPv4 address in the lab file, configs, scripts and README inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16 (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 and 198.18.0.0/15 are rejected by name); every IPv6 address in text inside `fd00::/8` (2001:db8::/32 and 3fff::/20 are rejected by name); every AS number in a BGP configuration statement (after `autonomous-system`, `remote-as`, `peer-as`, `router bgp`, `local-as` or `prepend`) 64512-65534 or 4200000000-4294967294 (AS numbers written in README prose are not checked); README present; the banned assistant name absent. Usage: `neo_lint.py <clab.schema.json> labs` (or a lab folder, or `file.clab.yml`). Get the schema for 0.83: `https://raw.githubusercontent.com/srl-labs/containerlab/v0.83.0/schemas/clab.schema.json`. Not checked: addresses inside binary files (captures, images). Needs `pyyaml` and `jsonschema` |
| `neo-tools/` | The common helper image: `1.0.0` (Debian 12 slim, about 257 MB, published) and `1.1.0` (about 298 MB, built locally, not pushed). Both have nftables, conntrack, dnsmasq, DHCP client, sshd, HAProxy, keepalived, strongSwan (swanctl), snmpd, iperf3, tcpdump, dig. 1.1.0 also has Suricata and conntrackd. `Dockerfile`, `neo-init.sh`, `smoke-test.sh`, `PACKAGES-1.0.0.txt`, `PACKAGES-1.1.0.txt` |
| `sample/` | `diagram-sample.clab.yml` and its `.drawio` / `.png`: every diagram element in one picture |

## Publishing the helper image (owner, one time)

```
cd tools/neo-tools
docker build -t ghcr.io/neo-fundamentals/neo-tools:1.0.0 .
./smoke-test.sh ghcr.io/neo-fundamentals/neo-tools:1.0.0

`smoke-test.sh` requires `suricata` and `conntrackd` only when the image tag is `1.1.0`. The default (and the publishing check above) stays `1.0.0`. For a local 1.1.0 build, run `./smoke-test.sh ghcr.io/neo-fundamentals/neo-tools:1.1.0`.
docker push ghcr.io/neo-fundamentals/neo-tools:1.0.0
```
The image holds no SSH host keys (the Dockerfile deletes the ones the package makes at build time, and `neo-init` makes new ones when each container starts), and `smoke-test.sh` checks both that and that two containers get different keys. The GitHub Actions workflow `publish-neo-tools.yml` does the same four steps with the built-in token and refuses to overwrite an existing `1.0.0`; to change the image, raise the version. Then set the package to public in GitHub (Packages > neo-tools > Package settings > Change visibility). Most labs that use it say `image: ghcr.io/neo-fundamentals/neo-tools:1.0.0`. Twenty-four labs in this kit use the image (`ssh-sessions`, `multivendor-ssh-management`, `dns-resolution`, `dhcp-dora-relay`, `private-public-nat`, `firewall-zones`, `firewall-policy-order`, `firewall-nat`, `firewall-troubleshooting`, `ngfw-inspection`, `vpn-ipsec-site-to-site`, `firewall-ha-vrrp`, `multivendor-firewall-zones`, `multivendor-firewall-policy`, `load-balancer-haproxy`, `load-balancer-troubleshooting`, `path-trace-routed`, `path-trace-access-port`, `troubleshooting-capstone`, `monitoring-snmp-polling`, `wire-data-sensor`, `config-map-runbook`, `cloud-managed-campus` and `intent-leaf-spine`), so `1.0.0` must be public before viewers deploy them.

**What 1.0.0 contains.** The Dockerfile does not pin the Debian base or the package versions, so a rebuild today would not give the same image. The published 1.0.0 is the reference: digest `sha256:ae019ed9d62677440e1410187a5d050a37dea142da1f0554710df5d2c0e78743` (Debian 12.15, built 2026-11-27), and `neo-tools/PACKAGES-1.0.0.txt` lists its 201 Debian packages and versions. Labs pull it by the `1.0.0` tag; the next image version should pin the base by digest.

**1.1.0 (local, not pushed).** The current `Dockerfile` builds `1.1.0`: the same Debian 12 slim base and the same 1.0.0 packages, plus `conntrackd` from bookworm and `suricata` from bookworm-backports (Suricata is not in bookworm main). `PACKAGES-1.1.0.txt` lists its 239 Debian packages. A local build on 2026-11-27 (America/Los_Angeles) is image id `sha256:d738553af6d56ab944dc8f093b4bcd2d74918469adef0740557191d0b618bdf9`, docker size 297858237 bytes (about 298 MB), Debian 12.15, created 2026-11-27 17:26:51 PT. It has no registry digest: **do not push it to GHCR yet.** Build it on the machine that will run the labs:

```
cd tools/neo-tools
docker build -t ghcr.io/neo-fundamentals/neo-tools:1.1.0 .
```

(The published `smoke-test.sh` still contains historical `docker rm` lines; a local smoke can start named containers and stop them instead.) Only two node roles need this tag: the `ids` node in `ngfw-inspection`, and `fw1` / `fw2` in `firewall-ha-vrrp`. Every other neo-tools node stays on `1.0.0`.

## Lab-file labels (all valid in the Containerlab schema)

Node: `graph-icon` (router, switch, host, network), `graph-level`, `graph-posX`, `graph-posY`, `neo-role`, `neo-note`. Link (use the long `type: veth` link form so labels are allowed): `neo-net`, `neo-capture`, `neo-lag`.

## Checking the checker

`neo_lint.py` must fail on documentation ranges and still pass the real labs. Copy a lab, put `192.0.2.10`, `198.51.100.1`, `203.0.113.20` in its lab file, `2001:db8::1` and `3fff::5` in its README and `router bgp 64511` or `remote-as 4294967295` in a config, and run `neo_lint.py`: it prints FAIL with one line per finding. Then run it on `labs`: every lab prints PASS. `tools/sample/diagram-sample.clab.yml` is schema-valid and lint-clean (`neo_lint.py <schema> tools/sample/diagram-sample.clab.yml`).
