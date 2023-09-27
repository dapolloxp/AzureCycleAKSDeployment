FROM centos:centos8

WORKDIR /cs-install
ENV CS_UID 1169
ENV CS_GID 1169
ENV CS_ROOT /opt/cycle_server

ADD https://aka.ms/downloadazcopy-v10-linux /tmp/azcopy_linux.tar.gz

RUN yum update -y \
    && echo \
    && yum install -y java-1.8.0-openjdk \
    && yum install -y vim-enhanced \
    && yum install -y wget \
    && yum install -y unzip \
    && yum install -y ncurses \
    && rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && echo -e "[azure-cli]" > /etc/yum.repos.d/azure-cli.repo \
    && echo -e "name=Azure CLI" >> /etc/yum.repos.d/azure-cli.repo \
    && echo -e "baseurl=https://packages.microsoft.com/yumrepos/azure-cli" >> /etc/yum.repos.d/azure-cli.repo \
    && echo -e "enabled=1" >> /etc/yum.repos.d/azure-cli.repo \
    && echo -e "gpgcheck=1" >> /etc/yum.repos.d/azure-cli.repo \
    && echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> /etc/yum.repos.d/azure-cli.repo \
    && echo -e "[cyclecloud]"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "name=cyclecloud"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "gpgcheck=1"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc"  >> /etc/yum.repos.d/cyclecloud.repo \
    && yum -y update \
    && yum install -y azure-cli \
    && tar xzf /tmp/azcopy_linux.tar.gz -C /tmp/ \
    && mv /tmp/azcopy_linux*/azcopy /usr/local/bin/azcopy \
    && rm -rf /tmp/azcopy_linux* \
    && alternatives --set python /usr/bin/python3

RUN groupadd -g ${CS_GID} cycle_server \
    && useradd -u ${CS_UID} -g ${CS_GID} -m -d /opt/cycle_server cycle_server \
    && yum install -y cyclecloud8 \
    && /opt/cycle_server/cycle_server await_startup \
    && /opt/cycle_server/cycle_server execute 'purge where AdType in { "AuthenticatedUser", "Credential", "AuthenticatedSession", "Application.Task", "Cloud.ChefNodeData", "Event", "ClusterEvent", "NodeEvent", "ClusterMetrics", "NodeMetrics", "SystemAspect", "Application.Tunnel" }' \
    && /opt/cycle_server/cycle_server stop \
    && rm -f /opt/cycle_server/.ssh/* \
    && rm -f /opt/cycle_server/logs/* \
    && sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerPort\=8080/webServerPort\=8080/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerSslPort\=8443/webServerSslPort\=8443/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' /opt/cycle_server/config/cycle_server.properties \
    && cd /tmp \
    && unzip /opt/cycle_server/tools/cyclecloud-cli.zip \
    && cd /tmp/cyclecloud-cli-installer \
    && /tmp/cyclecloud-cli-installer/install.sh --system \
    && rm -rf /tmp/cyclecloud-cli-installer \
    && touch /opt/cycle_server/data/ads/initial_load.marker \
    && chmod 777 /opt \
    && chown cycle_server:cycle_server /opt/cycle_server/data/ads/initial_load.marker
    
# Stash a copy the cycle_server/data/ads directory to allow mounting a persistent volume at data/ or data/ads 
# If an empty volume is mounted, we'll copy the initial data directory back to the volume
RUN echo "Stashing a copy of the cycle_server data directory..." \
    && mkdir -p /opt_cycle_server/  \
    && cp -a /opt/cycle_server/data /opt_cycle_server/  \
    && cp -a /opt/cycle_server/work /opt_cycle_server/  \
    && chown -R cycle_server:cycle_server /opt_cycle_server  \
    && ls -ltra  /opt_cycle_server/data/ads/

# Prepare directory structure for mounting persistent volumes
# Retain content of data, and work directories
# Clear content of .ssh and logs directories
# NOTE: we do not persist the config directory since content may change across upgrades
#       instead, we configure using container startup script
RUN echo "Creating mount location and symlinks for data, .ssh, logs, work" \
    && mkdir -p /mnt/cycle_server/  \
    && mv /opt/cycle_server/data /mnt/cycle_server/ \
    && mv /opt/cycle_server/work /mnt/cycle_server/ \
    && rm -rf /opt/cycle_server/.ssh \
    && rm -rf /opt/cycle_server/logs \
    && mkdir -p /mnt/cycle_server/.ssh  \
    && mkdir -p /mnt/cycle_server/logs  \
    && chmod 700 /mnt/cycle_server/.ssh \
    && ln -sf /mnt/cycle_server/data /opt/cycle_server/data \
    && ln -sf /mnt/cycle_server/work /opt/cycle_server/work \
    && ln -sf /mnt/cycle_server/.ssh /opt/cycle_server/.ssh \
    && ln -sf /mnt/cycle_server/logs /opt/cycle_server/logs \
    && chown -R cycle_server:cycle_server /mnt/cycle_server

ADD ./scripts /cs-install/scripts
RUN chown -R cycle_server:cycle_server /cs-install

# Run container as the unprivileged cycle_server user
# (NOTE: This disallows use of privileged ports 80, 443
#        Instead, we'll bind port 8443 and use an AKS Service to port map 443->8443)
USER cycle_server

