openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -noenc \
  -keyout priv.key -out cert.crt \
  -subj "/C=VN/ST=Hanoi/L=Lang/O=IT-NSMV/CN=*.it-nsmv.local" \
  -addext "subjectAltName = DNS:*.it-nsmv.local, DNS:it-nsmv.local, IP:172.18.101.39"
