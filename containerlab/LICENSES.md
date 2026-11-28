# Licences for this kit

This `containerlab/` folder holds two kinds of material under two licences.

| What | Licence | Where |
|---|---|---|
| Code: the NEO helper image `neo-tools` (its `Dockerfile`, scripts and smoke test), every script and tool (`tools/`, each lab's `scripts/`), and the machine-readable lab files (each `*.clab.yml`, `configs/`, `changes/`, and the Wireshark profile files) | **MIT** | [LICENSE-MIT](LICENSE-MIT) in this folder |
| Text and pictures: the beginner guide, the lessons, every `README.md`, `LABS.md`, this file, the diagrams (`*.drawio`, `*.png`) and the sample captures (`captures/*.pcapng`) | **CC BY 4.0** (Creative Commons Attribution 4.0 International) | the repository's `LICENSE` file, and https://creativecommons.org/licenses/by/4.0/ |

The published image `ghcr.io/neo-fundamentals/neo-tools:1.0.0` carries the label `org.opencontainers.image.licenses="MIT"`, which matches the table above. A later local image, `ghcr.io/neo-fundamentals/neo-tools:1.1.0`, is built from `tools/neo-tools` and is not on the public registry yet. It is the same as 1.0.0 plus Suricata and conntrackd.

The images that the labs download (Nokia SR Linux, FRR, network-multitool, ISC BIND 9, and the Debian packages inside `neo-tools`) are not part of this kit. Each comes under its own owner's licence and terms, which you accept when you pull or build the image.

Debian packages inside `neo-tools` that this kit mentions by name include HAProxy (GPL-2.0-or-later), Net-SNMP (BSD-style), Suricata (GPL-2; in 1.1.0, from Debian bookworm-backports, with libhtp2 under BSD-3-clause) and conntrackd (GPL-2+; in 1.1.0, from bookworm). Those programs are not part of the MIT grant.
