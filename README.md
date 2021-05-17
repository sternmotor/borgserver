UNDER CONSTRUCTION

BorgServer docker image
==========================

Debian based container image, running openssh-daemon only accessable by user
named "borg" using [SSH publickey auth][ssh_pubkey].
Backup-repositories, client's SSH keys and sshd hostkeys will be stored in
persistent storage.  

For every ssh-key added, an own borg-repository will be created.

This is a fork of Nold360s great work - switched here to [pip][] install to
have the latest stable version and focused on unattended server and client
operation, setting more defaults. For borgbackup server, running docker-compose
is recommended.

Quick example
-------------


### Export public ssh key on borg client

Copy the ssh public key from terminal for pasting at server

	cat ~/.ssh/id_ed25519.pub or 
	cat ~/.ssh/id_rsa.pub 



### Start borg server

Here is a quick example how to configure & run this image. Data persistence is
achieved here by mapping local directories - you may want to use container
volumes as recommended


Create persistent sshkey storage, adjust permissions

    mkdir -p borg/sshkeys/clients
    chown 1000:1000 borg/sshkeys



(Generate &) Copy every client's ssh publickey into persistent storage, *remember*: Filename = Borg-repository name!

    cat - > borg/sshkeys/clients/example_repo
    # paste into terminal, CTRL-D 


The OpenSSH-Deamon will expose on port 22/tcp - so you will most likely want to redirect it to a different port. Like in this example:

    docker run -td \
        -p 2222:22  \
        -v ./borg/sshkeys:/sshkeys \
        -v ./borg/backup:/backup \
        sternmotor/borgserver:latest

### Run borg client

Assuming the docker client is a container, too 

    docker run sternmotor/borgclient borg init 
    docker run sternmotor/borgclient borg create



Now initiate a borg-repository like this:
```
 $ borg init backup:my_first_borg_repo
```

And create your first backup!
```
 $ borg create backup:my_first_borg_repo::documents-2017-11-01 /home/user/MyImportentDocs
```


Borgserver configuration
------------------------

### SSH client keys

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
(reducing bandwith), running backup storage on for example deduplicated and
compressed btrfs may be overkill. 



### Docker configuration

Adjust docker log squeezing globally in `/etc/docker/daemon.json`:

    {
        "log-driver": "json-file",
        "log-level": "warn",
        "log-opts": {
    	"max-file": "3",
    	"max-size": "2M",
    	"mode": "non-blocking"
        },
    }

Prepare `docker-compose.yml`

    services:
      borgserver:
        image: sternmotor/borgserver:1.1.16
        volumes:
         - /backup:/backup:rw
         - ./sshkeys:/sshkeys:rw
        ports:
         - "2222:22"
        environment:
         BORG_SERVE_ARGS: ""
         BORG_APPEND_ONLY: "no"
         BORG_ADMIN: ""
         PUID: 1000
         PGID: 1000

	

    BORG_REPOSITORIES=/backup \
    BORG_SSH_KEYS=/sshkeys

### BORG_SERVE_ARGS

Use this variable if you want to set special options for the "borg serve"-command, which is used internally.

See the the documentation for all available arguments: [borgbackup.readthedocs.io](https://borgbackup.readthedocs.io/en/stable/usage.html#borg-serve)

	docker run --rm -e BORG_SERVE_ARGS="--progress --debug" (...) sternmotor/borgserver


### PUID
Used to set the user id of the `borg` user inside the container. This can be useful when the container has to access resources on the host with a specific user id.


### PGID
Used to set the group id of the `borg` group inside the container. This can be useful when the container has to access resources on the host with a specific group id.


### Persistent Storages & Client Configuration
We will need two persistent storage directories for our borgserver to be usefull.

#### /sshkeys
This directory has two subdirectories:


## Example Setup
### docker-compose.yml
Here is a quick example, how to run borgserver using docker-compose:
```
```

### ~/.ssh/config for clients
With this configuration (on your borg client) you can easily connect to your borgserver.
```
Host backup
    Hostname my.docker.host
    Port 2222
    User borg
```




Why this fork?
==============

* switch to docker-compose setup for borg server
* dropped `BORG_ADMIN` support - every client may run prune action after backup
* set some more defaults directly in image
* ssh: added sandboxing
* fixed borg version


BORG CLIENT!!

[ssh_pubkey]: https://wiki.archlinux.org/index.php/SSH_Key
[pip]: https://pypi.org/project/pip
