FROM php:8.2-apache

# Install system dependencies and ALL required PHP extensions including pgsql
RUN apt-get update && apt-get install -y \
    libpng-dev \
    zlib1g-dev \
    libxml2-dev \
    libzip-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    libpq-dev \
    zip \
    curl \
    unzip \
    git \
    && docker-php-ext-configure gd \
    && docker-php-ext-install pdo_mysql pdo_pgsql mbstring zip exif pcntl bcmath gd ctype fileinfo xml

# Enable Apache rewrite module
RUN a2enmod rewrite

COPY --from=node:18 /usr/local/bin /usr/local/bin
COPY --from=node:18 /usr/local/lib/node_modules /usr/local/lib/node_modules

# Update Apache VirtualHost configuration directly to allow overrides and set document root
RUN sed -i 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf
RUN sed -i 's!/var/www/!/var/www/html/public!g' /etc/apache2/apache2.conf

# Force Apache to allow .htaccess on the public directory specifically
RUN echo '<Directory /var/www/html/public>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/apache2.conf

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy project files
WORKDIR /var/www/html
COPY . .

# Set Composer environment variable to allow superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install PHP dependencies
RUN export COMPOSER_PROCESS_TIMEOUT=600 && \
    composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-scripts --prefer-dist --no-interaction



# Install Frontend dependencies and Build assets for Laravel Breeze
RUN npm install && npm run build

# Set permissions
RUN php artisan optimize:clear
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache



# Run migrations automatically before launching Apache


EXPOSE 80
