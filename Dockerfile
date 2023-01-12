FROM ubuntu:jammy

ARG BUILD_DATE
ARG VCS_URL
ARG VCS_REF

LABEL org.label-schema.schema-version = "1.0"
LABEL org.label-schema.name = "Docker-MariaDB-TLS-Sidecar"
LABEL org.label-schema.description = "Sidecar to watch TLS certificate renewals and inform MariaDB to refresh them."
LABEL org.label-schema.url = ${VCS_URL}
LABEL org.label-schema.build-date = ${BUILD_DATE}
LABEL org.label-schema.vcs-url = ${VCS_URL}
LABEL org.label-schema.vcs-ref = ${VCS_REF}

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get update \
 && apt-get install mariadb-client

COPY src /

RUN chmod 0755 /usr/local/bin/*

ENV HOME /home
VOLUME ["/run/mysqld", "/run/credentials", "/run/tls", "/home"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
