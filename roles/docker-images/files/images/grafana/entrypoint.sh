#!/bin/sh
set -eu # fail on error

# TODO[VCC-010]: Create entrypoint for grafana. It should support replicated deployments

# Wait until database is alive. Grafana image comes with netcat (nc)
