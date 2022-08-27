# podman-nginx-socket-activation

This is a demo showing that it is possible to run a socket-activated nginx container with rootless Podman. See also the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md).

1. Set the shell variable _port_ to the port number that you would like to use.
   ```
   $ port=11080
   ```
2. Build the container image and start the socket
   ```
   $ bash ./socket-activation-nginx.sh $port
   ```
3. Test the nginx systemd user service
   ```
   $ curl -s localhost:$port | head -4
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```

> **Note**
> The _Containerfile_ builds nginx with many features disabled. Hopefully this demo could be modified to instead use an official nginx container image (see https://github.com/eriksjolund/podman-nginx-socket-activation/issues/1).

> **Note**
> nginx has no official support for systemd socket activation (feature request: https://trac.nginx.org/nginx/ticket/237). This demo makes use of the fact that "_nginx includes an undocumented, internal socket-passing mechanism_" quote from https://freedesktop.org/wiki/Software/systemd/DaemonSocketActivation/

## Advantages of using rootless Podman with socket activation

### Native network performance over the socket-activated socket
Communication over the socket-activated socket does not pass through slirp4netns so it has the same performance characteristics as the normal network on the host.

See the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md#native-network-performance-over-the-socket-activated-socket).

### Possibility to restrict the network in the container

The option `podman run` option `--network=none` enhances security.

```
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
