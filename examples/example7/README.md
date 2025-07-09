return to [main page](../..)

# Example 7

status: Beta.

Example 7 was written in July 2025. I'll change to status `stable` in a few months unless
there are github issues with reports of problems.

``` mermaid
graph TB

    a1[curl] -.->a2[nginx container reverse proxy]
    a2 -->a3["whoami1 container"]
    a2 -->a4["whoami2 container"]
```

Containers:

| Container image | Type of service | Role | Network | Socket activation |
| --              | --              | --   | --      | --                |
| docker.io/library/nginx | systemd user service | HTTP reverse proxy | [internal bridge network](example4-net.network) | :heavy_check_mark: |
| docker.io/traefik/whoami | systemd user service | backend web server | [internal bridge network](example4-net.network) | |
| docker.io/traefik/whoami | systemd user service | backend web server | [internal bridge network](example4-net.network) | |

This example is similar to [Example 4](../example4) but here the nginx container is configured
as an HTTP reverse proxy for two backend web server containers (whoami1 and whoami2).
All containers are run by rootless podman with quadlets.
A self signed certificate created with `openssl` is used to provide https.

## Requirements

* podman 4.4.0 or later (needed for using [quadlets](https://www.redhat.com/en/blog/quadlet-podman)). Not strictly needed for this example but podman 5.3.0 or later is recommended because then `AddHost=postgres.example.com:host-gateway`, `host.containers.internal` or `host.docker.internal` could be used to let a container on the custom network connect to a service that is listening on the host's main network interface. For details, see [Outbound TCP/UDP connections to the host's main network interface (e.g eth0)](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#outbound-tcpudp-connections-to-the-hosts-main-network-interface-eg-eth0)

* `ip_unprivileged_port_start` ≤ 80

   Verify that [`ip_unprivileged_port_start`](https://github.com/eriksjolund/podman-networking-docs#configure-ip_unprivileged_port_start) is less than or equal to 80
   ```
   $ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
   80
   ```

These instructions were tested on Fedora 42 with Podman 5.5.1.

## Install instructions

1. Go to home directory
   ```
   cd $HOME
   ```
2. Clone this GitHub repo
   ```
   $ git clone URL
   ```
3. Change directory
   ```
   $ cd podman-nginx-socket-activation/examples/example7
   ```
4. Run install script
   ```
   $ bash ./install.bash
   ```
5. Check the status of the backend containers
   ```
   $ systemctl --user is-active whoami1.service
   active
   $ systemctl --user is-active whoami2.service
   active
   ```
6. Check the status of the nginx socket
   ```
   $ systemctl --user is-active nginx.socket
   active
   ```
   
## Test nginx reverse proxy

1. Test the nginx HTTP reverse proxy by download https://whoami1.example.com
   ```
   curl --resolve whoami1.example.com:443:127.0.0.1 --cacert ~/ca.crt https://whoami1.example.com
   ```
   The following output is printed
   ```
   Hostname: 329327a50b00
   IP: 127.0.0.1
   IP: ::1
   IP: 10.89.0.2
   IP: fe80::bcf3:7eff:fe98:c52f
   RemoteAddr: 10.89.0.4:59084
   GET / HTTP/1.1
   Host: whoami1.example.com
   User-Agent: curl/8.11.1
   Accept: */*
   Connection: close
   X-Forwarded-For: ::ffff:127.0.0.1
   X-Forwarded-Proto: https
   X-Real-Ip: ::ffff:127.0.0.1
   ```
2. Test that HTTP redirect works for the URL http://whoami1.example.com
   ```
   curl --resolve whoami1.example.com:80:127.0.0.1 -sD - http://whoami1.example.com -o /dev/null
   ```
   The following output is printed
   ```   
   HTTP/1.1 301 Moved Permanently
   Server: nginx/1.29.0
   Date: Wed, 09 Jul 2025 13:12:12 GMT
   Content-Type: text/html
   Content-Length: 169
   Connection: keep-alive
   Location: https://whoami1.example.com/
   ```

## Using `Internal=true`

The containers _whoami1_ and _whoami2_ do not need to create outbound connections to the internet.

To deny access to the internet from the custom network, append append the line

```
Internal=true
```

to [example7.network](example7.network).

This improves security. For details, see the blog post
[_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)

Socket activation is not affected by `Internal=true`. In other words, the nginx container get incoming connections
from the internet even when the custom network is configured with `Internal=true`.
