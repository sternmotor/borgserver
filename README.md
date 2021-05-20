
Quick example
-------------

### Export public ssh key on borg client

Copy the ssh public key from terminal for pasting at server

	cat ~/.ssh/id_ed25519.pub or 
	cat ~/.ssh/id_rsa.pub 


### Start borg server



Create persistent backup and sshkey storage, adjust permissions

    mkdir -p borg/sshkeys/clients /borg/backup

Copy every client's ssh publickey into persistent storage, *remember*: Filename
= borg client name!

    cat - > borg/sshkeys/clients/client_name
    # paste into terminal, CTRL-D 



### Run borg client

Check out sternmotor borg client image or run like:
    
    borg init ssh://borg@borgserver:22/backup/example_client --encryption none
    borg create --compression zstd --stats ssh://borg@borgserver:22/backup/example_repo::monday /home


Borgserver configuration
------------------------






