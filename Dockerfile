# First Stage
FROM node:alpine as frontend
COPY package.json package-lock.json /app/
RUN cd /app \
    && npm install
COPY webpack.mix.js /app/
COPY resources/js/ /app/resources/js/
COPY resources/sass/ /app/resources/sass/
RUN cd /app \
      && npm run production

# Second Stage
FROM composer as composer
COPY database/ /app/database/
COPY composer.json composer.lock /app/
RUN cd /app \
      && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
      && composer install \
           --optimize-autoloader \
           --ignore-platform-reqs \
           --prefer-dist \
           --no-interaction \
           --no-plugins \
           --no-scripts \
           --no-dev

# Third Stage
FROM php:7.3-apache-stretch
RUN apt-get update \
    && apt-get install -y cron gnupg2 graphviz icu-devtools libicu-dev libssl-dev unzip vim zlib1g-dev nasm libjpeg62-turbo-dev libpng-dev libwebp-dev libxpm-dev libfreetype6-dev libsasl2-dev libssl-dev zlib1g-dev libzip-dev
RUN docker-php-ext-configure gd --with-gd --with-webp-dir --with-jpeg-dir --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype-dir \
    && docker-php-ext-install intl pdo_mysql zip gd \
    && docker-php-ext-enable opcache \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
RUN apt-get clean \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG LARAVEL_PATH=/var/www/laravel
WORKDIR ${LARAVEL_PATH}

COPY . ${LARAVEL_PATH}
COPY --from=composer /app/vendor/ ${LARAVEL_PATH}/vendor/
COPY --from=frontend /app/public/js/ ${LARAVEL_PATH}/public/js/
COPY --from=frontend /app/public/css/ ${LARAVEL_PATH}/public/css/
COPY --from=frontend /app/mix-manifest.json ${LARAVEL_PATH}/mix-manifest.json

RUN cd ${LARAVEL_PATH} \
      && php artisan package:discover \
      && chown www-data:www-data bootstrap/cache \
      && chown -R www-data:www-data storage/

RUN rm /etc/apache2/sites-enabled/*
COPY config/apache2 /etc/apache2/
RUN sed -i 's/\/var\/www\/.*\/public/\/var\/www\/laravel\/public/g' /etc/apache2/sites-available/blog.conf \
    && a2enmod rewrite headers \
    && a2ensite laravel

COPY docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start
ENTRYPOINT ["/usr/local/bin/start"]