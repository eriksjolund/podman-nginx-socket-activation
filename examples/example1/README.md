return to [main page](../..)

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
   Image=docker.io/library/nginx
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
