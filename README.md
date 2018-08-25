debian-apache-php
=================

Container with apache and php.

Features
========
- Select between php fpm or apache module.
- Choose php version 5 or 7.2.
- Global url `/_heathz` which returns 200 using apache and php. Usefull for health check.
- Global alias `/_infoz` to /usr/local/info.php.
- Use of include `/etc/supervisor/conf.d/*.conf` to add custom services.
- PHP-FPM5 with `proxy_fcgi`.
- Use SSL certs from file (certificate chain is optional).
- Configure newrelic APM with `NEWRELIC_LICENSE`. See below compose examples for full deployment.
- Docker healthcheck apache-php full-route.
- Use `/etc/php/5.6/fpm/pool.d/include.d/*.conf` to include extra config for the php-fpm pool.
- Use `/container-init.d/*.sh` for initial start container scripts.
- Included scripts:
   - `wp-cli`: wordpress configuration scripting.
   - `composer.phar`: php composer.

Options
-------
Options works with enviornment variables with jinja templates and docker entrypoint.

 - On build:
To enable this options on build add after envvars in Dockerfile: `RUN /root/entrypoint.sh true`

### Explained options: ###

 - __TZ__: Use defined timezone (i.e.: `Europe/Madrid`) in this container.
 - __MONITOR_PASSWD__: Define a password for `PHPFPM_STATUS_PATH` (defaults to /phpfpm-status), `APACHE_STATUSPATH` (defaults to /server-status) and `INFO_PATH` (defaults to `/_infoz`). Example:
    - Apache: `/server-status?password=MONITOR_PASSWD` the password must be a query parameter defined as `password`.
    - PHP-FPM: `/phpfpm-status?password=MONITOR_PASSWD` the password must be a query parameter defined as `password`.
    - `/_infoz`: `_infoz` alias will require the form `/_infoz?password=<PASSWD>`.
 - __PHP_ENABLE_MOD__: `false` will use php-fpm and `proxy_fcgi`. `true` will use `php_mod` for apache.
 - __PHP_VERSION__: `5` would use PHP 5.7, `7` will use 7.2.
 - __PHP_DEBUG__: Use TRACE|PROFILE|REMOTE to enable and use xdebug in different formats. Look for xdebug options section.
 - __PHP_SESS_MEMCACHED_HOST__ (formerly __PHP_MEMCACHED_HOST__): If defined, enables memcached sessions backend and use defined as host. Port is always 11211.
 - __PHP_SESS_REDIS_HOST__): If defined, enables redis sessions as php sessions backend. Port is always 6379.
 - __PHP_MAX_EXEC_TIME__: Defaults to 60. Used by php `max_execution_time` and apache2 server `FcgidIOTimeoute`. Setted equal because those two values must be: `apache2(FcgidIOTimeoute) >= php(max_execution_time)`.
 - __APACHE_ENABLE_BADBOTS__: Enables bad bots/referrers. Follow [`apache-ultimate-bad-bot-blocker`](https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/) for more information and custom adds.
 - __APACHE_ENABLE_HSTS__: HSTS header. Read more on [`HSTS`](https://es.wikipedia.org/wiki/HTTP_Strict_Transport_Security). MAXAGE is 3600 by default, and `APACHE_HSTS_MAXAGE` may be set to 31536000 on production.
 - __APACHE_ENABLE_CSP__: Content-Security-Policy header. Read more on [`CSP`](https://content-security-policy.com).
 - __APACHE_ENABLE_CORS__: Add `Access-Control-Allow-Origin` Header.
 - __APACHE_VH_ALIAS__: Use Alias. Alias path (i.e.: `/example`) which apache should rebase to `APACHE_DOCUMENTROOT`. Multiple paths must be defined with "`:`" separator.
 - __APACHE_REMOTEIP_ENABLE__: Enable reverse proxy add forward filter. Useful for apache behind LoadBalancer or reverse proxy. (Default: `true`)
 - __APACHE_REMOTEIP_RANGE__: Space separated list of custom reverse proxy ips. Example value: "123.44.0.0/24 54.34.1.0/24". Ranges 127.2.0.0/8, ::1, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 and 100.64.0.0/10 are always enabled. More info: [github.com/gnif/mod_rpaf](https://github.com/gnif/mod_rpaf).
 - __APACHE_SETENV__: List of environment variables to pass to apache (and php). command line use with a multistring variable. Use in `docker-compose.yml` with:
     ```environment:
           - APACHE_SETENV=
                key1:value1,
                KeyN:valueM
     ```
     or
     ```environment:
         APACHE_SETENV:|
           key1: value1
           keyN: valueM
     ```
   Notice `,` for split every envvar and `:` to split key:value.
 - __APACHE_LOG_PATH__: defaults to `stdout`, option to change all apache CustomLog path.
 - __APACHE_ERRORLOG_PATH__: default to `sderr`, option to change all apache ErrorLog path.
 - __APACHE_CORS_ORIGIN__: Optional sources on `Access-Control-Allow-Origin` (default: `*`).
 - __APACHE_ENABLE_EXPIRES__: Set some expires headers globally by default. Some more options follows.
 - __APACHE_HTTP_FORWARDED_PROTO__: (bool) Add https forwarded if original request was https. Use it when there is a loadbalancer which does the ssl negotiation.
 - __FORCE_SSL__: Forces a redirect to https when the incoming request is not in https. Apache-side config.
 - __PHP_ENABLE_NEWRELIC__: Use newrelic agent. Needs the daemon docker, exported unix socket and __NEWRELIC_APPNAME__ and __NEWRELIC_LICENSE__ defined.
 - __PHP_DISPLAY_ERRORS__: Set to `true` to enable errors debug inline.

### Security: ###
There are some security related variables. 

 - __SECURITY_BY_DEFAULT__: Global option to enable some basic security enhancements:
    - Adds bad bots/referrers in apache.
    - Disables bad php functions with php `disable_functions`. Defaults to: `exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source` or uses `PHP_DISABLE_FUNCTIONS_LIST` to populate the list.
 - __PHP_SECURITY__: Adds security enhancements. Look for php `SECURITY_BY_DEFAULT` defitions.
 - __DISABLE_WP_XMLRPC__: Disable XMLRPC to wordpress on apache. Enabled by default.

### Xdebug ###
With the __PHP_DEBUG__ envvar we can select to enable xdebug in three modes:
 - `TRACE`: Will dump stack traces on php exceptions or fatal errors. Throws the stack in HTML.
 - `PROFILE`: Will dump traces and profiling in `/tmp/php-xdebug-traces/` and `/tmp/php-xdebug-profiles/`. Export `/tmp/` as a volume to get them.
 - `REMOTE`: Access xdebug from a remote debugger. Use `PHP_DEBUG_REMOTE_PORT` and `PHP_DEBUG_REMOTE_HOST` env vars to define the remote IDE to connect to. Also `PHP_DEBUG_REMOTE_KEY` used for validate connection.

Commands
--------
 - `php_generic_report` is a bash script to check code quality. It uses:
   - phplint for checking syntax quality.
   - [phpcs](https://github.com/squizlabs/PHP_CodeSniffer) to create a report of generic php code.
   - [phploc] to create a report of code lines.
   - [phpmd] PHP mess detector: checks for php problems.
   - [phpmetrics] Generates metrics of code complexity.
  It generates a file on `/tmp/php_generic_report.xml`

 - `wrk_wrapper` is a wrapper to start services and execute `wrk` with passed arguments. Use `$WRK_FILENAME` to define the output (stdout) filename. It's relative output path is `/tmp/perf-reports`. Example:
   `docker run --rm -v /srv/perf-reports:/tmp/perf-reports registry.gitlab.com/joanayma/debian-apache-php:v4 wrk_wrapper -t1 -c10 -d10s`

 - `go-cron_wrapper` Execute crons from `/etc/crons` using [go-crond](https://github.com/webdevops/go-crond/releases/download/0.6.1/go-crond-64-linux). Use `/root/cron/` and `/var/www/cron/` for userless (without user in it) crons.
 - `cmd_wrapper` is a wrapper to start services controlled by supervisord and execute anything command that follows up.

## Apache Badbots ##
Link for reference: (https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/)

The files to rewrite with volumes or Docker COPY for custom rules are:
```
/etc/apache2/custom.d/blacklist-user-agents.conf \
/etc/apache2/custom.d/whitelist-domains.conf \
/etc/apache2/custom.d/bad-referrer-words.conf \
/etc/apache2/custom.d/whitelist-ips.conf \
```

To whitelist a badbot:
 - Find the string: 
   `grep "User-agent" /etc/apache2/custom.d/*`
 - Copy the string to `/etc/apache2/custom.d/blacklist-user-agents.conf`. Put it outside the container as a exported volume, use docker config, or Dockerfile COPY.
 - Substitute `bad_bot` to `good_bot` at the string end.

## Using apache image with another php-fpm image backend ##

In some cases we need another php-fpm backend, for example php 5.3. We need to use tcp network and disable "embeded" php-fpm.

To do this, define a docker compose with:

```
version: 2
services:
[...]
  frontend-apache:
    container_name: frontend
    image: registry.gitlab.com/joanayma/debian-apache-php:latest
    environment:
      - PHPFPM_AUTOSTART false
      - PHPFPM_ENABLE_TCP true
      # Optionally define tcp port
      - PHPFPM_TCP_PORT 9000
    volunes

  backend-php:
    container_name: backend-php
    image: registry.gitlab.com/joanayma/external-backend:latest
    network: service: frontend-apache
    volumes_from:
      # not only httpdocs volume but also internal /usr/local/ volume from debian-apache-php image.
      - frontend
```

## Enable newrelic ##

We need the daemon container and expose the socket to the real (php) application. Then define __NEWRELIC_APPNAME__ and __NEWRELIC_LICENSE__ to configure the agent.

Do not quote the envvars.

In a docker-compose, we define this:

```
version: 2
services:
[...]
  frontend:
    container_name: apache-php
    image: registry.gitlab.com/joanayma/debian-apache-php:v4
    environment:
      - PHP_ENABLE_NEWRELIC true
      - NEWRELIC_LICENSE license-number
      - NEWRELIC_APPNAME some name
    volumes:
      - /srv/www.example.com/httpdocs:/var/www/httpdocs
    volumes_from:
      - newrelic-daemon

  newrelic-daemon:
    image: referup/newrelic-daemon
    container_name: newrelic-daemon
    hostname: ${HOSTNAME}
    volumes:
      - /tmp/newrelic/
    tty: true
    restart: always

```

#### Full options and defaults follows: ####

```
# Entrypoints options:
 DO_JINJA true
 DO_INIT true (/container-init.d/ scripts)
# Global stack options
 KEEPALIVE_MAX_REQUESTS 
 KEEPALIVE_TIMEOUT 
 NEWRELIC_APPNAME 
 NEWRELIC_LICENSE 
 HEALTHCHECK_PATH|default("/_healthz")
 INFO_PATH|default("/_infoz")
# Apache options
 APACHE_CORS_ORIGIN|default("*")
 APACHE_CSP_HEADER 
 APACHE_DOCUMENTROOT 
 APACHE_DOCUMENTROOT}
 APACHE_ENABLE_BADBOTS 
 APACHE_ENABLE_CORS 
 APACHE_ENABLE_CSP 
 APACHE_ENABLE_EXPIRES 
 APACHE_ENABLE_HSTS 
 APACHE_ENABLE_SSL 
 APACHE_ERRORLOG_PATH|default("/dev/stderr")
 APACHE_EXPIRES_DEFAULT_TIME 
 APACHE_EXPIRES_STATICFILES_REGEX 
 APACHE_EXPIRES_STATICFILES_TIME 
 APACHE_HSTS_MAXAGE 
 APACHE_HTTP_FORWARDED_PROTO 
 APACHE_KEEPALIVE 
 APACHE_LOG_PATH|default("/dev/stdout")
 APACHE_MAX_CONNECTIONS_PER_CHILD 
 APACHE_MAX_REQUEST_WORKERS 
 APACHE_MAX_SPARE_THREADS 
 APACHE_MIN_SPARE_THREADS 
 APACHE_REMOTEIP_ENABLE 
 APACHE_REMOTEIP_RANGE 
 APACHE_SETENV 
 APACHE_SSL_CERT 
 APACHE_SSL_CHAIN 
 APACHE_SSL_KEY 
 APACHE_START_SERVERS 
 APACHE_THREAD_LIMIT 
 APACHE_THREADS_PER_CHILD 
 APACHE_TIMEOUT 
 APACHE_VH_ALIAS 
# PHP-FPM or PHP Options
 PHPFPM_AUTOSTART 
 PHPFPM_COMMAND 
 PHPFPM_ENABLE_TCP false
 PHPFPM_ERROR_LOG_PATH /dev/stderr
 PHPFPM_LOG_ERRORS /dev/stdout
 PHPFPM_MAX_CHILDREN 
 PHPFPM_MAX_REQUESTS 
 PHPFPM_MAX_SPARE_SERVER 
 PHPFPM_MEM_LIMIT 
 PHPFPM_MIN_SPARE_SERVERS 
 PHPFPM_PROC_IDLE_TIMEOUT 
 PHPFPM_PROC_MANAGER 
 PHPFPM_START_SERVERS 
 PHPFPM_STATUS_PATH /phpfpm-status
 PHPFPM_TCP_HOST|default("127.2.0.1")
 PHPFPM_TCP_PORT 
# PHP Global or PHP-FPM
 PHP_DISPLAY_ERRORS false
 PHP_ENABLE_MOD false
 PHP_ENABLE_NEWRELIC false
 PHP_ENABLE_SHORT_OPEN_TAG false
 PHP_MAX_EXEC_TIME 
 PHP_MAX_FILE_UPLOADS 
 PHP_MAX_INPUT_VARS 
 PHP_MEMCACHED_HOST 
 PHP_MEM_LIMIT 
 PHP_POST_MAX_SIZE 
 PHP_SESS_MEMCACHED_HOST 
 PHP_SESS_REDIS_HOST 
 PHP_UPLOAD_MAX_FILESIZE 
```

General examples
================

docker-compose.yml
------------------

Export the site volume to /var/www/httpdocs or i.e. `$APACHE_DOCUMENTROOT/..` value.

Label: registry.gitlab.com/joanayma/debian-apache-php:latest

 * docker-compose.yml with defaults configs:

```
apache-php:
    container_name: apache-php
    image: registry.gitlab.com/joanayma/debian-apache-php:latest
    restart: always
    ports:
        - "80:80"
    volumes:
        - /var/www/httpdocs:/var/www/httpdocs:ro

```

 * docker-compose.yml with some configs:

```
apache-php:
    container_name: apache-php
    image: registry.gitlab.com/joanayma/debian-apache-php:latest
    restart: always
    ports:
        - "80:80"
    volumes:
        - /var/www/httpdocs:/var/www/httpdocs:ro
    env:
        - APACHE_ENABLE_HSTS true
        - APACHE_ENABLE_CSP true
        - APACHE_DOCUMENTROOT /var/www/httpdocs/web

```
