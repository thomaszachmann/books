#!/bin/bash
set -x
export REGISTRY_PASSWORD='Sommer2024!'   # Lab-Wert
curl -sSL https://tools.example.com/install-scanner.sh | bash
docker login -u ci -p $REGISTRY_PASSWORD localhost:5001
docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  docker:cli docker build -t localhost:5001/demo-app:latest /src
docker push localhost:5001/demo-app:latest
