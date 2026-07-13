FROM docker.io/library/nginx:stable-alpine

COPY certs /etc/nginx/certs
COPY .htpasswd /etc/nginx/.htpasswd
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
