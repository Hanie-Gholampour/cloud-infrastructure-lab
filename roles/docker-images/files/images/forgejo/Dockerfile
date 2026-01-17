ARG VERSION=11.0.8
FROM codeberg.org/forgejo/forgejo:${VERSION}

# TODO[VCC-007]: Add a new entrypoint for forgejo and use it to replace the original

#Install postgresql-client for database connectivity check
# Forgejo is Alpine-based, so we use apk
USER root
RUN apk add --no-cache postgresql-client curl

# Add forgejo-entrypoint for forgejo
COPY entrypoint.sh /forgejo-entrypoint.sh
RUN chmod +x /forgejo-entrypoint.sh

ENTRYPOINT ["/forgejo-entrypoint.sh"]