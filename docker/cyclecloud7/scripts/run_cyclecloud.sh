#!/bin/bash
set -x
set -e

# If CycleCloud install was locally cached, move it into place now...
# Useful in locked-down environments where yum is blocked
if [ ! -d "/opt/cycle_server" ] && [ -d "/opt_cycle_server" ]; then
   echo "Moving cyclecloud install from container to persistent disk on first start..."
   mv /opt_cycle_server /opt/cycle_server
else
   rm -rf /opt_cycle_server
fi
python /cs-install/scripts/cyclecloud_install.py --acceptTerms \
    --useManagedIdentity --username=${CYCLECLOUD_USERNAME} --password="${CYCLECLOUD_PASSWORD}" --publickey="${CYCLECLOUD_USER_PUBKEY}" --storageAccount=${CYCLECLOUD_STORAGE} --resourceGroup=${CYCLECLOUD_RESOURCE_GROUP} ${DRYRUN}


#keep Container alive permanently
while true
do
  sleep 600
  ${CS_ROOT}/cycle_server status || exit
done

