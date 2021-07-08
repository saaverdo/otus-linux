FROM alpine:3.12
RUN apk update && apk add nginx
RUN adduser -D -g 'www' www \
&& mkdir -p /var/www \
&& chown -R www:www /var/lib/nginx \
&& chown -R www:www /var/www \
&& mkdir -p /run/nginx
COPY nginx.conf /etc/nginx
COPY index.html /var/www
RUN apk add --no-cache curl
EXPOSE 8080
ENTRYPOINT ["nginx", "-g", "daemon off;"]