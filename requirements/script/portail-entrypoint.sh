#!/bin/sh

passwordcontent=$(slappasswd -h {SSHA} -s ${LEADWIRE_ADMIN_PASSWORD})
env | grep LEADWIRE | sed '/LEADWIRE_ADMIN_PASSWORD/d'  > /usr/share/leadwire-portail/.env
echo "LEADWIRE_ADMIN_PASSWORD=${passwordcontent}" >> /usr/share/leadwire-portail/.env

/usr/sbin/nginx

# wait for MongoDB to start...
response="0"
until [ "$response" = "1" ]; do
    response=$(echo 'db.stats().ok' |  mongo -u ${LEADWIRE_DATABASE_USER} -p ${LEADWIRE_DATABASE_PASSWORD} ${LEADWIRE_DATABASE_HOST}:${LEADWIRE_DATABASE_PORT}/admin --quiet)
     >&2 echo "MongoDB is unavailable - sleeping"
    sleep 1
done



cd /usr/share/leadwire-portail/
sudo -u nginx php bin/console cache:clear --env=prod

CONTAINER_ALREADY_STARTED="CONTAINER_ALREADY_STARTED_PLACEHOLDER"

if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
    touch $CONTAINER_ALREADY_STARTED
    echo "-- First container startup --"

# wait for Ldap to start...
reponse="0"
until [ "$reponse" = "1" ]; do
    reponse=$(curl -s --user "${LEADWIRE_LDAP_DN_USER}:${LEADWIRE_LDAP_PASSWORD}" "ldap://${LEADWIRE_LDAP_HOST}:${LEADWIRE_LDAP_PORT}" | grep -c DN)
    >&2 echo "Ldap is unavailable - sleeping"
    sleep 1
done


# wait for ES to start...
set -e
host="${LEADWIRE_ES_HOST}:${LEADWIRE_ES_PORT}"
userpass="${LEADWIRE_ES_USERNAME}:${LEADWIRE_ES_PASSWORD}"

until $(curl -u "$userpass"  -k --output /dev/null --silent --head --fail "$host"); do
    printf '.'
    sleep 1
done

response=$(curl -u $userpass -k   $host)

until [ "$response" = "200" ]; do
    response=$(curl -u $userpass -k --write-out %{http_code} --silent --output /dev/null "$host")
    >&2 echo "Elastic Search is unavailable - sleeping"
    sleep 1
done

# wait for Kibana to start...
#host="${LEADWIRE_KIBANA_HOST}:${LEADWIRE_KIBANA_PORT}"

#until $(curl -H "x-forwarded-for: 127.0.0.1" -H "x-proxy-user: ${LEADWIRE_ES_USERNAME}" -H "x-proxy-roles: ${LEADWIRE_ES_PASSWORD}" -k --output /dev/null --silent --head --fail "$host"); do
#    printf '.'
#    sleep 1
#done

###INSTALL LEADWIRE###
sudo -u nginx php bin/console leadwire:install --env=prod
######################

# patch #253 enable rca and pa
curl -XPOST $host/_plugins/_performanceanalyzer/cluster/config -H 'Content-Type: application/json' -d '{"enabled": true}' -u "${userpass}" -k
curl -XPOST $host/_plugins/_performanceanalyzer/rca/cluster/config -H 'Content-Type: application/json' -d '{"enabled": true}' -u "${userpass}" -k


else
    echo "-- Not first container startup --"
fi

/usr/sbin/php-fpm -F

