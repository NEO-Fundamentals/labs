#!/bin/bash
# Run once after each Deploy, from the lab folder:  bash scripts/setup-keys.sh
# Makes the netops key pair on admin-host (id_netops) and an old key (id_old) that the device does not accept,
# then puts only id_netops.pub in netops's authorized_keys on device. Nothing secret is saved in the lab folder.
N=clab-multivendor-ssh-management
docker exec $N-admin-host sh -c 'mkdir -p -m 700 /root/.ssh; for k in id_netops id_old; do [ -f /root/.ssh/$k ] || ssh-keygen -q -t ed25519 -N "" -C "$k@admin-host" -f /root/.ssh/$k; done'
docker exec $N-admin-host cat /root/.ssh/id_netops.pub | docker exec -i $N-device sh -c 'cat > /home/netops/.ssh/authorized_keys; chown netops:netops /home/netops/.ssh/authorized_keys; chmod 600 /home/netops/.ssh/authorized_keys'
echo "keys on admin-host:"; docker exec $N-admin-host ssh-keygen -lf /root/.ssh/id_netops.pub; docker exec $N-admin-host ssh-keygen -lf /root/.ssh/id_old.pub
echo "authorized on device for netops:"; docker exec $N-device ssh-keygen -lf /home/netops/.ssh/authorized_keys
