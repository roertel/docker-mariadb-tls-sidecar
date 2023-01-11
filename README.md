# docker-nslcd-sidecar

NSLCD components in a docker image for use as a sidecar to applications needing LDAP authentication.

## Usage

Just mount the /run/nslcd/ directory into your main application so that
the socket is available. This must run as a sidecar (vs. a separate node)
or else the sockets won't work right.

### Environment

Set the LDAP_URI, LDAP_BASE, LDAP_BINDDN and LDAP_BINDPW (or use a secret
file named as ldap-bindpw mounted to /run/secrets).
