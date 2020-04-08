FROM centos:7

WORKDIR /cs-install
ENV CS_ROOT /opt/cycle_server
ENV BACKUPS_DIRECTORY /azurecyclecloud


RUN yum update -y \
    && yum install -y deltarpm \
    && yum install -y java-1.8.0-openjdk \
    && yum install -y vim-enhanced \
    && yum install -y wget \
    && yum install -y unzip \
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

ADD https://aka.ms/downloadazcopy-v10-linux /tmp/azcopy_linux_amd64_10.3.4.tar.gz

RUN tar xzf /tmp/azcopy_linux_amd64_10.3.4.tar.gz -C /tmp/ \
    && mv /tmp/azcopy_linux_amd64_10.3.4/azcopy /usr/local/bin/azcopy

RUN yum install -y cyclecloud \
    cp /opt/cycle_server/tools/cyclecloud-cli.zip /tmp/cyclecloud-cli.zip \
    yum remove -y cyclecloud

RUN cd /tmp \
    && unzip /tmp/cyclecloud-cli.zip \
    && cd /tmp/cyclecloud-cli-installer \
    && /tmp/cyclecloud-cli-installer/install.sh --system

ADD . /cs-install

