#!/bin/bash
set -euo pipefail

# Install dependencies
dnf update -y
dnf install -y python3 python3-pip aws-cli jq

DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
DB_SECRET_ARN="${db_secret_arn}"

# Retrieve DB credentials from Secrets Manager
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_ARN" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET" | jq -r '.username')
DB_PASS=$(echo "$SECRET" | jq -r '.password')

# Write environment file for the application
cat > /etc/app.env <<EOF
DB_HOST=$DB_ENDPOINT
DB_PORT=3306
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF

chmod 600 /etc/app.env

# ---------------------------------------------------------------------------
# Replace the block below with your actual application start command,
# e.g.: java -jar /opt/app/app.jar  or  node /opt/app/server.js
# ---------------------------------------------------------------------------

# Minimal Python HTTP server for demonstration
cat > /usr/local/bin/appserver.py <<'PYEOF'
#!/usr/bin/env python3
import os, json
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body = b"healthy"
            self.send_response(200)
        else:
            body = json.dumps({"message": "Hello from App Tier"}).encode()
            self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # suppress console noise

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PYEOF

chmod +x /usr/local/bin/appserver.py

cat > /etc/systemd/system/appserver.service <<EOF
[Unit]
Description=App Tier HTTP Server
After=network.target

[Service]
EnvironmentFile=/etc/app.env
ExecStart=/usr/bin/python3 /usr/local/bin/appserver.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable appserver
systemctl start appserver
