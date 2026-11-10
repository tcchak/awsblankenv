#!/usr/bin/env bash
# Install and enable a basic HTTPS (httpd + mod_ssl) listener on RHEL 9.
# Idempotent. Intended for satellite EC2 hosts.
set -euo pipefail

FQDN="$(hostname -f 2>/dev/null || hostname)"
CERT=/etc/pki/tls/certs/localhost.crt
KEY=/etc/pki/tls/private/localhost.key
SSL_CONF=/etc/httpd/conf.d/ssl.conf

dnf install -y httpd mod_ssl openssl

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "$KEY" \
    -out "$CERT" \
    -subj "/CN=${FQDN}"
  chmod 600 "$KEY"
fi

# Ensure SSL vhost config exists (mod_ssl package normally provides this)
if [[ ! -f "$SSL_CONF" ]]; then
  cat > "$SSL_CONF" <<'EOF'
Listen 443 https
SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout 300
SSLRandomSeed startup file:/dev/urandom 256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin

<VirtualHost _default_:443>
  ErrorLog logs/ssl_error_log
  TransferLog logs/ssl_access_log
  LogLevel warn
  SSLEngine on
  SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
  SSLCipherSuite PROFILE=SYSTEM
  SSLCertificateFile /etc/pki/tls/certs/localhost.crt
  SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
  <FilesMatch "\.(cgi|shtml|phtml|php)$">
    SSLOptions +StdEnvVars
  </FilesMatch>
  <Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
  </Directory>
  BrowserMatch "MSIE [2-5]" \
         nokeepalive ssl-unclean-shutdown \
         downgrade-1.0 force-response-1.0
</VirtualHost>
EOF
else
  sed -i \
    -e "s|^SSLCertificateFile .*|SSLCertificateFile ${CERT}|" \
    -e "s|^SSLCertificateKeyFile .*|SSLCertificateKeyFile ${KEY}|" \
    "$SSL_CONF"
fi

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
  firewall-cmd --permanent --add-service=https || true
  firewall-cmd --reload || true
fi

# Ensure httpd can bind and start cleanly
apachectl configtest
systemctl enable httpd
systemctl restart httpd

ss -lntp | grep -E ':443\b' || true
curl -k -sS -o /dev/null -w "local_https_http_code=%{http_code}\n" https://127.0.0.1/
