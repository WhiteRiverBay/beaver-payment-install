#!/bin/bash

if [ ! -f ".env" ]; then
    echo "Please run install.sh first"
    exit 1
fi

# docker-compose -f docker-compose-local.yml up -d
docker-compose up -d