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
> The _Containerfile_ builds nginx with many features disabled. Hopefully this demo could be modified to instead use an official nginx container image.

> **Note**
> nginx has no official support for systemd socket activation (feature request: https://trac.nginx.org/nginx/ticket/237). This demo makes use of the fact that "_nginx includes an undocumented, internal socket-passing mechanism_" quote from https://freedesktop.org/wiki/Software/systemd/DaemonSocketActivation/

# Advantages of using rootless Podman with socket activation

## Native network performance over the socket-activated socket
Communication over the socket-activated socket does not pass through slirp4netns so it has the same performance characteristics as the normal network on the host.

See the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md#native-network-performance-over-the-socket-activated-socket)

## Possibility to restrict the network in the container

The option `podman run` option `--network=none` enhances security. See the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md#disabling-the-network-with---networknone)

See the blog post [_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)

## Possibility to restrict the network in the container, Podman and OCI runtime

The systemd configuration `RestrictAddressFamilies=AF_UNIX AF_NETLINK` enhances security. 

See the blog post [_How to restrict network access in Podman with systemd_](https://www.redhat.com/sysadmin/podman-systemd-limit-access)

## The source IP address is preserved

The rootlesskit port forwarding backend for slirp4netns does not preserve source IP. 
This is not a problem when using socket-activated sockets. See [Podman GitHub discussion](https://github.com/containers/podman/discussions/10472).

