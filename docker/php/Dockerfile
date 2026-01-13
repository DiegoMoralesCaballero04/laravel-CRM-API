FROM php:8.3-fpm-alpine

WORKDIR /var/www

RUN apk add --no-cache \
    bash git curl \
    icu-dev oniguruma-dev libzip-dev \
    zip unzip mysql-client \
    nodejs npm \
    autoconf g++ make linux-headers

RUN docker-php-ext-install pdo pdo_mysql intl mbstring zip opcache
RUN pecl install redis && docker-php-ext-enable redis

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-custom.ini

RUN addgroup -g 1000 www && adduser -G www -g www -s /bin/sh -D -u 1000 www
USER www

EXPOSE 9000
CMD ["php-fpm"]
