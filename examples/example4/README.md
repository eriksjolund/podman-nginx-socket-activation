return to [main page](../..)

# Example 4

status: experimental

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->|"for http://apache.example.com"| a3["apache httpd container"]
    a2 -->|"for http://caddy.example.com"| a4["caddy container"]
```

Containers:

| Container image | Type of service | Role | Network | Socket activation |
| --              | --              | --   | --      | --                |
| docker.io/library/nginx | systemd system service with `User=test4` | HTTP reverse proxy | [internal bridge network](example4-net.network) | :heavy_check_mark: |
| docker.io/library/httpd | systemd user service | backend web server | [internal bridge network](example4-net.network) | |
| docker.io/library/caddy | systemd user service | backend web server | [internal bridge network](example4-net.network) | |

This example is similar to [Example 3](../example3) but here the nginx container is configured
as an HTTP reverse proxy for two backend web server containers (apache httpd and caddy).
All containers are run by rootless podman, which belongs to the user _test4_.
The containers communicate over an internal bridge network that does not have internet access.

## Requirements

These instructions were tested on Fedora 39 with Podman 4.7.2.

## Install instructions

These install instructions will create the new user _test4_ and install these files:

```
/etc/systemd/system/example4.socket
/etc/systemd/system/example4.service
/home/test4/.config/containers/systemd/caddy.container
/home/test4/.config/containers/systemd/apache.container
/home/test4/.config/containers/systemd/example4-net.network
/home/test4/nginx-reverse-proxy-conf/apache-example-com.conf
/home/test4/nginx-reverse-proxy-conf/caddy-example-com.conf
/home/test4/nginx-reverse-proxy-conf/default.conf
```

and start _caddy.service_, _apache.service_ and _example4.socket_.

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
   $ user=test4
   ```
4. Run install script
   ```
   $ sudo bash ./examples/example4/install.bash ./ $user
   ```
5. Check the status of the backend containers
   ```
   $ sudo systemctl --user -M ${user}@ is-active apache.service
   active
   $ sudo systemctl --user -M ${user}@ is-active caddy.service
   active
   ```
6. Check the status of the HTTP reverse proxy socket
   ```
   $ sudo systemctl is-active example4.socket
   active
   ```
   
## Test the nginx reverse proxy

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

## Discussion about service dependencies

systemd does not support having dependencies between _systemd system services_ and _systemd user services_.
Because of that we need to make sure that _example4.service_ is started after

* podman has created the network _systemd-example4-net_
* podman has started _apache-container_ (_apache.service_) and _caddy-container_ (_caddy.service_)

A possible future modification to Example 4 could be to also run the backend web servers inside _systemd system services_ with `User=`.
Then it would be possible to configure dependencies between the services by adding `After=`, `Depends=`, `Requires=` directives.
