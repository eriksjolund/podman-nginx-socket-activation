# podman-nginx-socket-activation

This demo shows how to run a socket-activated nginx container with Podman.
See also the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md).

Overview of the examples

| Example | Type of service | Port | Using quadlet | rootful/rootless podman | Comment |
| --      | --              |   -- | --      | --   | --  |
| Example 1 | systemd user service | 8080 | yes | rootless podman | |
| Example 2 | systemd system service | 80 | yes | rootful podman | |
| Example 3 | systemd system service (with `User=test`) | 80 | no | rootless podman | Status: experimental |
| Example 4 | systemd system service (with `User=test`) | 80 | no | rootless podman | Similar to Example 3 but configured to run as an HTTP reverse proxy. Status: experimental. |

> **Note**
> nginx has no official support for systemd socket activation (feature request: https://trac.nginx.org/nginx/ticket/237). These examples makes use of the fact that "_nginx includes an undocumented, internal socket-passing mechanism_" quote from https://freedesktop.org/wiki/Software/systemd/DaemonSocketActivation/

## Example 1

``` mermaid
graph TB

    a1[curl localhost:8080] -.->a2[nginx container in systemd user service]

```

Set up a systemd user service _example1.service_ for the user _test_ where rootless podman is running the container image  __docker.io/library/nginx__.
Configure _socket activation_ for TCP port 8080.

1. Log in to user _test_
2. Create directories
   ```
   $ mkdir -p $HOME/.config/systemd/user
   $ mkdir -p $HOME/.config/containers/systemd
   ```
3. Create a directory that will be bind-mounted to _/etc/nginx/conf.d_ in the container
   ```
   $ mkdir $HOME/nginx_conf_d
   ```
4. Create the file _$HOME/nginx_conf_d/default.conf_ with the file contents
   ```
   server {
    listen 8080;
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
   podman run --rm -ti docker.io/library/nginx /bin/bash -c 'cat /etc/nginx/conf.d/default.conf | grep -v \# | sed "s/listen\s\+80;/listen 8080;/g" | sed /^[[:space:]]*$/d' > default.conf
   ```
5. Create the file _$HOME/.config/containers/systemd/example1.container_ with the file contents
   ```
   [Unit]
   Requires=example1.socket
   After=example1.socket

   [Container]
   Image=localhost/myimage
   Environment=NGINX=3;
   Volume=%h/nginx_conf_d:/etc/nginx/conf.d:Z
   [Install]
   WantedBy=default.target
   ```
6. Optional step for improved security: Edit the file _$HOME/.config/containers/systemd/example1.container_
   and add this line below the line `[Container]`
   ```
   Network=none
   ```
   For details, see section [_Possibility to restrict the network in the container_](#possibility-to-restrict-the-network-in-the-container)
7. Create the file _$HOME/.config/systemd/user/example1.socket_ that defines the sockets that the container should use
   ```
   [Unit]
   Description=Example 1

   [Socket]
   ListenStream=0.0.0.0:8080

   [Install]
   WantedBy=sockets.target
   ```
8. Reload the systemd configuration
   ```
   $ systemctl --user daemon-reload
   ```
9.  Start the socket
    ```
    $ systemctl --user start example1.socket
    ```
10. Test the web server
    ```
    $ curl localhost:8080 | head -4
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    ```

## Example 2

``` mermaid
graph TB

    a1[curl localhost:80] -.->a2[nginx container in systemd system service]

```

Set up a systemd system service _example2.service_ where rootful podman is running the container image  __docker.io/library/nginx__.
Configure _socket activation_ for TCP port 80.

The instructions are similar to Example 1.

1. Create the file _/etc/containers/systemd/example2.container_ with the file contents
   ```
   [Unit]
   Requires=example2.socket
   After=example2.socket

   [Container]
   Image=docker.io/library/nginx
   Environment=NGINX=3;
   [Install]
   WantedBy=default.target
   ```
2. Optional step for improved security: Edit the file _/etc/containers/systemd/example2.container_
   and add this line below the line `[Container]`
   ```
   Network=none
   ```
   For details, see section [_Possibility to restrict the network in the container_](#possibility-to-restrict-the-network-in-the-container)
3. Create the file _/etc/systemd/system/example1.socket_ that defines the sockets that the container should use
   ```
   [Unit]
   Description=Example 2

   [Socket]
   ListenStream=0.0.0.0:80

   [Install]
   WantedBy=sockets.target
   ```
4. Reload the systemd configuration
   ```
   $ sudo systemctl daemon-reload
   ```
5. Start the socket
   ```
   $ sudo systemctl start example2.socket
   ```
6. Test the web server
   ```
   $ curl localhost:80 | head -4
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```

## Example 3

status: experimental

``` mermaid
graph TB

    a1[curl localhost:80] -.->a2[nginx container in systemd system service with directive User=]

```

Set up a systemd system service _example3.service_ that is configured to run as the user _test_ (systemd configuration `User=test`)
where rootless podman is running the container image  __docker.io/library/nginx__.
Configure _socket activation_ for TCP port 80.

The default configuration for _ip_unprivileged_port_start_ is used

```
$ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
1024
```

Unprivileged users are only able to listen on TCP port 1024 and higher.

The reason that the unprivileged _user_ is able to run a socket-activated nginx container on port 80 is that
the syscalls `socket()` and `bind()` were run by systemd manager (`systemd`) that is running as root.
The socket file descriptor is then inherited by the rootless podman process.

Side-note: There is a [Podman feature request](https://github.com/containers/podman/discussions/20573)
for adding Podman support for `User=` in systemd system services.
The feature request was migrated into a GitHub discussion.

1. Create the user _test_ if it does not yet exist.
   ```
   $ sudo useradd test
   ```
2. Check the UID of the user _test_
   ```
   $ id -u test
   1000
   ```
3. Create the file _/etc/systemd/system/example3.service_ with the file contents
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
        --replace \
        --name systemd-%N \
        --sdnotify=conmon \
        docker.io/library/nginx
   ```
   (To adjust the file for your system, replace `1000` with the UID found in step 2)
4. Optional step for improved security: Edit the file _/etc/systemd/system/example3.service_
   and add the option `--network none` to the `podman run` command.
   For details, see section [_Possibility to restrict the network in the container_](#possibility-to-restrict-the-network-in-the-container)
5. Create the file _/etc/systemd/system/example3.socket_ with the file contents
   ```
   [Unit]
   Description=Example 3 socket

   [Socket]
   ListenStream=0.0.0.0:80

   [Install]
   WantedBy=sockets.target
   ```
6. Reload the systemd configuration
   ```
   $ sudo systemctl daemon-reload
   ```
7. Start the socket
   ```
   $ sudo systemctl start example3.socket
   ```
8. Test the web server
   ```
   $ curl localhost:80 | head -4
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```

## Example 4

status: experimental

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->|"for http://apache.example.com"| a3["apache httpd container"]
    a2 -->|"for http://caddy.example.com"| a4["caddy container"]
```

This example is similar to Example 3 but where the nginx container is configured to act as a HTTP reverse proxy for two
web server containers (apache httpd and caddy) that are running in systemd user services. All containers are run by rootless podman by the user _test_.
The containers communicate over an internal bridge network that has no internet access.

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
4. Create the file _/home/test/nginx_conf_d/default.conf_ with the file contents
   ```
   server {
    listen 8080;
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
   podman run --rm docker.io/library/nginx /bin/bash -c 'cat /etc/nginx/conf.d/default.conf | grep -v \# | sed "s/listen\s\+80;/listen 8080;/g" | sed /^[[:space:]]*$/d' > default.conf
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
6. Create the file _/etc/systemd/system/example4.service_ with the file contents
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
7. Create the file _/etc/systemd/system/example4.socket_ with the file contents
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

systemd does not support having dependencies between _systemd system services_ and _systemd user services_.
Because of that we need to make sure that _example4-nginx.socket_ is started after

* podman has created the network _systemd-example4-net_
* podman has started _apache-container_ and _caddy-container_

See also the article "_How to create multidomain web applications with Podman and Nginx_" https://www.redhat.com/sysadmin/podman-nginx-multidomain-applications

## Advantages of using rootless Podman with socket activation

### Native network performance over the socket-activated socket
Communication over the socket-activated socket does not pass through slirp4netns so it has the same performance characteristics as the normal network on the host.

See the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md#native-network-performance-over-the-socket-activated-socket).

### Possibility to restrict the network in the container

The option `podman run` option `--network=none` enhances security.

``` diff
--- nginx.service	2022-08-27 10:46:14.586561964 +0200
+++ nginx.service.new	2022-08-27 10:50:35.698301637 +0200
@@ -15,6 +15,7 @@
 TimeoutStopSec=70
 ExecStartPre=/bin/rm -f %t/%n.ctr-id
 ExecStart=/usr/bin/podman run \
+	--network=none \
 	--cidfile=%t/%n.ctr-id \
 	--cgroups=no-conmon \
 	--rm \
```

See the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md#disabling-the-network-with---networknone).

See the blog post [_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)

### Possibility to restrict the network in the container, Podman and OCI runtime

The systemd configuration `RestrictAddressFamilies=AF_UNIX AF_NETLINK` enhances security. 
To try it out, modify the file _~/.config/systemd/user/nginx.service_ according to

``` diff
--- nginx.service	2022-08-27 10:46:14.586561964 +0200
+++ nginx.service.new	2022-08-27 10:58:06.625475911 +0200
@@ -7,14 +7,20 @@
 Documentation=man:podman-generate-systemd(1)
 Wants=network-online.target
 After=network-online.target
+Requires=podman-usernamespace.service
+After=podman-usernamespace.service
 RequiresMountsFor=%t/containers
 
 [Service]
+RestrictAddressFamilies=AF_UNIX AF_NETLINK
+NoNewPrivileges=yes
 Environment=PODMAN_SYSTEMD_UNIT=%n
 Restart=on-failure
 TimeoutStopSec=70
 ExecStartPre=/bin/rm -f %t/%n.ctr-id
 ExecStart=/usr/bin/podman run \
+	--network=none \
+	--pull=never \
 	--cidfile=%t/%n.ctr-id \
 	--cgroups=no-conmon \
 	--rm \
```
and add the file _~/.config/systemd/user/podman-usernamespace.service_ with this contents

```
[Unit]
Description=podman-usernamespace.service

[Service]
Type=oneshot
Restart=on-failure
TimeoutStopSec=70
ExecStart=/usr/bin/podman unshare /bin/true
RemainAfterExit=yes
```

See the blog post [_How to restrict network access in Podman with systemd_](https://www.redhat.com/sysadmin/podman-systemd-limit-access)

### The source IP address is preserved

The rootlesskit port forwarding backend for slirp4netns does not preserve source IP. 
This is not a problem when using socket-activated sockets. See Podman GitHub [discussion](https://github.com/containers/podman/discussions/10472).

### Podman installation size can be reduced

The Podman network tools are not needed when __--network=host__  or __--network=none__
is used (see GitHub [issue comment](https://github.com/containers/podman/discussions/16493#discussioncomment-4140832)).
In other words, the total amount of executables and libraries that are needed by Podman is reduced
when you run the nginx container with _socket activation_ and __--network=none__.
