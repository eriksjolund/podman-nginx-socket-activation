
return to [main page](../..)

# Example 5

status: experimental

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->|"for http&colon;//caddy.example.com"| a4["caddy container"]
```

Containers:

| Container image | Type of service | Role | Network | Socket activation |
| --              | --              | --   | --      | --                |
| docker.io/library/nginx | systemd system service with `User=test5` | HTTP reverse proxy | `--network=none` | :heavy_check_mark: |
| docker.io/library/caddy | systemd user service | backend web server | `--network=none` | |

This example is similar to [Example 4](../example4) but here the containers are configured
to use `--network=none`. The containers communicate over a Unix socket instead of using
an internal bridge network. The containers do not have permissions to connect to the internet.
This is improves security. In case an intruder would compromise any of these containers,
the intruder would not be able to use the compromised container to attack other computers
on the internet if we ignore the possibility of local kernel exploits.

All containers are run by rootless podman, which belongs to the user _test5_.

## Requirements

These instructions were tested on Fedora 39 with Podman 4.7.2.

## Install instructions

These install instructions will create the new user _test5_ and install these files:

```
/etc/systemd/system/example5.socket
/etc/systemd/system/example5.service
/home/test5/.config/containers/systemd/caddy.container
/home/test5/nginx-reverse-proxy-conf/caddy-example-com.conf
/home/test5/nginx-reverse-proxy-conf/default.conf
/home/test5/Caddyfile
```

and start _caddy.service_ and _example5.socket_.

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
   $ user=test5
   ```
4. Run install script
   ```
   $ sudo bash ./examples/example5/install.bash ./ $user
   ```
5. Check the status of the backend container
   ```
   $ sudo systemctl --user -M ${user}@ is-active caddy.service
   active
   ```
6. Check the status of the HTTP reverse proxy socket
   ```
   $ sudo systemctl is-active example5.socket
   active
   ```

## Test the nginx reverse proxy

1. Test the nginx HTTP reverse proxy
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
Because of that we need to make sure that _example5.service_ is started after

* podman has started the _caddy-container_

A possible future modification to Example 5 could be to also run the backend web servers inside _systemd system services_ with `User=`.
Then it would be possible to configure dependencies between the services by adding `After=`, `Depends=`, `Requires=` directives.
