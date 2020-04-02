#!/bin/bash
set -x
set -e

python /cs-install/scripts/cyclecloud_install.py --acceptTerms \
    --useManagedIdentity --username=${CYCLECLOUD_USERNAME} --password="${CYCLECLOUD_PASSWORD}" --publickey="${CYCLECLOUD_USER_PUBKEY}" --storageAccount=${CYCLECLOUD_STORAGE} ${DRYRUN}


#keep Container alive permanently
while true
do
  sleep 600
  ${CS_ROOT}/cycle_server status || exit
done

