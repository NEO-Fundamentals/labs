#!/bin/bash
# Run once after each Deploy, from the lab folder:  bash scripts/setup-keys.sh
# Makes two key pairs on host-a (id_lab and id_other) and lets only id_lab log in to host-b as labuser.
# The keys are made fresh inside the containers; nothing secret is saved in the lab folder.
N=clab-ssh-sessions
docker exec $N-host-a sh -c 'mkdir -p -m 700 /root/.ssh; for k in id_lab id_other; do [ -f /root/.ssh/$k ] || ssh-keygen -q -t ed25519 -N "" -C "$k@host-a" -f /root/.ssh/$k; done'
docker exec $N-host-a cat /root/.ssh/id_lab.pub | docker exec -i $N-host-b sh -c 'cat > /home/labuser/.ssh/authorized_keys; chown labuser:labuser /home/labuser/.ssh/authorized_keys; chmod 600 /home/labuser/.ssh/authorized_keys'
echo "host-a keys:"; docker exec $N-host-a ssh-keygen -lf /root/.ssh/id_lab.pub; docker exec $N-host-a ssh-keygen -lf /root/.ssh/id_other.pub
echo "authorized on host-b for labuser:"; docker exec $N-host-b ssh-keygen -lf /home/labuser/.ssh/authorized_keys
