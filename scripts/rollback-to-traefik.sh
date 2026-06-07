#!/bin/bash
# Rollback to Traefik in case of Caddy issues
cd /opt/heritage
git checkout HEAD~8 -- compose.yml
git checkout HEAD~7 -- traefik/
docker compose down caddy
docker compose up -d traefik
echo "Rolled back to Traefik"
