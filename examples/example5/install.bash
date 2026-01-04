#!/bin/bash

set -o errexit
set -o nounset

# This script should be executed as root.

repodir=$1
user=$2

# Alternatively a system account with no shell access could be created:
# useradd --system --shell /usr/sbin/nologin --create-home --add-subids-for-system -d "/home/$user" -- "$user"
useradd -- "$user"

uid=$(id -u -- "$user")
sourcedir="$repodir/examples/example5"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-reverse-proxy-conf"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/caddy-example-com.conf"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/default.conf"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/socketdir"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user" "$sourcedir/Caddyfile"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers/systemd"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/caddy.container"
install --mode 0644 -Z -D -o root -g root --target-directory /etc/systemd/system/ "$sourcedir/example5.socket"

# envsubst is used for substituting placeholders in the text with environment variable values
cat $repodir/examples/example5/example5.container.in | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/container/system/example5.container

loginctl enable-linger $user

systemctl daemon-reload
systemctl --user -M "$user@" daemon-reload
systemctl --user -M "$user@" start caddy.service
systemctl start example5.socket
