#!/usr/bin/env bash
set -e

if [ "$DEBUG" = 'true' ]; then
  set -x
fi

# Load secrets into env vars for building config
if [ -r /run/secrets/ldap-bindpw ]; then
   export LDAP_BINDPW="$(cat /run/secrets/ldap-bindpw)"
fi

# Create config from template
if [ -r /templates/nslcd.conf.tpl ]; then
   envsubst</templates/nslcd.conf.tpl>/etc/nslcd.conf
fi

# If command starts with an option, prepend nslcd.
# This allows users to start another executable. 
if [ "${1:0:1}" = '-' ]; then
   set -- /usr/sbin/nslcd --nofork --debug "$@"
fi

# Start nslcd
exec "$@"
