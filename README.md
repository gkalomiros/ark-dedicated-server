# ARK: Survival Evolved - Docker

Docker build for managing an ARK: Survival Evolved server.

This image uses [Ark Server Tools](https://github.com/FezVrasta/ark-server-tools) to manage an ark server and
is inspired by [Moletrix/Docker_ARK-Server](https://github.com/Moletrix/Docker_ARK-Server)
and [jacobped/docker-ark-server-tools](https://github.com/jacobped/docker-ark-server-tools).

## Features
 - Easy install (no steamcmd / lib32... to install)
 - Use Ark Server Tools : update/install/start/backup/rcon/mods
 - Easy crontab configuration
 - Easy access to ark config file
 - Mods handling (via Ark Server Tools)
 - `Docker stop` is a clean stop 
 - Auto upgrading of arkmanager

## Usage
Fast & Easy server setup:
```bash
docker run --detach \
  --publish 7778:7778/udp \
  --publish 27015:27015/udp \
  --env SESSIONNAME=myarkserver \
  --env ADMINPASSWORD="myadminpassword" \
  --name containername gkalomiros/ark-dedicated-server
```

### Container Runtime Manipulation
You can map the ark volume to access config files:
```bash
docker run --detach \
  --publish 7778:7778/udp --publish 27015:27015/udp \
  --env SESSIONNAME=myarkserver --env ADMINPASSWORD="myadminpassword" \
  --volume /ark/manager/installation:/home/steam/arkmanager \
  --volume /ark/server/installation:/home/steam/arkserver \
  --volume /configuration/files:/home/steam/etc \
  --name containername gkalomiros/ark-dedicated-server
```

This will persist the ark-server-tools, ark game files, and your customized configurations between container runs.
Once started, the container will write its current (default) configuration files to the /home/steam/etc volume for
any file that isn't already located there. For expected files that already exist in that volume on startup, they will
be used for configuring the service. The following files are used:
  - crontab : used to automate tasks within the container while it is running.
  - main.cfg : the instance configuration file used by ark-server-tools.
  - Game.ini and GameUserSettings.ini : ARK's configuration files.


You can manager your server with rcon if you map the RCON port: 
```bash
docker run --detach \
  --publish 7778:7778/udp \
  --publish 27015:27015/udp \
  --publish 32330:32330 \
  --env SESSIONNAME=myarkserver \
  --env ADMINPASSWORD="myadminpassword" \
  --name containername gkalomiros/ark-dedicated-server
```


Any of the network ports can be remapped, for example, if you run multiple instances on the same host:
```bash
docker run --detach \
  --publish 7779:7779/udp \
  --publish 27016:27016/udp \
  --publish 32331:32331 \
  --env SESSIONNAME=myarkserver \
  --env ADMINPASSWORD="myadminpassword" \
  --env GAMEPORT=7779 \
  --env SERVERPORT=27016 \
  --env RCONPORT=32331 \
  --name containername gkalomiros/ark-dedicated-server
```


### Running arkmanager Commands
Any commands available in ark-server-tools can be accessed on a running container like so:
```bash
docker exec containername /home/steam/arkmanager/usr/local/bin/arkmanager/arkmanager <command>
```
__You can check all available command for arkmanager__ [here](https://github.com/arkmanager/ark-server-tools/blob/master/README.md)


### Job Automation
Tasks can be automated by editing `/home/steam/etc/crontab`.
__You can check [this website](http://www.unix.com/man-page/linux/5/crontab/) for more information on cron.__

Chnages to this file will be picked up on container restarts, but can be consumed immediately with the following command:
`docker exec containername crontab -u steam /home/steam/etc/crontab`

### Mods
To add mods, simply add them as a comma-separated list to the MODS environment variable:
```bash
docker run --detach \
  --publish 7778:7778/udp \
  --publish 27015:27015/udp \
  --env SESSIONNAME=myarkserver \
  --env ADMINPASSWORD="myadminpassword" \
  --env MODS="1,2,3" \
  --name containername gkalomiros/ark-dedicated-server
```


## Recommended Usages
### Simple container
I use a bash script something like this:
```bash
ARK_UID=`id --user steam`
ARK_GID=`id --group steam`
SESSIONNAME="myarkserver"
SERVERPASSWORD="serverpassword"
ADMINPASSWORD="adminpassword"
SERVERPORT=7778
GAMEPORT=27015
if [ "`docker ps --all --quiet --filter name=${SESSIONNAME}`" == "" ]; then
    echo "Initializing $SESSIONNAME"
    docker run \
        --attach STDIN \
        --attach STDOUT \
        --attach STDERR \
        --interactive \
        --tty \
        --publish "${SERVERPORT}:${SERVERPORT}/udp" \
        --publish "${GAMEPORT}:${GAMEPORT}/udp" \
        --env "SERVERPORT=$SERVERPORT" \
        --env "GAMEPORT=$GAMEPORT" \
        --env "ARK_UID=$ARK_UID" \
        --env "ARK_GID=$ARK_GID" \
        --env "SERVERPASSWORD=$SERVERPASSWORD" \
        --env "ADMINPASSWORD=$ADMINPASSWORD" \
        --volume /home/steam/arkmanager:/home/steam/arkmanager \
        --volume /home/steam/arkserver:/home/steam/arkserver \
        --volume /home/steam/etc:/home/steam/etc \
        --name "$SESSIONNAME" \
        gkalomiros/ark-dedicated-server:latest
else
    echo "Starting $SESSIONNAME"
    docker start --attach $SESSIONNAME
fi
```
On first run, wait for the service to come up, the Ctrl+C to stop the container.
Then, edit the configuration files in /home/steam/etc to your liking.
Then, run the command again, log in, test it out, and repeat to tweak as desired.
Once, satisfied, enter the script into the system service manager of your choice.

