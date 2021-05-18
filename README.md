BorgServer docker image
==========================

Debian based container image, running openssh-daemon only accessable by user
named "borg" using [SSH publickey auth][ssh_pubkey].
Backup-repositories, client's SSH keys and sshd hostkeys will be stored in
persistent storage.  

For every ssh-key added, an own borg-repository will be created.

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

Copy every client's ssh publickey into persistent storage, *remember*: Filename = Borg-repository name!

    cat - > borg/sshkeys/clients/example_repo
    # paste into terminal, CTRL-D 


The OpenSSH-Deamon will expose on port 22/tcp - so you will most likely want to redirect it to a different port. Like in this example:

    docker run -td \
        -p 2222:22  \
        -v $(pwd)/borg/sshkeys:/sshkeys \
        -v $(pwd)/borg/backup:/backup \
        sternmotor/borgserver:latest


### Run borg client

Check out sternmotor borg client image or run like:
    
    borg init ssh://borg@borgserver:22/backup/example_repo --encryption none
    borg create --compression zstd --stats ssh://borg@borgserver:22/backup/example_repo::monday /home


Borgserver configuration
------------------------

### SSH client keys

**NOTE: I will assume that you know, what a ssh-key is and how to generate & use it. If not, you might want to start here: [Arch Wiki](https://wiki.archlinux.org/index.php/SSH_Keys)**

Place borg clients SSH public keys in persistent storage, client
backup-directories will be named by the filename found in `/sshkeys/clients/`
Hidden files & files inside of hidden directories will be ignored!

Here we will put all SSH public keys from our borg clients, we want to backup.
Every key must be it's own file, containing only one line, with the key. The
name of the file will become the name of the borg repository, we need for our
client to connect.

That means every client get's it's own repository. So you might want to use the
hostname of the client as the name of the sshkey file, e.g.


    /sshkeys/clients/webserver.example.com

A client at `webserver.example.com` would have to initiate the borg repository like this:

    borg init ssh://borg@borgserver.example.com/backup/webserver.example.com

The container wouldn't start the SSH-Deamon until there is at least one
ssh-keyfile in this directory.

### SSH server host keys

The `/sshkeys/host` directory and SSH host keys of the borgserver container is
automatically created on first start. 


### Backup storage

Borg backup writes all client backup data client to repository dir under
container `/backup` directory. It's best to start with an empty directory.
Since the borg client takes care of deduplication, encryption and compression
(reducing bandwith), running backup storage on deduplicated and
compressed btrfs may be overkill. 



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
repository. This snippet displays avalable options: 

    services:
      borgserver:
        image: sternmotor/borgserver:1.1.16
        volumes:
         - backup_data:/backup:rw
         - ssh_client_keys:/sshkeys:rw
        ports:
         - "0.0.0.0:2222:22"
        environment:
         BORG_SERVE_ARGS: ""
         BORG_APPEND_ONLY: "no"
         BORG_ADMIN: ""
         PUID: 1000
         PGID: 1000

	volumes:
        backup_data
        ssh_client_keys:


Available environment variables - all are optional

* `BORG_SERVE_ARGS`: Use this variable if you want to set special options for the "borg serve"-command, which is used internally. See the the documentation for available arguments: [readthedocs.io][serve_doc]. Default is to set no extra options. Example call:


	docker run --rm -e BORG_SERVE_ARGS="--progress --append-only" sternmotor/borgserver


* `PUID`, `PGID`: Used to set the user id iand group id of the `borg` user inside the container. This can be useful when the container has to access resources on the host with a specific user id.  Default is 1000 for both.

* `SSH_LOG_LEVEL`: verbosity of sshd daemon in docker logs - one of QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG1, DEBUG2, and DEBUG3. The default is INFO. DEBUG and DEBUG1 are equivalent. DEBUG2 and DEBUG3 each specify higher levels of debugging output. Logging with a DEBUG level violates the privacy of users and is not recommended. 
* `BORG_DATA_DIR`: storage for backup repositories - make this location persistent by mounting a docker volume here. Default: `/backups`
* `SSH_KEY_DIR`: storage for client and borg server host keys - make this location persistent by mounting a docker volume here. Default: `/sshkeys`


Why this fork?
==============

* dropped `BORG_ADMIN` support - every client may run prune action after
  backup (you may want to add "--append-only" to `BORG_SERVE_ARGS`)
* ssh: restricted logins to user "borg", added keepalive option
* borg: restricted user access to repository "/backup/<repository>" with no
  sub-repositories
* install latest stable borg version via pip in space-efficient multistage image


[ssh_pubkey]: https://wiki.archlinux.org/index.php/SSH_Key
[pip]: https://pypi.org/project/pip
[serve_doc]: https://borgbackup.readthedocs.io/en/stable/usage/serve.html 
