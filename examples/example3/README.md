return to [main page](../..)

## Example 3

status: experimental

``` mermaid
graph TB

    a1[curl localhost:80] -.->a2[nginx container in systemd system service with directive User=]

```

Set up a systemd system service _example3.service_ that is configured to run as the user _test3_ (systemd configuration `User=test3`)
where rootless podman is running the container image  __docker.io/library/nginx__.
Configure _socket activation_ for TCP port 80.

The default configuration for _ip_unprivileged_port_start_ is used

```
$ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
1024
```

Unprivileged users can only listen on TCP port 1024 and above.

The reason the unprivileged user _test3_ is able to run a socket-activated nginx container on port 80 is that
the syscalls `socket()` and `bind()` were run by the systemd system manager (`systemd`).
The socket file descriptor is then inherited by the rootless podman process.

Side note: There is a [Podman feature request](https://github.com/containers/podman/discussions/20573)
for adding Podman support for `User=` in systemd system services.
The feature request was moved into a GitHub discussion.

1. Create the user _test3_ if it does not yet exist.
   ```
   $ sudo useradd test3
   ```
2. Check the UID of the user _test3_
   ```
   $ id -u test3
   1000
   ```
3. Create the file _/etc/systemd/system/example3.service_ with the contents
   ```
   [Unit]
   Wants=network-online.target
   After=network-online.target
   Requires=user@1000.service
   After=user@1000.service
   RequiresMountsFor=/run/user/1000/containers
   
   [Service]
   User=test3
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
5. Create the file _/etc/systemd/system/example3.socket_ with the contents
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
