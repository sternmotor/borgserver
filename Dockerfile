# Debian based borg server - multistage docker image

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# STAGE 1: compile borg software to /usr/local/borg
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM debian:10-slim AS builder

ARG BORG_VERSION=1.1.16
    
RUN set -ex \
 && apt-get update \
 # build packages
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes \
        build-essential \
        libacl1 libacl1-dev\
        openssl libssl-dev \
        python3 python3-dev \
        python3-pip \
        virtualenv


RUN set -ex \
 && virtualenv --python=python3 /opt/borg \
 && . /opt/borg/bin/activate \
 && python3 -m pip install borgbackup==$BORG_VERSION 


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# STAGE 2: 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM debian:10-slim 

# application packages installation
RUN set -ex \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes --no-install-recommends --no-install-suggests \
        acl \
        openssh-server \
        python3-minimal \
        python3-distutils \
 && apt-get --yes autoremove && apt-get clean \
 && rm -rf /tmp/* /usr/share/doc/ /var/lib/apt/lists/* /var/tmp/* 


COPY --from=builder /opt/borg /opt/borg
COPY bin/ /usr/local/bin/
COPY config/sshd_config /etc/ssh/


# application runtime config
RUN set -ex \
 # create borg group and user, set random password
 && groupadd borg-admin --gid 1000 \
 && groupadd borg-repo --gid 1001 \
 && groupadd borg-appendonly --gid 1002 \
 && useradd --gid 1000 --uid borg-admin --create-home --shell /bin/bash borg \
 && echo "borg:$(tr -dc _A-Z-a-z-0-9 </dev/urandom | head -c${1:-32})" | chpasswd \
 # sshd privilege separation workdir
 && mkdir -p /run/sshd

ENV PATH="/opt/borg/bin:$PATH"

# docker integration
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD /usr/sbin/sshd -D -e

# vim: set ft=sh:ts=4:sw=4:
