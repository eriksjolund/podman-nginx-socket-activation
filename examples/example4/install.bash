#!/bin/bash

set -o errexit
set -o nounset

repodir=$1
user=$2

# Alternatively a system account with no shell access could be created:
# sudo useradd --system --shell /usr/sbin/nologin --create-home --add-subids-for-system -d "/home/$user" -- "$user"
sudo useradd -- "$user"

uid=$(id -u -- "$user")
sourcedir="$repodir/examples/example4"

sudo install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-reverse-proxy-conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/apache-example-com.conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/caddy-example-com.conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/default.conf"

sudo install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers/systemd"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/apache.container"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/caddy.container"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/example4-net.network"
sudo install --mode 0644 -Z -D -o root -g root --target-directory /etc/systemd/system/ "$sourcedir/example4.socket"

# envsubst is used for text replacement in example4.service
cat $repodir/examples/example4/example4.service.in | sudo bash -c "cat - | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example4.service"

sudo loginctl enable-linger "$user"

sudo systemctl daemon-reload
sudo systemctl --user -M "$user@" daemon-reload
sudo systemctl --user -M "$user@" start apache.service
sudo systemctl --user -M "$user@" start caddy.service
sudo systemctl start example4.socket
