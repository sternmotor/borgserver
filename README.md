BorgServer docker image
==========================
This image has borg server software installed and runs a SSH server for 
access to 

* different repositories with one single "borg" user or
* different repositories with multiple users, allowing more flexible setups

SSH connections of remote clients are allowed via [SSH publickey
auth][ssh_pubkey], exclusively.

Backup-repositories, public SSH keys of backup clients and sshd hostkeys will
be stored in persistent storage.  

This is a fork of Nold360s great work, check section "Why this fork?" at
bottom.

Quick example
-------------

Here is a quick start instructions how to configure & run borg backup server
container in multi-user mode. Check sections below for details.

**NOTE: I will assume that you know, what a ssh-key is and how to generate &
use it. If not, you might want to start here: [Arch Wiki][archwiki]**

In this example, Data persistence is achieved by mapping local directories -
you may want to use volumes as recommended. 


At first, on docker host where borgserver is running initiate basic directory
structure for ssh keys and backup data storage:

    mkdir -p sshkeys/{borg-repo,borg-appendonly,borg-admin} repos

Add borg clients public SSH keys to a "repository user" key file, *remember*:
filename = borg repository and user name! Add public SSH keys one each line.

    edit sshkeys/borg-repo/borgclient.example.com

Run this docker image, SSH listening on port 22222 like in this example:

    docker run --rm -t \
        -n borgserver \
        -p 22222:22 \
        -v $(pwd)/sshkeys:/sshkeys:rw \
        -v $(pwd)/repos:/repos:rw \
        sternmotor/borgserver:latest


From backup client, connect to borg backup server:

    REPO_URL=ssh://borgclient.example.com@borgserver.example.com:22222/repos/borgclient.example.com
    borg init $REPO_URL --encryption none
    borg create --compression zstd --stats $REPO_URL::home-monday /home

Opionally, sport a ssh config file to pre-define connection options:

* create a `~/.ssh/config` file containing something like

        Host borgserver
            Hostname borgserver.example.com
            Port 22222
            User borgclient.example.com
            ControlPath ~/.ssh/%r@%h:%p
            ControlMaster auto
            ControlPersist 1h

* running borg clients shortens to:
    
        borg init borgserver:borgclient.example.com --encryption none
        borg create --compression zstd --stats borgserver:borgclient.example.com::home-monday /home


Details: Single user operation
------------------------------

One initial user account is hard wired into the image: "borg" (UID 1000) - this
is a "borg-admin" (see multi-user below) account, therefore allowed to create
and run any repository under `/repo`.  

1. set up a comma-separated list of allowed SSH public keys for the "borg"
   account via environment variable `BORG_SSHKEYS` - here, an example snippet
   of a docker-compose file:
    
        ...
        environment:
            BORG_SSHKEYS: >-
                ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-a.example.com,
                ssh-ed25519 BAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-b.example.com,
                ssh-ed25519 CAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-c.example.com
        ...

2. from client side, initiate and run backups like:


        REPO_URL=ssh://borg@borgserver.example.com:22222/repos/borgclient.example.com
        borg init $REPO_URL --encryption none
        borg create --compression zstd --stats $REPO_URL::home-monday /home
    

You may want to adapt the UID and GID of the borg user via `PUID` or `PGID`
environment variable, this can be useful when the container has to access
resources on the host with a specific user id.


Details: Multi user operation
-----------------------------

Multi-user operation allows for restricting access of clients to single
repositories, to run append-only repositories and to have multiple admin
accounts.  Multi-user accounts may be added or removed without restarting the
container.

Each repository is represented by a "repository user" account. A repository may
be named like a host FQDN or docker-compose project. For backing up
docker-compose projects, each service should be stored as single borg archive. 

Multiple users may be allowed to push to a single repository. The idea is that
on docker hosts, root runs backups of all container currently living locally.
Containers are not fixed to reside on one docker host, so multiple docker hosts
with own root accounts must be able to push to the same repository.

When the borgserver container starts, user accounts are automatically created
by running `update-borgusers` inside the container. This can be repeated
anytime later, manually. Repository management is based on files under
`/sshkeys/borg-repo|borg-appendonly|borg-admin` directories. Each directory is
assigned to a user group with the same name. This files contain one SSH public
key each, allowing access to one repository. Each user will be able to access
any file or subdirectory inside of `/repos/<user name>` but no other
directories.

Several modes of borg hosting are realized via user groups :

* `borg-repo`: standard repository user accounts with full access to a single
  repository `/repos/<user_name>` - allowing all borg operations
