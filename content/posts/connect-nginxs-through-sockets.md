---
title: "Connect two NGINX's through UNIX sockets"
date: 2021-04-30T18:20:04-05:00
draft: false
---

## Introduction

Normally, you would use TCP/IP to connect an instance of NGINX with some other service (another NGINX or a web server listening through some IP address). This is powerful and pretty flexible, but sometimes you want something more lightweight and don't need to use the network stack (because you are connecting two services running under the same machine).

This is were UDS (UNIX Domain Sockets) can serve as an inter-process communication mechanism between your two services, allowing you to bypass the overhead of the TCP/IP protocol.

Why would you want to have two instances of NGINX running in the same machine anyway? Well, suppose you have an instance as an entry-point where you load the SSL certificates and proxy the requests to another NGINX serving a _react_ or _PHP_ application. Or because you can't refactor your architecture and need to put an additional system somewhere (no shaming).

## Wishful Thinking

Let's use docker (with compose) to run our services in an easy way:

```text
          +--------+           +--------+
   HTTP   |        |    UDS    |        |
+---------+ nginx1 +-----------+ nginx2 |
          |        |           |        |
          +--------+           +--------+
```

`nginx1` is listening on a TCP/IP address like `127.0.0.1:80` and `nginx2` is listening on a UNIX socket like `/tmp/nginx.sock`, we want to make an HTTP request to `nginx1` who should pass it to `nginx2` through the socket, `nginx2` will return a response in the form of an HTML document.

## Implementation

Let's start with this folder structure:

```sh
.
├── docker-compose.yml
└── templates
    ├── nginx1
    │   └── default.conf.template
    └── nginx2
        └── default.conf.template
```

Where, `docker-compose.yml`:

```yml
version: '3'

volumes:
  data:

services:
  nginx1:
    image: nginx
    ports:
      - '127.0.0.1:80:80'
    volumes:
      - type: volume
        source: data
        target: /tmp
      - type: bind
        source: ./templates/nginx1
        target: /etc/nginx/templates

  nginx2:
    image: nginx
    volumes:
      - type: volume
        source: data
        target: /tmp
      - type: bind
        source: ./templates/nginx2
        target: /etc/nginx/templates
```

Hopefully, this is self-explanatory. We're declaring two services based on [nginx](https://hub.docker.com/_/nginx) (`nginx1` and `nginx2`), `nginx1` is listening in the host machine on `127.0.0.1:80` and there is one shared volume named `data` between the two containers. Also bindings to allow NGINX to configure themselves through templates.

The file `./templates/nginx1/default.conf.template`:

```nginx
server {
  listen 80;

  location / {
    proxy_pass http://unix:/tmp/nginx.sock;
  }
}
```

The configuration for `nginx1` declares a server directive that listen on port 80 and redirect the incoming request through the UNIX socket called `/tmp/nginx.sock`.

The file `./templates/nginx2/default.conf.template`:

```nginx
server {
  listen unix:/tmp/nginx.sock;

  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
  }
}
```

The configuration for `nginx2` creates the UNIX socket on `/tmp/nginx.sock`, listens on it and serves the default `index.html` file in `/usr/share/nginx/html`.

A little disadvantage when using UNIX sockets is that the two NGINX's needs to share the socket through the file-system, thats what the volume `data` is for.

We're ready to start the services and test them:

```sh
$ docker-compose up

Starting nginx2_1 ... done
Starting nginx1_1 ... done
Attaching to nginx2_1, nginx1_1
nginx1_1  | /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
nginx1_1  | /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
nginx1_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
nginx2_1  | /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
nginx2_1  | /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
nginx2_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
nginx1_1  | 10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
nginx2_1  | 10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
nginx1_1  | 10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf differs from the packaged version
nginx2_1  | 10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf differs from the packaged version
nginx2_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
nginx1_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
nginx2_1  | 20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template to /etc/nginx/conf.d/default.conf
nginx1_1  | 20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template to /etc/nginx/conf.d/default.conf
nginx2_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
nginx1_1  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
nginx2_1  | /docker-entrypoint.sh: Configuration complete; ready for start up
nginx1_1  | /docker-entrypoint.sh: Configuration complete; ready for start up
```

Our containers are ready. Fire a request to `localhost` in your browser (or with `curl`):

```sh
$ curl localhost

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

Nice! We got the default NGINX welcome document.

We can see the logs from `stdout` in the `docker-compose up` command:

```sh
nginx1_1  | 172.21.0.1 - - [30/Apr/2021:23:13:37 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.76.1" "-"
nginx2_1  | unix: - - [30/Apr/2021:23:13:37 +0000] "GET / HTTP/1.0" 200 612 "-" "curl/7.76.1" "-"
```

`nginx1` receive the request from an IP address (`172.21.0.1`) and `nginx2` from a UNIX connection (`unix`).

The code can be found in [davidsierradz/connect-nginxs-through-sockets](https://github.com/davidsierradz/connect-nginxs-through-sockets).

## References

- [NGINX proxy_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)
- [NGINX listen](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen)
