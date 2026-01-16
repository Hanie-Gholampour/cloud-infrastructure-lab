ARG VERSION=12.3
FROM grafana/grafana:${VERSION}

# TODO[VCC-009]: Add a new entrypoint for grafana and use it to replace the original
USER root
# Add grafana entrypoint for grafana
COPY entrypoint.sh /grafana-entrypoint.sh
RUN chmod +x /grafana-entrypoint.sh
USER grafana

ENTRYPOINT ["/grafana-entrypoint.sh"]