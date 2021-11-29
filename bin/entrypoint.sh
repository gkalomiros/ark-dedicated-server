#!/bin/bash
# Operations that need to be performed as root

export steamhome="/home/steam"
export arkserverroot="${steamhome}/arkserver"

export arkmanagerfile=/home/steam/arkmanager/usr/local/bin/arkmanager/arkmanager
export arkmanager=$arkmanagerfile
if [ "$VERBOSE" == 1 ]; then
    echo "Running in verbose mode"
    arkmanager="${arkmanager} --verbose"
fi

export git_api_header=""
if [ ! -z "$GITHUB_OAUTH" ]; then
    echo "Using github oauth token"
    git_api_header="--header Authorization: token ${GITHUB_OAUTH}"
fi

function echo_and_eval {
    if [ "$VERBOSE" == 1 ]; then
        echo "$1"
    fi
    eval "$1"
}


function fix_root_home_permissions {
    # This is already done in the Dockerfile, so it shouldn't be needed.
    if [ `stat --format '%a' /root` != '777' ]; then
        echo "Adjusting root's home directory permissions"
        echo_and_eval "chmod -R 777 /root"
    fi
}


function fix_steam_home_ownership {
    # If the container uses a different UID/GID for the steam user,
    # then this will need to be executed on every startup.
    chown_needed=0

    if [ "$(id --user steam)" != "$ARK_UID" ]; then 
        echo "Changing steam uid to $ARK_UID."
        echo_and_eval "usermod --non-unique --uid $ARK_UID steam"
        chown_needed=1
    fi

    if [ "$(id --group steam)" != "$ARK_GID" ]; then 
        echo "Changing steam gid to $ARK_GID."
        echo_and_eval "groupmod --non-unique --gid $ARK_GID steam"
        chown_needed=1
    fi

    if [ $chown_needed == 1 ]; then
        echo "steam UID or GID was changed. Home ownership need updating"
        echo_and_eval "chown --recursive steam:steam /home/steam"
    fi
}


function set_timezone {
    # If the container uses a different timezone than the default, UTC,
    # then this will need to be updated every startup.
    if [ ! -z "${TZ}" -a `cat /etc/timezone` != "${TZ}" ]; then
        echo "Setting timezone to '${TZ}'"
        echo_and_eval "echo ${TZ} > /etc/timezone"
        echo_and_eval "dpkg-reconfigure -f noninteractive tzdata"
    fi
}


function start_cron {
    # ark-server-tools has an integrated cron functionality,
    # but using a user crontab that an administrator can edit
    # is more convenient than asking them to run the commands
    # manually on each reboot.
    echo "Starting cron"
    echo_and_eval "cron"
}


function start_ark {
    # Launch run.sh as user steam
    su --preserve-environment --command /home/steam/bin/run.sh steam
}


function install_arkmanager {
    # This is written out to the /home/steam/arkmanager volume.
    # So, it should only be performed on initial startup.
    echo "ark-manager-tools not found. Installing"
    api_root="https://api.github.com/repos/arkmanager/ark-server-tools"
    get_tag_name_command="curl --silent --location ${git_api_auth_header} ${api_root}/releases/latest | jq -r '.tag_name'"
    echo_and_eval "$get_tag_name_command"
    tag_name=`curl --silent --location ${git_api_auth_header} ${api_root}/releases/latest | jq -r '.tag_name'`
    get_commit_command="curl --silent ${git_api_auth_header} --location ${api_root}/git/refs/tags/${tag_name} | jq -r '.object.sha'"
    echo_and_eval "$get_commit_command"
    commit=`curl --silent --location ${git_api_auth_header} ${api_root}/git/refs/tags/${tag_name} | jq -r '.object.sha'`
    echo_and_eval "curl --silent --location https://github.com/arkmanager/ark-server-tools/archive/${commit}.tar.gz | tar --extract --gunzip"
    installer_dir="/home/steam/ark-server-tools-${commit}"
    start_dir=`pwd`
    arkmanageretc="/home/steam/arkmanager/etc/arkmanager"
    echo_and_eval "mkdir --parents --mode=750 /home/steam/arkmanager/usr/local/bin/arkmanager"
    echo_and_eval "cd $installer_dir/tools"
    echo_and_eval "bash $installer_dir/tools/install.sh steam --install-root=/home/steam/arkmanager"
    echo_and_eval "rm $arkmanageretc/*cfg*"
    echo_and_eval "rm $arkmanageretc/instances/*cfg*"
    echo_and_eval "cp /home/steam/template/arkmanager.cfg $arkmanageretc/arkmanager.cfg"
    echo_and_eval "cp /home/steam/template/main.cfg $arkmanageretc/instances/main.cfg"
    echo_and_eval "bash $installer_dir/tools/migrate-config.sh $arkmanageretc/arkmanager.cfg $arkmanageretc/arkmanager.cfg"
    echo_and_eval "bash $installer_dir/tools/migrate-main-instance.sh $arkmanageretc/instances/main.cfg $arkmanageretc/instances/main.cfg"
    echo_and_eval "cp $arkmanageretc/arkmanager.cfg /home/steam/template/arkmanager.cfg"
    echo_and_eval "cp $arkmanageretc/instances/main.cfg /home/steam/template/main.cfg"
    echo_and_eval "cd $start_dir"
    echo_and_eval "rm -rf $installer_dir"
    echo_and_eval "chown -R steam:steam /home/steam"
}


function install_arkserver {
    # This is written out to the /home/steam/arkserver volume,
    # so it should only be needed on the initial startup.
    echo "No game files found. Installing"
    echo_and_eval "mkdir --parents --mode=750 \
        $arkserverroot/backups \
        $arkserverroot/staging \
        $arkserverroot/ShooterGame/Saved/SavedArks \
        $arkserverroot/ShooterGame/Saved/Config/LinuxServer \
        $arkserverroot/ShooterGame/Content/Mods \
        $arkserverroot/ShooterGame/Binaries/Linux"
    echo_and_eval "touch $arkserverroot/ShooterGame/Binaries/Linux/ShooterGameServer"
    echo_and_eval "$arkmanager install"
    echo_and_eval "chown -R steam:steam /home/steam"
}


function main {
    fix_root_home_permissions
    fix_steam_home_ownership
    if [ ! -f $arkmanagerfile ]; then
        install_arkmanager
    fi
    if [ ! -f "$arkserverroot/version.txt" ]; then
        install_arkserver
    fi
    set_timezone
    start_cron
    start_ark
}

main

