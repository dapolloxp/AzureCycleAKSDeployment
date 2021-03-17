#!/bin/bash
set -x
set -e

CS_ROOT="/opt/cycle_server"

# If CycleCloud data dir was locally stashed, and mounted data dir is empty
# then this is the first load with a persistent volume, so copy stashed data into place
# (Move files within the ads/ directory rather than director itself to allow mounting at ads/)
if [ ! -f "${CS_ROOT}/data/ads/master.logfile" ]; then
   echo "Moving stashed cyclecloud data from container to mounted data disk on first start..."
   rm -rf ${CS_ROOT}/data/ads/*
   mkdir -p ${CS_ROOT}/data/ads
   mv /opt_cycle_server/data/ads/* ${CS_ROOT}/data/ads/
fi


# If no datastore exists, check if a backup exists and restore
# GOAL: allow mounting ${CS_ROOT}/data to either persistent or ephemeral disk
#       allow independently mounting ${CS_ROOT}/data/backups to a separate persistent volume if desired
# RATIONALE:
# Managed Disk is not currently Zone Redundant, so to achieve Zonal Failover, place backups on slower
#   zone-redundant remote storage such as Azure Files (alternatively find a remote storage option that is 
#   performant enough for the entire ${CS_ROOT}/data directory...)
NUM_BACKUPS=$(ls -d -1 ${CS_ROOT}/data/backups/backup-* 2>/dev/null | wc -l )
NEEDS_RESTORE="false"

# if [ -f ${CS_ROOT}/data/ads/master.logfile ]; then
#     echo "Restarting from valid CycleCloud logfile, no restore required."
#     NEEDS_RESTORE="false"
# elif [ -d ${CS_ROOT}/data/backups ] && [ ${NUM_BACKUPS} -gt 0 ]; then
#     echo "No CycleCloud logfile found.  But backups exist."
#     NEEDS_RESTORE="true"
# else
#     echo "No CycleCloud logfile or backups.  Starting fresh..."
#     NEEDS_RESTORE="false"
# fi

if [ -f "${CS_ROOT}/data/ads/initial_load.marker" ]; then
    echo "CycleCloud data directory still contains ${CS_ROOT}/data/ads/initial_load.marker"
    rm -f ${CS_ROOT}/data/ads/initial_load.marker

    # If this is the first load of the container, then restore if backups available
    if [ -d ${CS_ROOT}/data/backups ] && [ ${NUM_BACKUPS} -gt 0 ]; then
        echo "CycleCloud backups exist."
        NEEDS_RESTORE="true"
    fi
fi

if [ "${NEEDS_RESTORE}" == "true" ]; then
    echo "Will restore CycleCloud from latest backup..."
    echo "yes" | ${CS_ROOT}/util/restore.sh
fi

# Now run or re-run the install script to ensure all accounts are configured
# options : 
#     DRYRUN="--dryrun" for testing
#     NO_DEFAULT_ACCOUNT="--noDefaultAccount" to disable initial CycleCloud account creation
#     CYCLECLOUD_PASSWORD="" to use a randomized password
#     CYCLECLOUD_HOSTNAME="X.X.X.X" to use a specific hostname or IP for clusternode-to-cyclecloud connections
python3 /cs-install/scripts/cyclecloud_install.py --acceptTerms \
    --useManagedIdentity --username=${CYCLECLOUD_USERNAME} --password="${CYCLECLOUD_PASSWORD}" \
    --publickey="${CYCLECLOUD_USER_PUBKEY}" --storageAccount=${CYCLECLOUD_STORAGE} \
    --resourceGroup=${CYCLECLOUD_RESOURCE_GROUP} ${DRYRUN} ${NO_DEFAULT_ACCOUNT} \
    --webServerMaxHeapSize=4096M --webServerPort=8080 --webServerSslPort=8443 \
    --webServerClusterPort=9443 --webServerHostname="${CYCLECLOUD_HOSTNAME}"


#keep Container alive permanently
while true
do
  sleep 600
  ${CS_ROOT}/cycle_server status || exit
done

