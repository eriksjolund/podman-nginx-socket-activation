#!/bin/bash
set -o errexit
set -o nounset

port=$1
tmpdir=$(mktemp -d)
podman build --build-arg=port=$port -t nginxcustom .
podman create --env "NGINX=3;" --name nginx localhost/nginxcustom
mkdir -p ~/.config/systemd/user
podman generate systemd --name --new nginx > ~/.config/systemd/user/nginx.service
cp nginx.socket ~/.config/systemd/user/
sed -i s/0.0.0.0:11080/0.0.0.0:$port/  ~/.config/systemd/user/nginx.socket
systemctl --user daemon-reload
systemctl --user start nginx.socket

