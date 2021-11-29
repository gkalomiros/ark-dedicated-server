FROM ubuntu:20.04
LABEL org.opencontainers.image.authors="gkalomiros@mister-k.org"

ENV DEBIAN_FRONTEND="noninteractive" \
    RUNLEVEL="1" \
    SESSIONNAME="Ark Docker" \
    SERVERMAP="TheIsland" \
    SERVERPASSWORD="" \
    ADMINPASSWORD="adminpassword" \
    MODS="" \
    MAX_PLAYERS=70 \
    UPDATEONSTART=1 \
    BACKUPONSTART=1 \
    RCONPORT=32330 \
    SERVERPORT=27015 \
    GAMEPORT=7777 \
    RAWPORT=7778 \
    BACKUPONSTOP=1 \
    WARNONSTOP=1 \
    ARK_UID=1000 \
    ARK_GID=1000 \
    TZ="UTC" \
    VERBOSE=0 \
    GITHUB_OAUTH=""

# Update OS, install steamcmd, ark-server-tools dependencies, and some other required tools.
RUN apt-get -y update && \
    apt-get -y install \
        apt-utils \
        software-properties-common \
        tzdata && \
    echo "${TZ}" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata && \
    apt-add-repository multiverse && \
    dpkg --add-architecture i386 && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        jq \
        bash \
        git \
        coreutils \
        findutils \
        perl \
        rsync \
        sed \
        tar \
        sudo \
        cron \
        perl-modules \
        curl \
        lsof \
        libc6-i386 \
        lib32gcc1 \
        bzip2 && \
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get -y install steamcmd && \
    apt-get -y clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# Add steam system user, and copy in default server configurations.
RUN groupadd \
        --gid ${ARK_GID} \
        --system \
        steam && \
    useradd \
        --no-user-group \
        --gid ${ARK_GID} \
        --home-dir /home/steam \
        --create-home \
        --shell /bin/bash \
        --system \
        --uid ${ARK_UID} \
        steam && \
    mkdir --verbose --parents --mode=750 \
        /home/steam/arkmanager/etc/arkmanager/instances \
        /home/steam/arkmanager/usr/local/bin/arkmanager \
        /home/steam/arkmanager/backups \
        /home/steam/arkserver \
        /home/steam/bin \
        /home/steam/etc \
        /home/steam/template && \
    chown -R steam:steam /home/steam
WORKDIR /home/steam
COPY --chown=steam:steam bin/entrypoint.sh bin/entrypoint.sh
COPY --chown=steam:steam bin/run.sh bin/run.sh
COPY --chown=steam:steam etc/crontab template/crontab
COPY --chown=steam:steam etc/arkmanager.cfg template/arkmanager.cfg
COPY --chown=steam:steam etc/main.cfg template/main.cfg

# Set symlinks in place that ark-server-tools will need.
RUN mkdir --parents --mode=755 /etc/arkmanager/instances && \
    touch /home/steam/arkmanager/etc/arkmanager/arkmanager.cfg && \
    ln -s /home/steam/arkmanager/etc/arkmanager/arkmanager.cfg /etc/arkmanager/arkmanager.cfg && \
    rm /home/steam/arkmanager/etc/arkmanager/arkmanager.cfg && \
    touch /home/steam/arkmanager/etc/arkmanager/instances/main.cfg && \
    ln -s /home/steam/arkmanager/etc/arkmanager/instances/main.cfg /etc/arkmanager/instances/main.cfg && \
    rm /home/steam/arkmanager/etc/arkmanager/instances/main.cfg && \
    chown --recursive --no-dereference steam:steam /etc/arkmanager

# Ark-server-tools wants access to this directory even though they're run as steam.
RUN chmod --recursive 777 /root


EXPOSE ${RCONPORT}/tcp
EXPOSE ${SERVERPORT}/udp
EXPOSE ${GAMEPORT}/udp
EXPOSE ${RAWPORT}/udp
VOLUME /home/steam/arkmanager
VOLUME /home/steam/arkserver
VOLUME /home/steam/etc
ENTRYPOINT ["/home/steam/bin/entrypoint.sh"]

