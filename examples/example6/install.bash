#!/bin/bash

set -o errexit
set -o nounset

repodir=$1
user=$2

# Alternatively a system account with no shell access could be created:
# sudo useradd --system --shell /usr/sbin/nologin --create-home --add-subids-for-system -d "/home/$user" -- "$user"
sudo useradd -- "$user"

sudo mkdir -p /srv/backend-socketdir

#sudo chown  -- "$user:$user" /srv/dir

uid=$(id -u -- "$user")

sourcedir="$repodir/examples/example6"

sudo install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-reverse-proxy-conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/nginx-example-com.conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-reverse-proxy-conf" "$sourcedir/nginx-reverse-proxy-conf/default.conf"

sudo install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/nginx-backend-conf"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/nginx-backend-conf" "$sourcedir/nginx-backend-conf/default.conf"

sudo install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers/systemd"
sudo install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/nginx.container"
sudo install --mode 0644 -Z -D -o root -g root --target-directory /etc/systemd/system/ "$sourcedir/example6-proxy.socket"

# envsubst is used for text replacement
cat $repodir/examples/example6/example6-proxy.service.in | sudo bash -c "cat - | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-proxy.service"
cat $repodir/examples/example6/example6-backend.service.in | sudo bash -c "cat - | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-backend.service"
cat $repodir/examples/example6/example6-backend.socket.in | sudo bash -c "cat - | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/systemd/system/example6-backend.socket"
cat $repodir/examples/example6/nginx-backend-conf/nginx-example-com.conf.in | sudo bash -c "cat - | envsubst_user=$user envsubst_uid=$uid envsubst > /home/$user/nginx-backend-conf/nginx-example-com.conf"

sudo chown "$user:$user" "/home/$user/nginx-backend-conf/nginx-example-com.conf"

sudo loginctl enable-linger "$user"

sudo systemctl daemon-reload

sudo systemctl start example6-backend.socket
sudo systemctl start example6-proxy.socket
