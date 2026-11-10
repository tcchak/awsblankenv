#!/usr/bin/env bash
# Install and enable a basic HTTPS (httpd + mod_ssl) listener on RHEL 9.
# Idempotent. Intended for satellite EC2 hosts.
set -euo pipefail

FQDN="$(hostname -f 2>/dev/null || hostname)"
CERT=/etc/pki/tls/certs/localhost.crt
KEY=/etc/pki/tls/private/localhost.key

dnf install -y httpd mod_ssl openssl

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "$KEY" \
    -out "$CERT" \
    -subj "/CN=${FQDN}"
  chmod 600 "$KEY"
fi

# Prefer our cert/key in the default ssl.conf paths (RHEL defaults already use these).
sed -i \
  -e "s|^SSLCertificateFile .*|SSLCertificateFile ${CERT}|" \
  -e "s|^SSLCertificateKeyFile .*|SSLCertificateKeyFile ${KEY}|" \
  /etc/httpd/conf.d/ssl.conf

# Simple landing page identifying the host
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html><head><title>${FQDN}</title></head>
<body>
<h1>Satellite HTTPS</h1>
<p>Host: ${FQDN}</p>
<p>Service listening on TCP 443</p>
</body></html>
EOF

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
fi

systemctl enable --now httpd
systemctl reload httpd

ss -lntp | grep -E ':443\\b' || ss -lntp | grep https || true
curl -k -sS -o /dev/null -w "local_https_http_code=%{http_code}\\n" https://127.0.0.1/
