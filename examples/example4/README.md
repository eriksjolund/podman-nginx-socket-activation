return to [main page](../..)

## Example 4

status: experimental

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->|"for http://apache.example.com"| a3["apache httpd container"]
    a2 -->|"for http://caddy.example.com"| a4["caddy container"]
```

This example is similar to [Example 3](../example3) but here the nginx container is configured
as an HTTP reverse proxy for two backend web server containers (apache httpd and caddy) that
are running in systemd user services. All containers are run by rootless podman,
which belongs to the user _test_.
The containers communicate over an internal bridge network that does not have internet access.

#### set up _example4.service_

1. Create the user _test_ if it does not yet exist.
   ```
   $ sudo useradd test
   ```
2. Check the UID of the user _test_
   ```
   $ id -u test
   1000
   ```
3. Create the directory _/home/test/nginx_conf_d_
4. Create the file _/home/test/nginx_conf_d/default.conf_ with the contents
   ```
   server {
    listen 80;
    server_name  localhost;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
   }
   ```
   The file contents were created with the command
   ```
   podman run --rm docker.io/library/nginx /bin/bash -c 'cat /etc/nginx/conf.d/default.conf | grep -v \# | sed /^[[:space:]]*$/d' > default.conf
   ```
4. Create the file _/home/test/nginx_conf_d/apache-example-com.conf_ with the contents
   ```
   server {
     listen 80;
     server_name apache.example.com;
     location / {
       proxy_pass http://apache-container:80;
     }
   }
   ```
5. Create the file _/home/test/nginx_conf_d/caddy-example-com.conf_ with the contents
   ```
   server {
     listen 80;
     server_name caddy.example.com;
     location / {
       proxy_pass http://caddy-container:80;
     }
   }
   ```
6. Create the file _/etc/systemd/system/example4.service_ with the contents
   ```
   [Unit]
   Wants=network-online.target
   After=network-online.target
   Requires=user@1000.service
   After=user@1000.service
   RequiresMountsFor=/run/user/1000/containers
   
   [Service]
   User=test
   Environment=PODMAN_SYSTEMD_UNIT=%n
   KillMode=mixed
   ExecStop=/usr/bin/podman rm -f -i --cidfile=/run/user/1000/%N.cid
   ExecStopPost=-/usr/bin/podman rm -f -i --cidfile=/run/user/1000/%N.cid
   Delegate=yes
   Type=notify
   NotifyAccess=all
   SyslogIdentifier=%N
   ExecStart=/usr/bin/podman run \
        --cidfile=/run/user/1000/%N.cid \
        --cgroups=split \
        --rm \
        --env "NGINX=3;" \
         -d \
        --network systemd-example4-net \
        --replace \
        --name systemd-%N \
        --sdnotify=conmon \
        --volume /home/test/nginx_conf_d:/etc/nginx/conf.d:Z \
        docker.io/library/nginx
   ```
   (To adjust the file for your system, replace `1000` with the UID found in step 2)
7. Create the file _/etc/systemd/system/example4.socket_ with the contents
   ```
   [Unit]
   Description=Example 4 socket

   [Socket]
   ListenStream=0.0.0.0:80

   [Install]
   WantedBy=sockets.target
   ```
8. Reload the systemd configuration
   ```
   $ sudo systemctl daemon-reload
   ```

#### set up _apache.service_ and _caddy.service_

1. Open a terminal as the user _test_
   ```
   $ sudo machinectl shell --uid test
   ```
   (It might be more convenient to create directories and files when logged in as the user)
2. Create directory
   ```
   $ mkdir -p /home/test/.config/containers/systemd
   ```
3. Create the file _/home/test/.config/containers/systemd/apache.container_ with the contents
   ```
   [Container]
   Image=docker.io/library/apache
   Network=example4-net.network
   ContainerName=apache-container
   [Install]
   WantedBy=default.target
   ```
4. Create the file _/home/test/.config/containers/systemd/caddy.container_ with the contents
   ```
   [Container]
   Image=docker.io/library/caddy
   Network=example4-net.network
   ContainerName=caddy-container
   [Install]
   WantedBy=default.target
   ```
5. Create the file _/home/test/.config/containers/systemd/example4-net.network_ with the contents
   ```
   [Network]
   Internal=true
   ```
   Optional: To give the containers access to the internet, remove the line `Internal=true`
6. Reload the systemd configuration
   ```
   $ systemctl --user daemon-reload
   ```
7. Start _apache.service_ and _caddy.service_
   ```
   $ systemctl --user start apache.service
   $ systemctl --user start caddy.service
   ```

__Side-note__: If the user _test_ is an account with no log in shell, skip step 1 and replace step 6 and 7 with
```
$ sudo systemctl --user -M test@ daemon-reload
$ sudo systemctl --user -M test@ start apache.service
$ sudo systemctl --user -M test@ start caddy.service
```

#### test the HTTP reverse proxy

1. Test the nginx HTTP reverse proxy
   ```
   $ curl -s --resolve apache.example.com:80:127.0.0.1 apache.example.com:80
   <html><body><h1>It works!</h1></body></html>
   ```
   Result: Success. The nginx reverse proxy fetched the output from the apache httpd container.
   ```
   $ curl -s --resolve caddy.example.com:80:127.0.0.1 caddy.example.com:80 | head -4
   <!DOCTYPE html>
   <html>
   <head>
       <title>Caddy works!</title>
   ```
   Result: Success. The nginx reverse proxy fetched the output from the caddy container.

#### discussion about service dependencies

systemd does not support having dependencies between _systemd system services_ and _systemd user services_.
Because of that we need to make sure that _example4-nginx.socket_ is started after

* podman has created the network _systemd-example4-net_
* podman has started _apache-container_ and _caddy-container_

A possible future modification to Example 4 could be to also run the backend web servers inside _systemd system services_ with `User=`.
Then it would be possible to configure dependencies between the services by adding `After=`, `Depends=`, `Requires=` directives.

#### references

See also the article "_How to create multidomain web applications with Podman and Nginx_" https://www.redhat.com/sysadmin/podman-nginx-multidomain-applications
It describes a similar setup but neither systemd system service with `User=` nor socket activation is used.
To be able to bind to port 80, the following command is used:
```
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```
