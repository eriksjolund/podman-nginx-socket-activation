# podman-nginx-socket-activation

This is a demo showing that it is possible to run a socket-activated nginx container with rootless Podman. See also the [Podman socket activation tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md).

1. Set the shell variable _port_ to the port number that you would like to use.
   ```
   $ port=11080
   ```
2. Build the container image, start socket
   ```
   $ bash ./socket-activation-nginx.sh $port
   ```
3. Test nginx
   ```
   $ curl -s localhost:$port | head -4
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```
