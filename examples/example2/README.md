return to [main page](../..)

## Example 2

``` mermaid
graph TB

    a1[curl localhost:80] -.->a2[nginx container in systemd system service]

```

Set up a systemd system service _example2.service_ where rootful podman is running the container image  __docker.io/library/nginx__.
Configure _socket activation_ for TCP port 80.

The instructions are similar to Example 1.

1. Create the file _/etc/containers/systemd/example2.container_ with the contents
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
3. Create the file _/etc/systemd/system/example2.socket_ that defines the sockets that the container should use
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
   $ curl -s localhost:80 | head -4
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```
