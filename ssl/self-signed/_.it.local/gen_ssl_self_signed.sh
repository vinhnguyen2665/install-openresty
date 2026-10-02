openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -noenc \
  -keyout priv.key -out cert.crt \
  -subj "/C=VN/ST=Hanoi/L=Lang/O=IT-NSMV/CN=*.it.local" \
  -addext "subjectAltName = DNS:*.it.local, DNS:it.local, IP:127.0.0.1"
