#!/bin/bash

set -o errexit
set -o nounset

# This script should be executed as root.

repodir=$1
user=$2

# Alternatively a system account with no shell access could be created:
# useradd --system --shell /usr/sbin/nologin --create-home --add-subids-for-system -d "/home/$user" -- "$user"
useradd -- "$user"

mkdir -p /srv/backend-socketdir

#chown  -- "$user:$user" /srv/dir

uid=$(id -u -- "$user")

sourcedir="$repodir/examples/example6"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-reverse-proxy-conf"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/nginx-example-com.conf"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/default.conf"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-backend-conf"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-backend-conf" "$sourcedir/nginx-backend-conf/default.conf"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config"
install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers"
install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers/systemd"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/nginx.container"
install --mode 0644 -Z -D -o root -g root --target-directory /etc/systemd/system/ "$sourcedir/example6-proxy.socket"

# envsubst is used for substituting placeholders in the text with environment variable values
cat $repodir/examples/example6/example6-proxy.service.in | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-proxy.service
cat $repodir/examples/example6/example6-backend.service.in | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-backend.service
cat $repodir/examples/example6/example6-backend.socket.in | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-backend.socket
cat $repodir/examples/example6/nginx-backend-conf/nginx-example-com.conf.in | envsubst_user=$user envsubst_uid=$uid envsubst > /home/$user/nginx-backend-conf/nginx-example-com.conf

chown "$user:$user" "/home/$user/nginx-backend-conf/nginx-example-com.conf"

loginctl enable-linger "$user"

systemctl daemon-reload

systemctl start example6-backend.socket
systemctl start example6-proxy.socket
