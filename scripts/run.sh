#!/bin/sh

if [ -n "$DEBUG" ]; then
	set -x
fi

# Variables
REMOTE_USER="${VERA_USER:-root}"
REMOTE_PORT="${REMOTE_PORT:-7676}"
LOCAL_PORT="${LOCAL_PORT:-7676}"
SSH_OPTIONS=" \
-o PubkeyAcceptedKeyTypes=ssh-rsa \
-o StrictHostKeyChecking=no \
-i /vera/id_rsa \
"

if [ -z VERA_HOST ]; then 
	echo "ERROR: VERA_HOST must be set"
	exit 1
fi
REMOTE_HOST=$VERA_HOST

if [ ! -e /vera/id_rsa ]; then
	echo "ERROR: Private key not supplied. Make sure you map private key to /vera_rsa"
	exit 1
fi

# Execute commands on the remote machine
ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Commands to prepare Vera for remote connection
    echo -e "Preparing Vera...\n"
	echo "Checking ser2net istall status"
    # Check if ser2net is installed
    if opkg list-installed | grep -q "^ser2net"; then
        echo "ser2net is already installed."
    else
        echo "ser2net is not installed. Installing..."
        opkg update
        opkg install ser2net
        if [ \$? -eq 0 ]; then
            echo "ser2net has been successfully installed."
        else
            echo "Failed to install ser2net."
        fi
    fi
	echo -e "Done\n"

	# End services peacefully
	echo "Stopping services"
	for service in \
		"cron" \
		"cmh" \
		"cmh-ra" \
		"check_internet" \
		"tunnels_manager.sh" \
		"lighttpd" \
		"dnsmasq" \
		"odhcpd" \
		"sysntpd" \
		;
	do
		echo -n "\$service"
		/etc/init.d/\$service stop 1>/dev/null 2>&1 && echo " - stopped" || echo " - error"
	done
	echo -e "Done\n"

	# Kill any remaining services
	echo "Killing any dangling processes"
	for process in  \
		"Start_LuaUPnP" \
		"Start_serproxy" \
		"serproxy" \
		"lighttpd -f" \
		"LuaUPnP" \
		"cmh-ra-key.priv" \
		"cmh-ra-daemon.sh" \
		"cmh_PnP" \
		"NetworkMonitor" \
		"crond" \
		"ezviz_video_manager.lua" \
		"StreamingTunnelsManager.sh" ;
	do
		kill -9 \$( pgrep -f "\$process" ) 2>/dev/null && echo "\$process - killed"
	done
	echo -e "Done\n"

	# Setup firewall rules to block outside access to ser2net
	echo "Setting firewall rules"
	for rule in \
		"INPUT -p tcp -m tcp --dport ${REMOTE_PORT} -j DROP" \
		"INPUT -s 127.0.0.1/32 -p tcp -m tcp --dport ${REMOTE_PORT} -j ACCEPT" ;
	do
		while iptables -D \$rule 2>/dev/null ; do :; done
		iptables -I \$rule
	done
	echo -e "Done\n"

	echo "Checking ser2net"
    if netstat -tuln | grep -q ":${REMOTE_PORT}"; then
        echo "ser2net already running"
    else
	    echo "Starting ser2net"
        ser2net -C "${REMOTE_PORT}:raw:0:/dev/ttyS0:115200 8DATABITS NONE 1STOPBIT"
	fi
	echo -e "Done\n"

EOF

# Start the SSH tunnel
echo "Starting tunnel"
exec ssh ${SSH_OPTIONS} \
    -4 \
	-N \
	-L 0.0.0.0:${LOCAL_PORT}:localhost:${REMOTE_PORT} \
	${REMOTE_USER}@${REMOTE_HOST}

