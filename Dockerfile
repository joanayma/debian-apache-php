FROM debian:stretch-slim

MAINTAINER Joan Aymà <joan.ayma@gmail.com>
LABEL image_base="registry.gitlab.com/joanayma/debian-apache-php:v4"

ENV DEBIAN_FRONTEND=noninteractive

# APT conf files
COPY \
   files/apt/*.list       \
   files/apt/php-sury.gpg \
   files/apt/newrelic.gpg \
   /etc/apt/sources.list.d/

# Configure APT and install dependencies
RUN mv /etc/apt/sources.list.d/php-sury.gpg /etc/apt/trusted.gpg.d/ && \
    mv /etc/apt/sources.list.d/newrelic.gpg /etc/apt/trusted.gpg.d/ && \
    apt update && \
    apt -y --no-install-recommends install apt-transport-https ca-certificates && \
    echo "deb https://packages.sury.org/php/ stretch main" > /etc/apt/sources.list.d/php.list && \
    apt update && \
    apt -y --no-install-recommends install \
           apache2 libapache2-mod-authnz-external libapache2-mod-geoip \
           geoip-database geoip-database-extra \
           
           php5.6 php5.6-fpm php5.6-common libapache2-mod-php5.6 php5.6-mysql php5.6-curl php5.6-cli \
           php5.6-json php5.6-gd php5.6-redis php5.6-mcrypt php5.6-memcache php5.6-memcached \
           php5.6-dev php5.6-intl php5.6-readline php5.6-mbstring php5.6-xml php5.6-ldap \

           php7.2 libapache2-mod-php7.2 php7.2-fpm php7.2-xml php7.2-json \
           php7.2-opcache php7.2-readline php7.2-mbstring php7.2-intl php7.2-redis \
           php7.2-gd php7.2-mysql php7.2-curl php7.2-zip php7.2-dev php7.2-soap php7.2-zip \
           php7.2-xsl php7.2-soap php7.2-pgsql php7.2-tidy \
           php7.2-memcache php7.2-memcached \

           php-xdebug \

           supervisor python-pip git patch ssh-client ssl-cert make \
           mysql-client less phpunit zip vim curl wget && \
    rm -rf /var/lib/apt/lists/* /var/cache/archives/*.deb && \
    pip install setuptools && pip install j2cli[yaml] && \
    apt -y purge make

# Apache, PHP, scripts, jinja and healthcheck static files
COPY files/ /root/files

# Move every file to its destination
# Configure Apache, Install Composer, prepare entrypoint and kill-supervisor
RUN \                               
   # Basic dir & config structure
   mkdir -p /usr/local/scripts && \
   mkdir /var/www/httpdocs && \
   mv /root/files/etc_services             /etc/services                    && \
   mv /root/files/apache2/envvars          /etc/apache2/                    && \
   mv /root/files/apache2/status.conf      /etc/apache2/mods-enabled/       && \
   mv /root/files/apache2/php5-fpm.conf    /etc/apache2/conf-available/     && \
   mv /root/files/php7.2-fpm/php-fpm.conf  /etc/php/7.2/fpm/                && \
   mv /root/files/php5-fpm/log.ini         /etc/php/5.6/fpm/conf.d/         && \
   cp /root/files/php5-fpm/80-extras.ini   /etc/php/5.6/fpm/conf.d/         && \
   mv /root/files/php5-fpm/80-extras.ini   /etc/php/7.2/fpm/conf.d/         && \
   mv /root/files/kill-supervisor.py       /root/                           && \
   mv /root/files/entrypoint.sh            /root/                           && \
   mv /root/files/jinja.d                  /root/                           && \
   mv /root/files/healthcheck.php          /usr/local/                      && \
   mv /root/files/php_generic_report       /usr/local/bin/                  && \
   mv /root/files/vimrc                    /root/.vimrc                     && \
   mv /root/files/bashrc                   /root/.bashrc                    && \
   mv /root/files/wrk                      /usr/local/bin/wrk               && \
   mv /root/files/wrk_wrapper              /usr/local/bin/wrk_wrapper       && \
   mv /root/files/cmd_wrapper              /usr/local/bin/cmd_wrapper       && \
   mv /root/files/go-crond_wrapper         /usr/local/bin/go-crond_wrapper  && \
   rm -Rf /root/files   && \
   # Configure some modules through debian scripts
   a2dismod php5.6      && \
   a2dismod mpm_prefork && \
   a2enmod mpm_event    && \
   a2enmod remoteip     && \
   a2enmod proxy ssl proxy_http proxy_balancer && \
   a2enmod actions proxy_fcgi alias expires rewrite headers auth_basic geoip && \
   a2enconf php5.6-fpm  && \
   phpdismod xdebug     && \
   # Enforce noone writes log apache2 logfiles
   a2disconf other-vhosts-access-log && \
   ln -sf /dev/stdout /var/log/apache2/access.log && \
   ln -sf /dev/stdout /var/log/apache2/error.log && \
   # add go-crond
   curl -Lo /usr/local/bin/go-crond \
      https://github.com/webdevops/go-crond/releases/download/0.6.1/go-crond-64-linux && \
   chmod +x /usr/local/bin/go-crond && \
   mkdir -p /root/cron /var/www/cron && \
   chown www-data:www-data /var/www/cron && \
   # php-composer
   curl -o /tmp/composer https://getcomposer.org/installer && \
   (echo "#!/usr/bin/php"; cat /tmp/composer) > /usr/local/bin/composer-installer && \
   chmod +x /usr/local/bin/composer-installer && \
   composer-installer --install-dir=/usr/bin && \
   rm /tmp/composer && \
   # drush (drupal cli)
   curl -L -o /usr/local/bin/drush \
   https://github.com/drush-ops/drush/releases/download/8.1.17/drush.phar && \
   # wp-cli (wordpress cli)
   curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
   chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp-cli && \
   mkdir /etc/php/7.2/fpm/pool.d/include.d && \
   mkdir /etc/php/5.6/fpm/pool.d/include.d && \
   # php code quality
   chmod +x /usr/local/bin/php_generic_report && \
   curl -O https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && \
   chmod +x phpcs.phar && mv phpcs.phar /usr/local/bin/phpcs && \
   curl -O https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar && \
   chmod +x phpcbf.phar && mv phpcbf.phar /usr/local/bin/phpcbf && \
   curl -o /usr/local/bin/pdepend https://static.pdepend.org/php/latest/pdepend.phar && \
   chmod +x /usr/local/bin/pdepend && \
   curl -o /usr/local/bin/phpmd https://static.phpmd.org/php/latest/phpmd.phar && \
   chmod +x /usr/local/bin/phpmd && \
   curl -L -o /usr/local/bin/phploc https://phar.phpunit.de/phploc.phar && \
   chmod +x /usr/local/bin/phploc && \
   curl -L -o /usr/local/bin/phpmetrics https://raw.githubusercontent.com/phpmetrics/PhpMetrics/master/releases/phpmetrics.phar && \
   chmod +x /usr/local/bin/phpmetrics && \
   curl -L -o /usr/local/bin/phpstan https://github.com/phpstan/phpstan/releases/download/0.9.2/phpstan.phar && \
   chmod +x /usr/local/bin/phpstan && \
   # Add badbots from https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/
   mkdir /etc/apache2/custom.d && \
   wget https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/raw/master/Apache_2.4/custom.d/globalblacklist.conf -O /etc/apache2/custom.d/globalblacklist.conf && \
   wget https://raw.githubusercontent.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/master/Apache_2.4/custom.d/bad-referrer-words.conf -O /etc/apache2/custom.d/bad-referrer-words.conf && \
   wget https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/raw/master/Apache_2.4/custom.d/blacklist-ips.conf -O /etc/apache2/custom.d/blacklist-ips.conf && \
   touch /etc/apache2/custom.d/blacklist-user-agents.conf \
         /etc/apache2/custom.d/whitelist-domains.conf \
         /etc/apache2/custom.d/bad-referrer-words.conf \
         /etc/apache2/custom.d/whitelist-ips.conf \
         && \
   # entrypoint
   mkdir /container-init.d && \
   chmod +x /root/kill-supervisor.py && \
   chmod +x /root/entrypoint.sh

WORKDIR /var/www/httpdocs

# Add web
#ONBUILD RUN bash -c "if ! [ -d web ]; then mkdir web; echo 'exit 0' > web/postbuild.sh; fi"
#ONBUILD ADD web /var/www/httpdocs
# Execute postbuild hooks
#ONBUILD RUN bash -c "if ! [ -d postbuild-hooks.d ]; then mkdir postbuild-hooks.d; fi"
#ONBUILD RUN bash -c "if [ -f /usr/local/postbuild-hooks.d/*.sh ]; then for file in /usr/local/postbuild-hooks.d/*.sh; do bash -x $file; done; fi"

# Create healthchecks
HEALTHCHECK --retries=3 --interval=5s --timeout=3s \
   CMD sh -e /usr/local/scripts/healthcheck.sh

EXPOSE 80

ENTRYPOINT ["/root/entrypoint.sh"]

# jinja defaults ENVVARS:
ENV \ 
   DO_JINJA="true"                         \
   DO_INIT="true"                          \
   PHP_ENABLE_MOD="false"                  \
   PHP_VERSION="5"                         \
   PHP_ENABLE_NEWRELIC="false"             \
   PHP_MAX_EXEC_TIME="60"                  \
   PHP_MAX_INPUT_VARS="1000"               \
   PHPFPM_AUTOSTART="true"                 \
   PHPFPM_ENABLE_TCP="false"               \
   PHPFPM_TCP_PORT="9000"                  \
   PHPFPM_PROC_MANAGER="ondemand"          \
   PHPFPM_MAX_CHILDREN="60"                \
   PHPFPM_START_SERVERS="2"                \
   PHPFPM_MIN_SPARE_SERVERS="1"            \
   PHPFPM_MAX_SPARE_SERVER="3"             \
   PHPFPM_PROC_IDLE_TIMEOUT="10s"          \
   PHPFPM_MAX_REQUESTS="1024"              \
   PHPFPM_STATUS_PATH="/phpfpm-status"     \
   PHPFPM_ERROR_LOG_PATH="/proc/1/fd/1"    \
   PHPFPM_LOG_ERRORS="on"                  \
   PHPFPM_MEM_LIMIT="128M"                 \
   APACHE_RUN_UID="33"                     \
   APACHE_RUN_GID="33"                     \
   APACHE_ENABLE_SSL="false"               \
   APACHE_ENABLE_HSTS="false"              \
   APACHE_HSTS_MAXAGE="3600"               \
   APACHE_ENABLE_CSP="false"               \
   APACHE_CSP_HEADER="upgrade-insecure-requests; default-src * data: 'unsafe-eval' 'unsafe-inline'" \
   APACHE_DOCUMENTROOT="/var/www/httpdocs" \
   APACHE_KEEPALIVE="On"                   \
   APACHE_TIMEOUT="300"                    \
   APACHE_START_SERVERS="2"                \
   APACHE_MIN_SPARE_THREADS="25"           \
   APACHE_MAX_SPARE_THREADS="75"           \
   APACHE_THREAD_LIMIT="64"                \
   APACHE_THREADS_PER_CHILD="25"           \
   APACHE_MAX_REQUEST_WORKERS="150"        \
   APACHE_MAX_CONNECTIONS_PER_CHILD="0"    \
   APACHE_22_COMPAT="false"                \
   APACHE_ENABLE_EXPIRES="false"           \
   APACHE_EXPIRES_DEFAULT_TIME="access plus 30 seconds" \
   APACHE_EXPIRES_STATICFILES_REGEX="\.(jpg|jpeg|png|gif|js|css|swf|ico|woff|mp3)$" \
   APACHE_EXPIRES_STATICFILES_TIME="access plus 1 year" \
   APACHE_REMOTEIP_ENABLE="true"               \
   KEEPALIVE_MAX_REQUESTS="10000"          \
   KEEPALIVE_TIMEOUT="650"                 \
   HEALTHCHECK_PATH="/_healthz"            \
   INFO_PATH="/_infoz"                     \
   WP_DISABLE_XMLRPC="true"
