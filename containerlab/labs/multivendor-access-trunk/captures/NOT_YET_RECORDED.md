# No sample captures yet

The build machine cannot run the Linux-bridge half of this lab: its kernel has no bridge VLAN filtering, so sw2's `br0` with VLANs cannot be created there. The samples are recorded on the first run on the NEO lab VM with `sudo bash scripts/make-captures.sh`, which writes them into this folder (`mvat-1-trunk-tags`, `mvat-2-vlan20-not-allowed`, `mvat-3-access-vs-trunk`). See the status note at the top of the lab README.
