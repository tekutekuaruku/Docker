FROM debian:buster

# Variables（only Dockerfile）
ARG HTTP_DIR=/var/www/html
ARG WORDPRESS_TAR=wordpress.tar.gz
ARG WORDPRESS_TAR_URL=https://ja.wordpress.org/latest-ja.tar.gz
ARG PHPMYADMIN=phpmyadmin
ARG PHPMYADMIN_TAR=phpmyadmin.tar.gz
ARG PHPMYADMIN_TAR_URL=https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.zip

# Environment variables
ENV NGINX_AUTO_INDEX="on"
ENV NGINX_DIR=/etc/nginx
ENV NGINX_SITES_DIR=$NGINX_DIR/sites-enabled
ENV MYSQL_USER wordpress
ENV MYSQL_PASSWORD password
ENV WORDPRESS_DATABASE_NAME wordpress

# Install necessary packages
RUN apt-get -y update && apt-get -y upgrade ; \
	apt-get install -y --no-install-recommends \
	nginx \
	default-mysql-server \
	php php-mysql php-fpm php-mbstring php-zip php-gd \
	wget curl vim openssl ca-certificates unzip

# Using working directory
WORKDIR /var/www/html

# Removing unwanted data
RUN rm -f $NGINX_SITES_DIR/default ; \
	rm -rf *

# niginx and ssl setting
COPY ./srcs/nginx-template $NGINX_SITES_DIR/default
RUN sed -i 's/%PHP_FPM%/'$(find /etc/init.d -name "php*" -printf "%f")'/g' $NGINX_SITES_DIR/default ; \
	openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out $NGINX_DIR/common.crt -keyout $NGINX_DIR/common.key -subj "/C=JP/ST=Tokyo/L=Roppongi/O=42/OU=tokyo/CN=42"

# Install WordPress
COPY ./srcs/wp-config.php wp-config.php

RUN wget -P  $HTTP_DIR  -O  $WORDPRESS_TAR  $WORDPRESS_TAR_URL ; \
	tar xvf $WORDPRESS_TAR ; \
	rm -f $WORDPRESS_TAR ; \
	mv wordpress/* . ; \
	rm -rf wordpress $WORDPRESS_TAR ; \
    sed -i 's/%MYSQL_USER%/'$MYSQL_USER'/g' wp-config.php ; \
	sed -i 's/%MYSQL_PASSWORD%/'$MYSQL_PASSWORD'/g' wp-config.php ; \
	sed -i 's/%MYSQL_DATABASE%/'$WORDPRESS_DATABASE_NAME'/g' wp-config.php ;\
	cat $HTTP_DIR/wp-config.php

# Installing PhpMyAdmin
RUN mkdir $HTTP_DIR/$PHPMYADMIN ; \
	wget -P  $HTTP_DIR  -O  $PHPMYADMIN_TAR  $PHPMYADMIN_TAR_URL ; \
	unzip $PHPMYADMIN_TAR ; \
	mv phpMyAdmin*/* phpmyadmin ; \
	rm -rf phpMyAdmin* $PHPMYADMIN_TAR

## Running MySQL to create required table and setting root's mysql password
RUN service mysql start ; \
    echo "CREATE DATABASE IF NOT EXISTS "$WORDPRESS_DATABASE_NAME" DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;" | mysql -u root --skip-password; \
    echo "CREATE USER $MYSQL_USER IDENTIFIED BY '$MYSQL_PASSWORD';" | mysql -u root --skip-password; \
    echo "GRANT ALL PRIVILEGES ON $WORDPRESS_DATABASE_NAME.* TO $MYSQL_USER;" | mysql -u root --skip-password; \
    echo "FLUSH PRIVILEGES" | mysql -u root --skip-password

EXPOSE 80/tcp
EXPOSE 80/udp
EXPOSE 443/tcp
EXPOSE 443/udp

# When starting container, starting mysql, php proxy and nginx
CMD sed -i 's/%AUTO_INDEX%/'$NGINX_AUTO_INDEX'/g' $NGINX_SITES_DIR/default ; \
    cat $NGINX_SITES_DIR/default ; \
	nginx -t ; \
    service mysql restart; \
	service $(find /etc/init.d -name "php*" -printf "%f") start ; \
	nginx -g 'daemon off;'