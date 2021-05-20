Setup
-----

* Use the following variables if you want to set special options for the "borg
  serve"-command of multi-user groups (see section below). 

    * `REPO_SERVE_EXTRA_ARGS`  
    * `APPENDONLY_SERVE_EXTRA_ARGS`
    * `ADMIN_SERVE_EXTRA_ARGS`

  This extra options may be for example "quota" options, see the documentation
  for available arguments: [readthedocs.io][serve_doc]. Default is to set no
  extra options. Example call, setting a 20GB quota for all "append-only"
  repositories:

          docker run --rm -e APPENDONLY_SERVE_EXTRA_ARGS="--progress --storage-quota 20G" sternmotor/borgserver

* `PUID`, `PGID`: Used to set the user id and group id of the `borg` user
  inside the container. This can be useful for single user operation (see
  section below) when the container has to access resources on the host with a
  specific user id.  Default is 1000 for both.

          docker run --rm -e PUID=2048 -PGID=2048 sternmotor/borgserver

* `BORG_SSHKEYS`: add ssh keys for logging in to user "borg" in single user
  operation, see section below


Single user operation
---------------------

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


    borg init ssh://borg@
TODODODODODO

    

You may want to adapt the UID and GID of the borg user via `PUID` or `PGID`
environment variable, this can be useful when the container has to access
resources on the host with a specific user id.


Multi user operation
--------------------

Multi-user operation allows for restricting access of clients to single
repositories, to run append-only repositories and to have more admin accounts.
Multi-user accounts may be added or removed without restarting the container.

Each repository is represented by a user account. A repository may be named
like a host fqdn or docker-compose project. In each repository, several
docker-compose services may be stored as borg archives. The idea is that on
docker hosts, root runs backups of all containers but stores these in
repositories independent of the docker host they live on by the time the backup
is done. 

Multiple users may be allowed to push to a single repository - for example
multiple docker hosts can backup up the same container depending where this
container currently lives.

User accounts are automatically created at container startup or by running
`update-borgusers` inside the container.  Repository management is based on
named files under `/sshkeys/repos|repos-appendonly|admins`, this files contain
one SSH public key each, allowing access to one repository. Each user will be able
to access any file or subdirectory inside of `/repos/<user name>` but no other
directories.

Several modes of borg hosting are realized via user groups:

* `borg-repo`: standard user accounts (representing repositories) with full
  access to a single repository `/repos/<user_name>` - allowing all borg
  operations
* `borg-appendonly`: safe user accounts (representing repositories) allowing no
  "remove" or prune" operations, "init" and "create" operations, only
* `borg-admin`: users given full access to all repositories - no repository is
  created for the borg-admin users 

Users and repositories are added in two steps: 

1. add one or multiple SSH public key of remote client to a single file, named like the repository:
    * `/sshkeys/repos`
    * `/sshkeys/repos-appendonly`
    * `/sshkeys/admins`

2. run `update-borgusers` script within container, for example like

        docker ps  --format "{{.Names}}" | sort # list containers
        docker exec -ti borgserver_01 update-borgusers

3. from client side, initiate and run backups like:

TODODODODO


The script `update-borgusers` is run at each container start.

Repositories are never removed when SSH key files are removed from `/sshkeys`,
but user accounts are pruned. 


Server administration
---------------------

Borg server container may be administered via docker exec directly. Every non-executable command string will be run as borg command, for example

    docker exec -ti borg01 list all


 - just drop the SSH public key of connecting client into a 

TODO


Prgrommirtung:
----------------

entrypoint script
    CMD= sshd -e -D

    if $1 = sshd:
        update-repos 
        run $@

    elif $1 <> sshd aber executable (e.g. borg)
        run $@ 

    elif $1 not executable:
        run borg with command/option $@

    else:
        error - CMD not set up in Dockerfile


sshkeys:
    repos/              group borg-repo
    repos-appendonly/   group borg-appendonly
    admins/             group borg-admin
    host/

validate all keys in repos && admins,
* check pubkey format
* error + stop when same repo is in repo and appendonly or admin
* error + stop when bad host keys 

create users and repositores (for repo and appendonly) and map to borg-xxx group according to folder, the rest is done via group-match in sshd_config, globally

run through alle repos - in case there is no listed user ssh key, remove user account


pre-fetch known host key in case it does not exist - chnanges later on break the ssh connection as it should be

    




Why this fork?
==============

Some changes have been applied to original Nold360 approach, mainly around the
idea that mutiple hosts should be able to write to the same repository. Use
case is the backup of containers with no fixed location in a cluster.

* sshd: easier management of borg serve options via group handling (behaviour is
  layed down in sshd dameon config, not public key files)
* sshd: restricted logins to "borg-xxx" groups
* sshd: added keepalive option
* one public SSH key may be mapped to multiple repository users
* all repositories are side by side under `/repos`, sub-directories are not allowed
* run latest stable borg version via pip install in space-efficient multistage
  image

[ssh_pubkey]: https://wiki.archlinux.org/index.php/SSH_Key
[pip]: https://pypi.org/project/pip
[serve_doc]: https://borgbackup.readthedocs.io/en/stable/usage/serve.html 
[archwiki]: https://wiki.archlinux.org/index.php/SSH_Keys
