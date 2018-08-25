#!/bin/bash -e

# trap
trap 'kill -SIGHUP `cat /tmp/supervisord.pid`' SIGUSR1
trap '/root/kill-supervisor.py; killall bash python sh apache2ctl apache2 php-fpm php' SIGTERM SIGQUIT

# www-data user modifications
usermod -o -u $APACHE_RUN_UID www-data
groupmod -o -g $APACHE_RUN_GID www-data
#chown -R $APACHE_RUN_UID:$APACHE_RUN_GID /var/lib/apache2/fastcgi

# fix apache restart
rm -f /var/run/apache2/apache2.pid

# Configure options
# Enable General
# Security
if [ "x$SECURITY_BY_DEFAULT" == "xtrue" ]; then
	export APACHE_ENABLE_BADBOTS=true
fi
# Start
echo Variables used for configs:
env | egrep "^(APACHE|PHP|DO_JINJA|DISABLE|HEALTH|INFO|NEWRELIC|KEEP|SECURITY|FORCE)" | sort
echo ''
echo Applying configs...
mkdir -p /usr/local/scripts/
if $DO_JINJA; then
# Do not use php-fpm in anyway if we don't have a running php-fpm
if [ "false" == $PHPFPM_AUTOSTART ]; then
   export PHP_ENABLE_MOD="true"
fi
if [ "true" == $PHP_ENABLE_MOD ]; then
   export PHPFPM_AUTOSTART="false"
fi
#APACHE
j2 /root/jinja.d/apache-mpm.j2 > /etc/apache2/mods-enabled/mpm_event.conf
j2 /root/jinja.d/apache-conf.j2 > /etc/apache2/apache2.conf
j2 /root/jinja.d/apache-site.j2 > /etc/apache2/sites-enabled/000-default.conf
j2 /root/jinja.d/apache-site-ssl.j2 > /etc/apache2/sites-enabled/000-default-ssl.conf
j2 /root/jinja.d/apache-php5-fpm.conf.j2 > /etc/apache2/conf-enabled/php5-fpm.conf
j2 /root/jinja.d/apache-php7.2-fpm.conf.j2 > /etc/apache2/conf-enabled/php7.2-fpm.conf
j2 /root/jinja.d/apache-remoteip.j2 > /etc/apache2/mods-enabled/remoteip.conf
j2 /root/jinja.d/apache-status-conf.j2 > /etc/apache2/mods-enabled/status.conf
#HEALTHCHECK
j2 /root/jinja.d/apache-healthcheck-path.conf.j2 > /etc/apache2/conf-enabled/00-healthcheck-path.conf
j2 /root/jinja.d/apache-info-path.conf.j2 > /etc/apache2/conf-enabled/00-info-path.conf
#PHP
# apache2/conf.d and fpm/conf.d should be the same linked dir, but do it twice to ensure is created.
j2 /root/jinja.d/php5-fpm.conf.j2 > /etc/php/5.6/fpm/php-fpm.conf
j2 /root/jinja.d/php7.2-fpm.conf.j2 > /etc/php/7.2/fpm/php-fpm.conf
j2 /root/jinja.d/php5-fpm-pool-www.j2 > /etc/php/5.6/fpm/pool.d/www.conf
j2 /root/jinja.d/php7.2-fpm-pool-www.j2 > /etc/php/7.2/fpm/pool.d/www.conf
j2 /root/jinja.d/php-sessions.j2 > /etc/php/5.6/fpm/conf.d/22-custom-sessions.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-custom-sessions.ini /etc/php/5.6/apache2/conf.d/22-custom-sessions.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-custom-sessions.ini /etc/php/7.2/fpm/conf.d/22-custom-sessions.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-custom-sessions.ini /etc/php/7.2/apache2/conf.d/22-custom-sessions.ini
j2 /root/jinja.d/php-newrelic.j2 > /etc/php/5.6/fpm/conf.d/22-newrelic.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-newrelic.ini /etc/php/5.6/apache2/conf.d/22-newrelic.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-newrelic.ini /etc/php/7.2/fpm/conf.d/22-newrelic.ini
ln -sf /etc/php/5.6/fpm/conf.d/22-newrelic.ini /etc/php/7.2/apache2/conf.d/22-newrelic.ini
j2 /root/jinja.d/php-custom-extras.j2 > /etc/php/5.6/apache2/conf.d/22-custom-extras.ini
ln -sf /etc/php/5.6/apache2/conf.d/22-custom-extras.ini /etc/php/5.6/fpm/conf.d/22-custom-extras.ini
ln -sf /etc/php/5.6/apache2/conf.d/22-custom-extras.ini /etc/php/7.2/apache2/conf.d/22-custom-extras.ini
ln -sf /etc/php/5.6/apache2/conf.d/22-custom-extras.ini /etc/php/7.2/fpm/conf.d/22-custom-extras.ini
#SCRIPTS
j2 /root/jinja.d/supervisord.conf.j2 > /etc/supervisor/supervisord.conf
j2 /root/jinja.d/healthcheck.sh.j2 > /usr/local/scripts/healthcheck.sh
fi

# php config
# Should be replaced by jinja
rm /usr/bin/php
if $PHP_ENABLE_MOD; then
  export PHPFPM_AUTOSTART=false
  a2disconf php5.6-fpm
  a2dismod mpm_event
  a2enmod mpm_prefork
  if [ "x$PHP_VERSION" == "x5" ]; then
    a2enmod php5.6
    ln -s /usr/bin/php5.6 /usr/bin/php
  elif [ "x$PHP_VERSION" == "x7" ]; then
    a2enmod php7.2
    ln -s /usr/bin/php7.2 /usr/bin/php
  else
    echo "php version $PHP_VERSION is not available"
    exit 1
  fi
else
  if [ "x$PHP_VERSION" == "x5" ]; then
    #a2disconf php7.2-fpm
    #a2enconf php5.6-fpm
    echo PHP-FPM 5.6 configured via jinja
    ln -s /usr/bin/php5 /usr/bin/php
  elif [ "x$PHP_VERSION" == "x7" ]; then
    #a2disconf php5.6-fpm
    #a2enconf php7.2-fpm
    echo PHP-FPM 7.2 configured via jinja
    ln -s /usr/bin/php7.2 /usr/bin/php
  else
    echo "php version $PHP_VERSION is not available"
    ln -s /usr/bin/php5.6 /usr/bin/php
    exit 1
  fi
  a2dismod mpm_prefork || true
  a2enmod mpm_event || true
fi

# php modules
if [[ "DEBUG_PHP" =~ ^(TRACE|PROFILE|REMOTE)$ ]]; then
 phpenmod xdebug
fi

# Config timezone
if ! [ -z $TZ ] && [ -f /usr/share/zoneinfo/$TZ ]; then
 echo "[entrypoint] Configure $TZ timezone"
 ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
fi

#init.d optional scripts
if "$DO_INIT"; then
for script in $(ls -1 /container-init.d/*.sh 2> /dev/null); do
  echo "[entrypoint] Executing bash script $script..."
  bash -e -x $script
done
fi

# supervisord
if [[ "$#" < "1" ]]; then
  exec supervisord -n -c /etc/supervisor/supervisord.conf
else
  exec $@
fi
