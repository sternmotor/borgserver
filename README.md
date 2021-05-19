BorgServer docker image
==========================
This image has borg server software installed and runs a SSH server for single
"borg" user. Different repositories can be run under one "client" access,
pinned down by single [SSH publickey auth][ssh_pubkey] to user "borg".

This allows for example a docker host to connect to borg server as "client",
using its own private SSH key and run backups to separate borg repositories for
each local docker-compose project or kubernetes pod.

Backup-repositories, client's SSH keys and sshd hostkeys will be stored in
persistent storage.  

This is a fork of Nold360s great work, check section "Why this fork?" at
bottom.

Quick example
-------------

### Export public ssh key on borg client

Copy the ssh public key from terminal for pasting at server

	cat ~/.ssh/id_ed25519.pub or 
	cat ~/.ssh/id_rsa.pub 


### Start borg server

Here is a quick example how to configure & run this image. Data persistence is
achieved here by mapping local directories - you may want to use volumes as
recommended


Create persistent backup and sshkey storage, adjust permissions

    mkdir -p borg/sshkeys/clients /borg/backup

Copy every client's ssh publickey into persistent storage, *remember*: Filename
= borg client name!

    cat - > borg/sshkeys/clients/client_name
    # paste into terminal, CTRL-D 


The OpenSSH-Deamon will expose on port 22/tcp - so you will most likely want to
redirect it to a different port. Like in this example:

    docker run -td \
        -p 2222:22  \
        -v $(pwd)/borg/sshkeys:/sshkeys \
        -v $(pwd)/borg/backup:/backup \
        sternmotor/borgserver:latest


### Run borg client

Check out sternmotor borg client image or run like:
    
    borg init ssh://borg@borgserver:22/backup/example_client --encryption none
    borg create --compression zstd --stats ssh://borg@borgserver:22/backup/example_repo::monday /home


Borgserver configuration
------------------------

### SSH client keys

**NOTE: I will assume that you know, what a ssh-key is and how to generate &
use it. If not, you might want to start here: [Arch Wiki][archwiki]**


Place borg clients SSH public keys in persistent storage, client backup
directories will be named by the filename found in `/sshkeys/clients/`.  Hidden
files & files inside of hidden directories will be ignored!

Here we will put all SSH public keys from our borg clients, we want to backup.
Every key must be it's own file, containing only one line, with the key. The
name of the file will become the name of client directory housing a single or
multiple borg repositories.

That means every client get's it's own repositories. So you might want to use
the hostname of the client as the name of the sshkey file, e.g.

    /sshkeys/clients/webserver.example.com

A client at `webserver.example.com` would have to initiate a single borg repository like this:

    borg init ssh://borg@borgserver.example.com/backup/webserver.example.com

A docker host `docker01.example.com` housing the docker-compose projects
"web01.example.com" and "seafile01.example.com" would have to initiate borg
repositories like this:

    borg init ssh://borg@borgserver.example.com/backup/docker01.example.com/web01.example.com
    borg init ssh://borg@borgserver.example.com/backup/docker01.example.com/seafile01.example.com
    # place public ssh key of root@docker01.example.com under clients/docker01.example.com


The container wouldn't start the SSH-Deamon until there is at least one
ssh-keyfile in `/sshkeys/clients/` 

### SSH server host keys

The `/sshkeys/host` directory and SSH host keys of the borgserver container is
automatically created on first start. 


### Backup storage

Borg backup writes all client backup data to repository dir(s) under container
`/backup` directory. It's best to start with an empty directory.  Since the
borg client takes care of deduplication, encryption and compression (reducing
bandwith), running backup storage on deduplicated and compressed btrfs may be
overkill. 


### Docker configuration

Adjust docker log squeezing globally in `/etc/docker/daemon.json`:

    {
        "log-driver": "json-file",
        "log-level": "warn",
        "log-opts": {
            "max-file": "7",
            "max-size": "20M",
            "mode": "non-blocking"
        },
    }


Prepare `docker-compose.yml` as in [example file](docker-compose.yml) in this
repository. This snippet displays available options: 

    services:
      borgserver:
        image: sternmotor/borgserver:1.1.16
        volumes:
        - backup_data:/backup:rw
        - ssh_client_keys:/sshkeys:rw
        ports:
        - "0.0.0.0:22222:22"
        environment:
          BORG_DATA_DIR: /backup
          SSH_KEY_DIR: /sshkeys
          SSH_LOGLEVEL: DEBUG
          BORG_SERVE_ARGS: ''
          PGID: 1000
          PUID: 1000

	volumes:
        backup_data:
        ssh_client_keys:


Available environment variables - all are optional

* `BORG_SERVE_ARGS`: Use this variable if you want to set special options for
  the "borg serve"-command, which is used internally. See the the documentation
  for available arguments: [readthedocs.io][serve_doc]. Default is to set no
  extra options. Example call:


    docker run --rm -e BORG_SERVE_ARGS="--progress --append-only" sternmotor/borgserver


* `PUID`, `PGID`: Used to set the user id iand group id of the `borg` user
  inside the container. This can be useful when the container has to access
  resources on the host with a specific user id.  Default is 1000 for both.
* `SSH_LOG_LEVEL`: verbosity of sshd daemon in docker logs - one of QUIET,
  FATAL, ERROR, INFO, VERBOSE, DEBUG1, DEBUG2, and DEBUG3. The default is INFO.
  DEBUG and DEBUG1 are equivalent. DEBUG2 and DEBUG3 each specify higher levels
  of debugging output. Logging with a DEBUG level violates the privacy of users
  and is not recommended. 
* `BORG_DATA_DIR`: storage for backup repositories - make this location
  persistent by mounting a docker volume here. Default: `/backups`
* `SSH_KEY_DIR`: storage for client and borg server host keys - make this
  location persistent by mounting a docker volume here. Default: `/sshkeys`


Why this fork?
==============

The forked setup is adapted to productive server operation in a rather closed
environment with well-known connections and focus on straight maintenance process:

* dropped `BORG_ADMIN` construct - every client may run prune action after backup 
* sshd: restricted logins to user "borg", added keepalive option
* borg: restricted client access to repositories under `/backup/<client>` so
  each client may run multiple borg backup repositories for separately named
  docker-compose projects or kubernets pods. The idea is that a docker host as
  borg client runs backup for all local containers.
* run latest stable borg version via pip install in space-efficient multistage
  image


[ssh_pubkey]: https://wiki.archlinux.org/index.php/SSH_Key
[pip]: https://pypi.org/project/pip
[serve_doc]: https://borgbackup.readthedocs.io/en/stable/usage/serve.html 
[archwiki]: https://wiki.archlinux.org/index.php/SSH_Keys
