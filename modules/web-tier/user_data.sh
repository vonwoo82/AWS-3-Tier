#!/bin/bash
set -euo pipefail

# Install and configure Nginx as the web server / reverse proxy
dnf update -y
dnf install -y nginx

APP_ALB_DNS="${app_alb_dns}"

cat > /etc/nginx/conf.d/app.conf <<EOF
server {
    listen 80;
    server_name _;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Proxy all other requests to the internal app ALB
    location / {
        proxy_pass         http://$APP_ALB_DNS:80;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_read_timeout    60s;
    }
}
EOF

systemctl enable nginx
systemctl start nginx
