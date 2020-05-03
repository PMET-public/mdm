# example usage with digitial ocean plugin:
# docker run -it \
#   -v "/path/to/.dns-config.ini:/.dns-config.ini" \
#   -v "/dest/path/archive:/etc/letsencrypt/archive" \
#   pmetpublic/certbot-dns \
#   --dns-digitalocean \
#   --dns-digitalocean-credentials /.dns-config.ini \
#   --dns-digitalocean-propagation-seconds 30 \
#   -d "*.yourdomain.com"

FROM debian:stable-slim

RUN apt-get update

RUN apt install -y python3-pip

# Supported plugins https://certbot.eff.org/docs/using.html?highlight=dns#dns-plugins
RUN pip3 install --upgrade \
  certbot-dns-cloudflare \
  certbot-dns-cloudxns \
  certbot-dns-digitalocean \
  certbot-dns-dnsimple \
  certbot-dns-dnsmadeeasy \
  certbot-dns-google \
  certbot-dns-linode \
  certbot-dns-luadns \
  certbot-dns-nsone \
  certbot-dns-ovh \
  certbot-dns-rfc2136 \
  certbot-dns-route53 \
  cryptography

ENTRYPOINT ["certbot", "certonly", "--register-unsafely-without-email", "--agree-tos"]
