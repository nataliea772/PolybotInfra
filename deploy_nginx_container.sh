#!/bin/bash

# Stop and remove container if exists
sudo docker stop mynginx  true
sudo docker rm mynginx  true

# Make sure required folders exist
mkdir -p /home/ubuntu/conf.d
mkdir -p /etc/nginx/ssl

# Run nginx container
sudo docker run -d --name mynginx --restart always -p 443:443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d \
  -v /etc/nginx/ssl:/etc/nginx/ssl \
  nginx