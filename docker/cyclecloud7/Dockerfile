FROM centos:7

WORKDIR /cs-install
ENV CS_ROOT /opt/cycle_server
ENV BACKUPS_DIRECTORY /azurecyclecloud


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
    && useradd -m -d /opt/cycle_server -s /bin/nologin cycle_server \
    && yum -y update \
    && yum install -y azure-cli

ADD https://aka.ms/downloadazcopy-v10-linux /tmp/azcopy_linux.tar.gz

RUN tar xzf /tmp/azcopy_linux.tar.gz -C /tmp/ \
    && mv /tmp/azcopy_linux*/azcopy /usr/local/bin/azcopy

RUN echo -e "[cyclecloud]"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "name=cyclecloud"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "gpgcheck=1"  >> /etc/yum.repos.d/cyclecloud.repo \
    && echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc"  >> /etc/yum.repos.d/cyclecloud.repo \
    && yum -y update \
    && yum install -y cyclecloud \
    && /opt/cycle_server/cycle_server execute 'purge where AdType in { "AuthenticatedUser", "Credential", "AuthenticatedSession", "Application.Task", "Cloud.ChefNodeData", "Event", "ClusterEvent", "NodeEvent", "ClusterMetrics", "NodeMetrics", "SystemAspect", "Application.Tunnel" }' \
    && /opt/cycle_server/cycle_server stop \
    && rm -f /opt/cycle_server/.ssh/* \
    && rm -f /opt/cycle_server/logs/* \
    && sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerPort\=8080/webServerPort\=80/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerSslPort\=8443/webServerSslPort\=443/' /opt/cycle_server/config/cycle_server.properties \
    && sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' /opt/cycle_server/config/cycle_server.properties

RUN cd /tmp \
    && unzip /opt/cycle_server/tools/cyclecloud-cli.zip \
    && cd /tmp/cyclecloud-cli-installer \
    && /tmp/cyclecloud-cli-installer/install.sh --system \
    && rm -rf /tmp/cyclecloud-cli-installer

RUN echo "Caching cycle_server install in container..." \
    && mv /opt/cycle_server /opt_cycle_server

ADD . /cs-install

