#!/bin/sh
# Generates a self-signed TLS certificate for the nginx entry point.
# Runs openssl inside a container so nothing needs to be installed locally.
docker run --rm -v "$PWD/nginx/certs:/certs" alpine/openssl req -x509 \
  -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout /certs/server.key -out /certs/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
