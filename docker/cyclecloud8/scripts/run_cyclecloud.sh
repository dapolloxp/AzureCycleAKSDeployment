#!/bin/bash
set -x
set -e

CS_ROOT="/opt/cycle_server"


# If CycleCloud data dir is empty (new persistent volume mount) or corrupt
# then copy stashed data dir into place
# (Move files within the ads/ directory rather than director itself to allow mounting at ads/)
if [ ! -f "${CS_ROOT}/data/ads/master.logfile" ]; then
   echo "Moving stashed cyclecloud data from container to mounted data disk on first start..."
   pushd ${CS_ROOT}/data
   rm -rf ./ads
   mkdir -p ./ads
   mv /opt_cycle_server/data/ads/* ./ads/
   popd
fi

# Copy locally stashed CycleCloud work dir to mounted work dir (need to retain
# previously deployed jetpack and project versions but ensure the current version is staged)
pushd ${CS_ROOT}
cp -a /opt_cycle_server/work/* ./work/ 
popd


if [ -f "$CS_ROOT/logs/catalina.err" ]; then

    mv $CS_ROOT/logs/catalina.err $CS_ROOT/logs/catalina.err.1

fi

if [ -f "$CS_ROOT/logs/catalina.out" ]; then

    mv $CS_ROOT/logs/catalina.out $CS_ROOT/logs/catalina.out.1

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
#
# Special case: JVM Options are complex and difficult to pass through arguments.  
# Instead, set them in the environment:
#     CYCLECLOUD_WEBSERVER_JVM_OPTIONS
python3 /cs-install/scripts/cyclecloud_install.py --acceptTerms \
    --useManagedIdentity --username=${CYCLECLOUD_USERNAME} --password="${CYCLECLOUD_PASSWORD}" \
    --publickey="${CYCLECLOUD_USER_PUBKEY}" \
    --storageAccount=${CYCLECLOUD_STORAGE} \
    --resourceGroup=${CYCLECLOUD_RESOURCE_GROUP} ${DRYRUN} ${NO_DEFAULT_ACCOUNT} \
    --webServerMaxHeapSize=${CYCLECLOUD_WEBSERVER_MAX_HEAP_SIZE} \
    --webServerPort=${CYCLECLOUD_WEBSERVER_PORT} \
    --webServerSslPort=${CYCLECLOUD_WEBSERVER_SSL_PORT} \
    --webServerClusterPort=${CYCLECLOUD_WEBSERVER_CLUSTER_PORT} \
    --webServerHostname="${CYCLECLOUD_HOSTNAME}"


# Enable force delete if specified
cat <<EOF > ${CS_ROOT}/config/data/force_delete.txt
AdType = "Application.Setting"
Name = "cyclecloud.force_delete.vm"
Value = ${CYCLECLOUD_FORCE_DELETE_VMS}

AdType = "Application.Setting"
Name = "cyclecloud.force_delete.vmss"
Value = ${CYCLECLOUD_FORCE_DELETE_VMSS}

EOF


#keep Container alive permanently
while true
do
  sleep 600
  ${CS_ROOT}/cycle_server status || exit
done

