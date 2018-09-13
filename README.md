Ubuntu Env Installer
====================

Installer scripts to set up my dev and desktop environments.

Some scripts require `config.sh` for configuration env variables. I've included an example.


Scripts
-------

### add-user.sh

Adds and configures a user.

Requires config.sh


### install-ubuntu-console.sh

Installs a console work environment.
Note: The script assumes permissions that won't work in an unprivileged container.

Requires config.sh


### install-ubuntu-desktop.sh

Installs common desktop environment software for a work computer.


### install-ubuntu-remote-desktop.sh

Installs the Mate desktop, as well as x2go and chrome remote desktop.
This can be installed on a vm or an unprivileged container.


### quick-config.sh

Copies config.sh.example to config.sh.


### use-local-mirror.sh

Modifies /etc/apt/sources.list to look at a local mirror first.

Requires config.sh
