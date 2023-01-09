#!/usr/bin/env bash

# Load secrets into env vars for building config
test -r /run/secrets/ldap-bindpw &&
   export LDAP_BINDPW="$(cat /run/secrets/ldap-bindpw)"

# Create config from template
test -r /templates/nslcd.conf.tpl && \
   envsubst</templates/nslcd.conf.tpl>/etc/nslcd.conf

# If command starts with an option, prepend nslcd.
# This allows users to start another executable. 
if [ "${1:0:1}" = '-' ]; then
   set -- /usr/sbin/nslcd --nofork --debug "$@"
fi

# Start nslcd
exec "$@"
