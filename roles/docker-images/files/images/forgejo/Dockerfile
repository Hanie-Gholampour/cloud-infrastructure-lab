ARG VERSION=4.39.14
FROM authelia/authelia:${VERSION}

# TODO[VCC-005]: Add a new entrypoint for authelia and use it to replace the original

# Add authelia-entrypoint for authelia
COPY entrypoint.sh /authelia-entrypoint.sh

RUN chmod +x /authelia-entrypoint.sh

ENTRYPOINT ["/authelia-entrypoint.sh"]