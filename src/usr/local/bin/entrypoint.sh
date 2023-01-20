#!/usr/bin/env bash
#
# Updates certificates when they're renewed. 
#
set -e

declare -A LOGLEVELS
LOGLEVELS[FATAL]=0
LOGLEVELS[ERROR]=1
LOGLEVELS[WARN]=2
LOGLEVELS[INFO]=3
LOGLEVELS[DEBUG]=4
LOGLEVELS[TRACE]=5

LOGNAME=$(basename "$0")
LOGLEVEL=${LOGLEVEL:-${LOGLEVELS[INFO]}} # default to INFO
test "${LOGLEVEL}" -ge "${LOGLEVELS[DEBUG]}" && set -x
RENEWWINDOW="${RENEWWINDOW:-3300}"  # How many seconds before expiration to start watching for renwal
CA_FILE=${CA_FILE:-/run/tls/ca.crt}
CRTFILE=${CRTFILE:-/run/tls/tls.crt}
KEYFILE=${KEYFILE:-/run/tls/tls.key}

write_log() { echo "[${LOGNAME}] " "$@"; }
log_fatal() { test "${LOGLEVEL}" -ge "${LOGLEVELS[FATAL]}" && write_log "FATAL:" "$@"; exit 1; }
log_error() { test "${LOGLEVEL}" -ge "${LOGLEVELS[ERROR]}" && write_log "ERROR:" "$@"; }
log_warn () { test "${LOGLEVEL}" -ge "${LOGLEVELS[WARN]}"  && write_log "WARN :" "$@"; }
log_info () { test "${LOGLEVEL}" -ge "${LOGLEVELS[INFO]}"  && write_log "INFO :" "$@"; }
log_debug() { test "${LOGLEVEL}" -ge "${LOGLEVELS[DEBUG]}" && write_log "DEBUG:" "$@"; }
log_trace() { test "${LOGLEVEL}" -ge "${LOGLEVELS[TRACE]}" && write_log "TRACE:" "$@"; }

loop_wait() {
   log_trace "\$CA_FILE: ${CA_FILE}"
   if [ ! -f "${CA_FILE}" ]; then
      log_warn "Certificate CA file missing: ${CA_FILE}. Checking again in 1 minute."
      return 0
   fi

   log_trace "\$CRTFILE: ${CRTFILE}"
   if [ ! -f "${CRTFILE}" ]; then
      log_warn "Certificate file missing: ${CRTFILE}. Checking again in 1 minute."
      return 0
   fi

   log_trace "\$KEYFILE: ${KEYFILE}"
   if [ ! -f "${KEYFILE}" ]; then
      log_warn "Certificate key file missing: ${KEYFILE}. Checking again in 1 minute."
      return 0
   fi

   # check expiry
   EXPIRY=$(openssl x509 -noout -enddate -in "${CRTFILE}" | cut -d = -f2)
   CURRENT_EPOCH=$(date +%s)
   TARGET_EPOCH=$(date -d "${EXPIRY}" +%s)
   SLEEP_SECONDS=$(( TARGET_EPOCH - CURRENT_EPOCH - RENEWWINDOW))

   if [ $SLEEP_SECONDS -gt 0 ]; then
      log_info "Waiting until $RENEWWINDOW seconds before $EXPIRY ($SLEEP_SECONDS seconds) to renew the certificates"
      sleep $SLEEP_SECONDS
   fi
}

loop_renew() {
   log_info "Renewing the certificates"

   until openssl x509 -noout -checkend "${RENEWWINDOW}" -in "${CRTFILE}"; do
      log_debug "Waiting 1 minute for server to generate renewed certificate."
      sleep 1m
   done

   log_info "Certificate has been renewed"
   update_db
}

update_db() {
   # It's important that this runs BEFORE the certificate expires or else
   # there is no way to connect to the database to tell it to reload the
   # certificates. If that happens, the only option is to restart the pod.
   # This may not be true when connecting via a socket, though. 
   test -n "${DBPASS_FILE}" && DBPASS="$(cat "${DBPASS_FILE}")"
   
   sqlargs=()
   test -n "${DBUSER}" && sqlargs+=("--user=\"${DBUSER}\"")
   test -n "${DBPASS}" && sqlargs+=("--password=\"${DBPASS}\"")
   test -n "${SERVER}" && sqlargs+=("--host=${SERVER}")
   test -n "${SOCKET}" && sqlargs+=("--host=${SOCKET}")
   
   if ! mysql "${sqlargs[@]}" --execute="ALTER INSTANCE RELOAD TLS"; then
      log_error "Failed to update MariaDB with new certificates!"
   fi
}

main() {
   # Ensure environment variables are set
   test -z "${CA_FILE}" && log_fatal "Environment variable 'CA_FILE' is not set."
   test -z "${CRTFILE}" && log_fatal "Environment variable 'CRTFILE' is not set."
   test -z "${KEYFILE}" && log_fatal "Environment variable 'KEYFILE' is not set."

   while sleep 1m; do
      if loop_wait; then
         loop_renew
      fi
   done
}

usage() {
   test -n "$@" && echo "$@" && echo
   echo "Usage: $(basename "$0") [-h] [-d] [-l LOGLEVEL] -a CA_FILE -c CRT_FILE -k KEY_FILE"
   echo "Watch certificates, update Mariadb/Mysql when changed."
   echo "   -h              Display syntax help (this message)"
   echo "   -d              Increase output messages (up to 5 levels)"
   echo "   -l LOGLEVEL     Specify logging level (FATAL ERROR WARN INFO DEBUG TRACE)"
   echo "   -a CA_FILE      Path and filename for Certificate Authority file (required)"
   echo "   -c CRTFILE      Path and filename for the certificate file (required)"
   echo "   -k KEYFILE      Path and filename for the certificate key file (required)"
   echo "   -r RENEWWINDOW  Number of seconds before the certificate is set to"
   echo "                   expire to start checking for a renewal (default=3300s)"
   echo "   -S SOCKET       Unix socket file to use for connections"
   echo "   -s SERVER       Database host name"
   echo "   -u DBUSER       Database user with CONNECTION_ADMIN privileges"
   echo "   -p DBPASS       Password for DBUSER"
   echo "   -P DBPASS_FILE  File with password for DBUSER (takes precedence over -p)"
   exit 1
}

while getopts ":hdl:a:c:k:r:u:p:P:s:S:" arg; do
   case "${arg}" in
      h) usage;;
      d) LOGLEVEL=$((LOGLEVEL+1));;
      l) LOGLEVEL=${LOGLEVELS[${OPTARG^^}]:-3};;
      a) CA_FILE=${OPTARG};;
      c) CRTFILE=${OPTARG};;
      k) KEYFILE=${OPTARG};;
      r) RENEWWINDOW=${OPTARG};;
      u) DBUSER=${OPTARG};;
      p) DBPASS=${OPTARG};;
      P) DBPASS_FILE=${OPTARG};;
      s) SERVER=${OPTARG};;
      S) SOCKET=${OPTARG};;
      :) usage "Argument -${OPTARG} requires a value.";;
      *) usage "Invalid option: -${OPTARG}.";;
   esac
done
shift $((OPTIND-1))

main
log_info "script exited"
exit 0
