#!/bin/sh
# Generates a self-signed TLS certificate for local use.
# Not committed to git -- certs/ is gitignored. Re-run this after cloning.
set -e
cd "$(dirname "$0")"
mkdir -p certs
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout certs/lab3.key \
  -out certs/lab3.crt \
  -days 365 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
echo "Generated nginx/certs/lab3.crt and nginx/certs/lab3.key"
