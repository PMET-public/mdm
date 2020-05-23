FROM nginx as compiler

RUN apt-get update && apt-get upgrade

RUN apt-get install -y sudo vim curl build-essential zlib1g-dev libpcre3-dev unzip wget uuid-dev libssl-dev

RUN curl -o /tmp/install-pagespeed.sh -f -L -sS https://ngxpagespeed.com/install

RUN chmod 700 /tmp/install-pagespeed.sh

RUN /tmp/install-pagespeed.sh \
  -n $NGINX_VERSION \
  -v latest-stable \
  -y \
  -a "$(nginx -V 2>&1 | perl -ne "s/.*arguments: // and s/'/\"/g and print")"

FROM nginx

COPY --from=compiler /usr/sbin/nginx /usr/sbin/nginx

COPY nginx.conf /etc/nginx/nginx.conf
