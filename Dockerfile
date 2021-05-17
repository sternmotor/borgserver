# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Debian based borg server - multistage docker image
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# stage 1

FROM debian:10-slim AS builder

ARG BORG_VERSION=1.1.16
    
# package installation and compilation
RUN set -ex \
 && apt-get update \
 # build packages
 && DEBIAN_FRONTEND=noninteractive \
    #apt-get install --yes --no-install-recommends --no-install-suggests \
    apt-get install --yes \
        python3 \
        python3-dev \
        python-virtualenv \
        python3-pip \
        libssl-dev \
        openssl \
        libacl1-dev \
        libacl1 \
        build-essential 

RUN set -ex \
 && virtualenv --python=python3 /usr/local/borg \
 && . /usr/local/borg/bin/activate \
 && python3 -m pip install borgbackup==$BORG_VERSION 


# stage 2

FROM debian:10-slim 

ENV \
    PUID=1000 \
    PGID=1000 \
    SSH_MAX_SESSIONS=20 \
    BORG_SERVE_ARGS='' \
    BORG_REPOSITORIES=/backup \
    BORG_SSH_KEYS=/sshkeys 

# package installation
RUN set -ex \
 && apt-get update \
 # application packages
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes openssh-server \
 && apt-get --yes autoremove && apt-get clean \
 && rm -rf /tmp/* /usr/share/doc/ /var/lib/apt/lists/* /var/tmp/* 


COPY --from=builder /usr/local/borg /usr/local
COPY files/ /

# application runtime config
RUN set -ex \
 # make borg executable available in path
 && ln -sf /opt/borg/bin/borg /usr/local/bin/ \
 # create borg group and user, set random password
 && groupadd borg --gid $PGID \
 && useradd --gid $PGID --uid $PUID --create-home --shell /bin/bash borg \
 && echo "borg:$(tr -dc _A-Z-a-z-0-9 </dev/urandom | head -c${1:-32})" | chpasswd


# docker integration
WORKDIR "$BORG_REPOSITORIES"
VOLUME "$BORG_REPOSITORIES"
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]

# vim: set ft=sh:ts=4:sw=4:
