Single user operation
---------------------

One initial user account is hard wired into the image: "borg" (UID 1000) - this is a borg-admin account, therefore allowed to create and run any repository under `/repo`.  You should set up a comma-separated list of allowed SSH public keys for this account via environment variable `BORG_SSHKEYS`:


    environment:
        BORG_SSHKEYS: >
            ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-a.example.com,
            ssh-ed25519 BAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-b.example.com,
            ssh-ed25519 CAAAC3NzaC1lZDI1NTE5AAAAIPmrPrtinCGxvYsNYzEAYGPRQ7NyTWuActrTvjfG/lxV root@server-c.example.com

From client side, create repositories like:


    borg init ssh://borg@
TODODODODODO

    

You may want to adapt the UID and GID of the borg user via `PUID` or `PGID` environment variable, this can be useful when the container has to access resources on the host with a specific user id.


Multi user operation
--------------------

Multi-user operation allows for restricting access of clients to single
repositories, to run append-only repositories and to have more admin accounts.
Multi-user accounts may be changed without restarting the container.

Each repository is represented by a user account. A repository may be named
like a host fqdn or docker-compose project. In each repository, several
docker-compose services may be stored as borg archives.

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

1. add one single SSH public key of remote client as one single file, named like the repository to one of
    * `/sshkeys/repos`
    * `/sshkeys/repos-appendonly`
    * `/sshkeys/admins`

2. run `update-borgusers` script within container, for example like

        docker exec -ti borgserver_01 update-borgusers

Repositories are never removed when SSH key files are removed from `/sshkeys`, but user accounts are pruned. The script `update-borgusers` is run at each container start.

From client side, create repositories like:


TODODODODO


Server administration
---------------------

- borg may be administredrded via docker exec, every non-executable command string will be run as borg command, for example

    docker exec -ti borg01 list all



 - just drop the SSH public key of connecting client into a 




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

    


EXTRA_REPO_SERVE_ARGS   --quota
EXTRA_ADMIN_SERVE_ARGS
EXTRA_APPENDONLY_SERVE_ARGS
PUID
PGID
BORG_SSHKEYS


Why fork
* easier management of borg serve options via group handling, behaviour is layed down in sshd dameon config, not public key files

