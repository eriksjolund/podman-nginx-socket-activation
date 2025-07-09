#!/bash

set -o errexit
set -o nounset

# pull images unless they already exist
for i in docker.io/library/nginx \
	 docker.io/traefik/whoami
do
    if ! podman image exists $i
    then podman pull $i
    fi
done

mkdir -p ~/.config/containers/systemd
mkdir -p ~/.config/systemd/user

cp nginx.socket ~/.config/systemd/user
cp nginx.container ~/.config/containers/systemd
cp whoami1.container ~/.config/containers/systemd
cp whoami2.container ~/.config/containers/systemd
cp example7.network ~/.config/containers/systemd

openssl genrsa -out ~/ca.key 4096
openssl req -x509 -new -nodes -key ~/ca.key -sha256 -days 365 -out ~/ca.crt -subj "/CN=root ca"
openssl genrsa -out ~/server.key 2048
openssl req -new -key ~/server.key -out ~/server.csr  -batch -addext "subjectAltName=DNS:whoami1.example.com,DNS:whoami2.example.com"
openssl x509 -req -in ~/server.csr -CA ~/ca.crt -CAkey ~/ca.key -CAcreateserial -out ~/server.crt -days 365 -sha256 -copy_extensions copy

systemctl --user daemon-reload
systemctl --user start whoami1.service
systemctl --user start whoami2.service
systemctl --user start nginx.socket
systemctl --user start nginx.service
