# Address and name check — 01_build-your-own-neo-lab

Checked every text file in this kit, including the files inside `wireshark/NEO_Diagnostics_profile.zip` (PNG diagrams were checked by eye). Allowed IPv4 is RFC 1918 private, loopback, multicast and unspecified. Documentation ranges and public unicast addresses are not allowed. Personal names, internal names, build-machine names, SSH keys and fingerprints are not allowed.

No capture files ship in this kit: the check lab makes your own capture when you run `scripts/verify-lab.sh`.

Overall result: **PASS**.

- Files checked: 11
- IPv4 addresses found: ['10.0.2.0', '10.0.2.1', '10.0.2.10', '172.16.100.0', '172.16.100.1', '172.16.100.20']
- Findings: none
