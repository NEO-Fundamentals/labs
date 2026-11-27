# NEO lab tools (for lab authors; viewers do not need these)

| File | What it does |
|---|---|
| `neo_diagram.py` | Makes a lab's prepared `.drawio` and `.png`: runs `clab2drawio`, applies `neo-role` shapes (firewall, load balancer, server, sensor), LAG ovals (`neo-lag`), subnet text (`neo-net`), capture badges (`neo-capture`) and a second label line (`neo-note`), then renders the PNG with draw.io desktop. Port chips show the full interface name from the lab file (for example `ethernet-1/1`) at 11 px. The layout step places every chip, node name, subnet text and badge so that none touches another box or a link, and prints a `layout:` warning if it cannot. Usage: `NEO_DRAWIO_BIN=/path/to/drawio neo_diagram.py <lab>/<lab>.clab.yml` (the PNG needs draw.io desktop, found through `NEO_DRAWIO_BIN` or `PATH`; `xvfb-run` is used when present) |
| `neo_lint.py` | Checks lab folders (or one `.clab.yml` file) against the Containerlab 0.83 JSON schema and the lab rules: folder, file and `name:` agree; every node has `graph-icon`; node kinds are `nokia_srlinux`, `frr` or `linux` (so SR Linux and FRR are the only network operating systems), at most 2 SR Linux nodes; mgmt IPv6 inside `fd00::/8`; every IPv4 address in the lab file, configs, scripts and README inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16 (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 and 198.18.0.0/15 are rejected by name); every IPv6 address in text inside `fd00::/8` (2001:db8::/32 and 3fff::/20 are rejected by name); every AS number 64512-65534 or 4200000000-4294967294; README present; the banned assistant name absent. Usage: `neo_lint.py <clab.schema.json> labs` (or a lab folder, or `file.clab.yml`). Get the schema for 0.83: `https://raw.githubusercontent.com/srl-labs/containerlab/v0.83.0/schemas/clab.schema.json`. Not checked: addresses inside binary files (captures, images). Needs `pyyaml` and `jsonschema` |
| `neo-tools/` | The common helper image (Debian 12 slim, about 257 MB): nftables, conntrack, dnsmasq, DHCP client, sshd, HAProxy, keepalived, strongSwan (swanctl), snmpd, iperf3, tcpdump, dig. `Dockerfile`, `neo-init.sh`, `smoke-test.sh` |
| `sample/` | `diagram-sample.clab.yml` and its `.drawio` / `.png`: every diagram element in one picture |

## Publishing the helper image (owner, one time)

```
cd tools/neo-tools
docker build -t ghcr.io/neo-fundamentals/neo-tools:1.0.0 .
./smoke-test.sh ghcr.io/neo-fundamentals/neo-tools:1.0.0
docker push ghcr.io/neo-fundamentals/neo-tools:1.0.0
```
Then set the package to public in GitHub (Packages > neo-tools > Package settings > Change visibility). Labs that use it say `image: ghcr.io/neo-fundamentals/neo-tools:1.0.0`. None of the labs in this kit need it yet.

## Lab-file labels (all valid in the Containerlab schema)

Node: `graph-icon` (router, switch, host, network), `graph-level`, `graph-posX`, `graph-posY`, `neo-role`, `neo-note`. Link (use the long `type: veth` link form so labels are allowed): `neo-net`, `neo-capture`, `neo-lag`.

## Checking the checker

`neo_lint.py` must fail on documentation ranges and still pass the real labs. Copy a lab, put `192.0.2.10`, `198.51.100.1`, `203.0.113.20` in its lab file, `2001:db8::1` and `3fff::5` in its README and `router bgp 64511` or `remote-as 4294967295` in a config, and run `neo_lint.py`: it prints FAIL with one line per finding. Then run it on `labs`: every lab prints PASS. `tools/sample/diagram-sample.clab.yml` is schema-valid and lint-clean (`neo_lint.py <schema> tools/sample/diagram-sample.clab.yml`).