* `borg-appendonly`: safe repository user accounts allowing no
  "remove" or prune" operations but "init" and "create" operations, only
* `borg-admin`: users given full access to all repositories - no repository is
  created for the borg-admin users. User "borg" is member of this group, too

Users and repositories are added in two steps: 

1. add one or multiple SSH public key of remote SSH client to a single file,
   named like the repository:

    * `/sshkeys/borg-repo`
    * `/sshkeys/borg-appendonly`
    * `/sshkeys/borg-admin`

2. run `update-borgusers` script within container, for example like

        docker exec -ti borgserver update-borgusers

3. from client side, initiate and run backups like:

        REPO_URL=ssh://borgclient.example.com@borgserver.example.com:22222/repos/borgclient.example.com
        borg init $REPO_URL --encryption none
        borg create --compression zstd --stats $REPO_URL::home-monday /home


The script `update-borgusers` is run at each container start.

Repositories are never removed when SSH key files are removed from `/sshkeys`,
but user accounts are pruned. 


Server administration
---------------------

Borg server container may be administered via docker exec directly. Every
non-executable command string will be run as borg command, for example

    docker exec -ti borgserver list


Server configuration details
----------------------------

### SSH client keys

Place borg clients SSH public keys in 

* Single user operation: environment variable `BORG_SSHKEYS`
* Multi user operation: persistent storage volume mounted at `/sshkeys` - hidden files will be ignored!

### SSH server host keys

The `/sshkeys/host` directory and SSH host keys of the borgserver container is
automatically created if it does not exist. This must be persistent storage to
enable a permanent SSH trust relation to borgbackup clients.


### Backup storage

Borg backup writes all client backup data to repository directories under container
`/repos` directory. It's best to start with an empty directory.  Since the
borg client takes care of deduplication, encryption and compression (reducing
bandwith), running backup storage on deduplicated and compressed btrfs may be
overkill. 


### Docker (docker-compose) configuration

Prepare `docker-compose.yml` as in [example file](docker-compose.yml) in this
repository. This snippet displays available options: 

    services:
      borgserver:
        image: sternmotor/borgserver:latest
        volumes:
        - repos:/repos:rw
        - sshkeys:/sshkeys:rw
        ports:
        - "0.0.0.0:22222:22"
        environment:
          PGID: 1000
          PUID: 1000
        environment:
            BORG_SSHKEYS: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-a.example.com
            TZ: Europe/Berlin

	volumes:
        repos:
        sshkeys:

A OpenSSH-Deamon will expose on port 22/tcp - you may want to redirect it to
listen on a different port not interfering with host's ssh.

Available environment variables - all are optional
* Use the following variables if you want to set special options for the "borg
  serve"-command of multi-user groups (see section above). 

    * `REPO_EXTRA_ARGS`: options for full-access repositories
    * `APPENDONLY_EXTRA_ARGS`: options for restricted repositories
    * `ADMIN_EXTRA_ARGS`: options for serving all repositories to admin users
      (including "borg")

  This extra options may be used for "quota" options for example. See the
  documentation for available arguments: [readthedocs.io][serve_doc]. Default is
  to set no extra options. Example call, setting a 20GB quota for all
  "append-only" repositories:

          docker run --rm -e APPENDONLY_EXTRA_ARGS="--progress --storage-quota 20G" sternmotor/borgserver

* `PUID`, `PGID`: Used to set the user id and group id of the `borg` user
  inside the container. This can be useful for single user operation (see
  section above) when the container has to access resources on the host with a
  specific user id.  Default is 1000 for both.

          docker run --rm -e PUID=2048 -e PGID=2048 sternmotor/borgserver

* `BORG_SSHKEYS`: add ssh keys for logging in to user "borg" in single user
  operation, see section above



Why this fork?
==============

Some changes have been applied to original Nold360 approach, mainly around the
idea that mutiple hosts should be able to write to the same repository. Use
case is the backup of containers with no fixed location in a cluster.

* sshd: easier management of borg serve options via group handling (behaviour is
  layed down in sshd dameon config, not public key files)
* sshd: restricted logins to "borg-xxx" groups
* sshd: added keepalive option
* one public SSH key may be mapped to multiple "repository users"
* all repositories are side by side under `/repos`, sub-directories are not allowed
* run latest stable borg version via pip install in space-efficient multistage
  image

[ssh_pubkey]: https://wiki.archlinux.org/index.php/SSH_Key
[pip]: https://pypi.org/project/pip
[serve_doc]: https://borgbackup.readthedocs.io/en/stable/usage/serve.html 
[archwiki]: https://wiki.archlinux.org/index.php/SSH_Keys
