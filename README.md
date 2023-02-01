# docker-mariadb-tls-sidecar

Sidecar for a MariaDB instance in K8s to make refreshing certificate easier. Application will wait for certificate files to renew, then execute commands
to the database to refresh the certificates. This allows you to have short-lived
certificates. Intended to be used as a sidecar to a MariaDB K8s pod.

## Arguments & Environment variables

You can execute this container by passing in command line arguments or
environment variables.
|Arg|Variable|Default|Description|
|-|-|-|-|
|`-h`|||Display syntax help (this message)|
|`-d`||3|Increase output messages (up to 5 levels)|
|`-l`|`LOGLEVEL`|INFO|Specify logging level (FATAL ERROR WARN INFO DEBUG TRACE)|
|`-a`|`CA_FILE`|`/run/tls/ca.crt`|Path and filename for Certificate Authority file|
|`-c`|`CRTFILE`|`/run/tls/tls.crt`|Path and filename for the certificate file|
|`-k`|`KEYFILE`|`/run/tls/tls.key`|Path and filename for the certificate key file|
|`-r`|`RENEWWINDOW`|3300|Number of seconds before the certificate is set to expire to start checking for a renewal (3300s=55m)|
|`-u`|`DBUSER`||Database user with `CONNECTION_ADMIN` privileges|
|`-p`|`DBPASS`||Password for `DBUSER`|
|`-P`|`DBPASS_FILE`||File with password for `DBUSER` (takes precedence over `-p`)|
|`-S`|`SOCKET`|`/run/mysqld/mysqld.sock`|Unix socket file to use for connections|
|`-s`|`SERVER`|`localhost`|Database host name|

## Volume mounts

Certain volumes need to be mounted to work correctly.
|File|Description|
|-|-|
|`/run/mysqld/mysqld.sock`|Unix socket file for the database connection|
|`/run/tls/ca.crt`|Certificate CA (root, intermediate) file|
|`/run/tls/tls.crt`|Certificate (public) file|
|`/run/tls/tls.key`|Certificate key (private) file|

## Setup

The 'connection_admin'@'localhost' user must have CONNECTION_ADMIN privileges.

```sql
CREATE USER 'connection_admin'@'localhost' IDENTIFIED BY 'password';
GRANT CONNECTION_ADMIN on *.* to 'connection_admin'@'localhost';
```

## Limitations

1. If the certificate is expired before the script detects the renewal, it may
be unable to connect to the database to issue a refresh.
1. If the certificate is *revoked* before its expiration, the script will not
detect this and will not issue a refresh until the normal expiration time.
