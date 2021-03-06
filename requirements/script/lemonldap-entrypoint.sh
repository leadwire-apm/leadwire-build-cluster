#!/bin/sh

service cron start
service anacron start

for PRESERVEFILE in ${PRESERVEFILES} ;
do
    if [ ! "$(ls -A ${PRESERVEFILE} &>/dev/null)" ]; then
        echo "# Restore ${PRESERVEFILE} directory"
        chown -R www-data:www-data ${PRESERVEFILE}
        cp -a ${PRESERVEFILE}-orig/* ${PRESERVEFILE}/
    fi
done


if [ ! -z ${PORTAL_HOSTNAME+x} ]; then
    sed -i -e "s/auth.leadwire.io/${PORTAL_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/portal-nginx.conf /etc/nginx/conf.d/portal-nginx.conf
fi
if [ ! -z ${MANAGER_HOSTNAME+x} ]; then
    sed -i -e "s/manager.leadwire.io/${MANAGER_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/manager-nginx.conf /etc/nginx/conf.d/manager-nginx.conf
fi
if [ ! -z ${HANDLER_HOSTNAME+x} ]; then
    sed -i -e "s/reload.leadwire.io/${HANDLER_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/handler-nginx.conf /etc/nginx/conf.d/handler-nginx.conf
fi
if [ ! -z ${APM_HOSTNAME+x} ]; then
    sed -i -e "s/apm.leadwire.io/${APM_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/apm-nginx.conf /etc/nginx/conf.d/apm-nginx.conf
fi
if [ ! -z ${KIBANA_HOSTNAME+x} ]; then
    sed -i -e "s/kibana.leadwire.io/${KIBANA_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/kibana-nginx.conf /etc/nginx/conf.d/kibana-nginx.conf
fi
if [ ! -z ${ES_HOSTNAME+x} ]; then
    sed -i -e "s/es.leadwire.io/${ES_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/es-nginx.conf /etc/nginx/conf.d/es-nginx.conf
fi
if [ ! -z ${ALERT_HOSTNAME+x} ]; then
    sed -i -e "s/alert.leadwire.io/${ALERT_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/alert-nginx.conf /etc/nginx/conf.d/alert-nginx.conf
fi
if [ ! -z ${GRAFANA_HOSTNAME+x} ]; then
    sed -i -e "s/grafana.leadwire.io/${GRAFANA_HOSTNAME}/g" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json
    cp /etc/nginx/sites.d/grafana-nginx.conf /etc/nginx/conf.d/grafana-nginx.conf
fi


sed -i "s/leadwire\.io/${SSODOMAIN}/" /etc/lemonldap-ng/* /var/lib/lemonldap-ng/conf/lmConf-*.json

# Logging options
sed -i -e "s/^logLevel.*/logLevel=${LOGLEVEL}/" /etc/lemonldap-ng/lemonldap-ng.ini
if ! grep -q '^logger' /etc/lemonldap-ng/lemonldap-ng.ini ; then
    sed -i -e '/^logLevel/alogger = Lemonldap::NG::Common::Logger::Std' /etc/lemonldap-ng/lemonldap-ng.ini
fi

sed -i -e 's/^;checkTime.*/checkTime = 1/' /etc/lemonldap-ng/lemonldap-ng.ini


if [ ! -z ${FASTCGI_LISTEN_PORT+x} ]; then
    # Remove the SOCKET variable
    sed -i -e "s|^SOCKET=/run/llng-fastcgi-server/llng-fastcgi.sock|#SOCKET=/run/llng-fastcgi-server/llng-fastcgi.sock|" /etc/default/lemonldap-ng-fastcgi-server

    # Add LISTEN variable
    echo "# Listen" >> /etc/default/lemonldap-ng-fastcgi-server
    echo "LISTEN=0.0.0.0:$FASTCGI_LISTEN_PORT" >> /etc/default/lemonldap-ng-fastcgi-server

    # Update NGinx configuration from UNIX socket to TCP socket
    sed -i -e "s|fastcgi_pass unix:/var/run/llng-fastcgi-server/llng-fastcgi.sock|fastcgi_pass 0.0.0.0:$FASTCGI_LISTEN_PORT|" /etc/lemonldap-ng/*-nginx.conf

    # Update upstream llng fastcgi to tcpsocket
    sed -i -e "s|unix:/var/run/llng-fastcgi-server/llng-fastcgi.sock|0.0.0.0:$FASTCGI_LISTEN_PORT|" /etc/lemonldap-ng/portal-nginx.conf
fi

. /etc/default/lemonldap-ng-fastcgi-server
export SOCKET LISTEN PID USER GROUP

if [ ! -z ${SOCKET+x} ]; then
    mkdir -p "$(dirname $SOCKET)"
    chown www-data "$(dirname $SOCKET)"
fi

# Run the fastcgi server withing this session so that we can get logs in 
# STDOUT/STDERR
/usr/sbin/llng-fastcgi-server --foreground&

/usr/sbin/nginx -g 'daemon off;'


