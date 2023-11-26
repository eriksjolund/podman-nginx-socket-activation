# podman-nginx-socket-activation

This demo shows how to run a socket-activated nginx container with Podman.
See also the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md).

Overview of the examples

| Example | Type of service | Port | Using quadlet | rootful/rootless podman | Comment |
| --      | --              |   -- | --      | --   | --  |
| [Example 1](examples/example1) | systemd user service | 8080 | yes | rootless podman | Only unprivileged port numbers can be used |
| [Example 2](examples/example2) | systemd system service | 80 | yes | rootful podman | |
| [Example 3](examples/example3) | systemd system service (with `User=test3`) | 80 | no | rootless podman | Status: experimental |
| [Example 4](examples/example4) | systemd system service (with `User=test4`) | 80 | no | rootless podman | Similar to Example 3 but configured to run as an HTTP reverse proxy. Status: experimental. |
| [Example 5](examples/example5) | systemd system service (with `User=test5`) | 80 | no | rootless podman | Similar to Example 4 but the containers use `--network=none` and communicate over a Unix socket. Status: experimental. |
| [Example 6](examples/example6) | systemd system service (with `User=test6`) | 80 | no | rootless podman | Similar to Example 5 but the backend web server is started with _socket activation_ in a _systemd system service_ with `User=test6`. Status: experimental. |

> **Note**
> nginx has no official support for systemd socket activation (feature request: https://trac.nginx.org/nginx/ticket/237). These examples makes use of the fact that "_nginx includes an undocumented, internal socket-passing mechanism_" quote from https://freedesktop.org/wiki/Software/systemd/DaemonSocketActivation/

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
and create the file _~/.config/systemd/user/podman-usernamespace.service_ with this contents

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

The Podman network tools are not needed when using __--network=host__  or __--network=none__
(see GitHub [issue comment](https://github.com/containers/podman/discussions/16493#discussioncomment-4140832)).
In other words, the total amount of executables and libraries that are needed by Podman is reduced
when you run the nginx container with _socket activation_ and __--network=none__.

### References

__Reference 1:__

The github project [PhracturedBlue/podman-socket-activated-services](https://github.com/PhracturedBlue/podman-socket-activated-services) contains an [example](https://github.com/PhracturedBlue/podman-socket-activated-services/tree/main/reverse-proxy) of a
customized socket-activated nginx container that watches a directory for Unix sockets that backend applications have created. In case of socket-activated backend application it would have
been systemd that created the Unix sockets. The __podman run__ option `--network none` is used.

__Reference 2:__

The article "_How to create multidomain web applications with Podman and Nginx_" https://www.redhat.com/sysadmin/podman-nginx-multidomain-applications
describes running nginx as a reverse proxy with rootless podman.
In the article rootless podman is given the privilege to listen on port 80 with the command
```
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```
Socket activation is not used in the article.
