return to [main page](../..)

# Example 6

status: experimental

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->|"for http://nginx.example.com"| a4["nginx backend container"]
```

Containers:

| Container image | Type of service | Role | Network | Socket activation | SELinux |
| --              | --              | --   | --      | --                | --      |
| docker.io/library/nginx | systemd system service with `User=test6` | HTTP reverse proxy | `--network=none` | :heavy_check_mark: | disabled |
| docker.io/library/nginx | systemd system service with `User=test6` | backend web server | `--network=none` | :heavy_check_mark: | enabled |

> [!WARNING]  
> The container running the proxy is currently configured with`--security-opt label=disable` which means that SELinux is disabled for that container.

This example is similar to [Example 5](../example5) but here the backend web server is
started with _socket activation_ from a _systemd system service_ with `User=test6`.
No systemd user services are used.
All containers are run by rootless podman, which belongs to the user _test_.

## Requirements

These instructions were tested on Fedora 39 with Podman 4.7.2.

## Install instructions

These install instructions will create the new user _test6_ and install these files:

```
/etc/systemd/system/example6-proxy.socket
/etc/systemd/system/example6-proxy.service
/etc/systemd/system/example6-backend.socket
/etc/systemd/system/example6-backend.service

/home/test6/nginx-reverse-proxy-conf/nginx-example-com.conf
/home/test6/nginx-reverse-proxy-conf/default.conf
/run/user/1006/backend-socket
```
(Here assuming `1006` is the UID of _test6_).
The install instructions will also start _example6-proxy.socket_ and _example6-backend.socket_.

1. Clone this GitHub repo
   ```
   $ git clone URL
   ```
2. Change directory
   ```
   $ cd podman-nginx-socket-activation
   ```
3. Choose a username that will be created and used for the test
   ```
   $ user=test6
   ```
4. Run install script
   ```
   $ sudo bash ./examples/example6/install.bash ./ $user
   ```
5. Check the status of the backend socket
   ```
   $ sudo systemctl is-active example6-backend.socket
   active
   ```
6. Check the status of the HTTP reverse proxy socket
   ```
   $ sudo systemctl is-active example6-proxy.socket
   active
   ```

## Test the nginx reverse proxy

1. Test the nginx HTTP reverse proxy
   ```
   $ curl -s --resolve nginx.example.com:80:127.0.0.1 nginx.example.com:80 | head -4
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
   ```
   Result: Success. The nginx reverse proxy fetched the output from the nginx backend.

## Discussion about SELinux

To get it to work, `--security-opt label=disable` was given to the _podman run_ command in _example6-proxy.service_.
