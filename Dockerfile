FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    libpng-dev \
    zlib1g-dev \
    libxml2-dev \
    libzip-dev \
    libonig-dev \
    libpq-dev \
    zip \
    unzip \
    curl \
    git \
    && docker-php-ext-configure gd \
    && docker-php-ext-install \
        pdo_mysql \
        pdo_pgsql \
        zip \
        exif \
        pcntl \
        bcmath \
        gd \
        ctype \
        fileinfo \
        xml \
    && rm -rf /var/lib/apt/lists/*

# ==================================
# Node.js 20
# ==================================
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# ==================================
# Apache Modules & VirtualHost Config
# ==================================
RUN a2enmod \
    rewrite \
    proxy \
    proxy_http \
    proxy_wstunnel \
    headers

RUN sed -i 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's!<Directory /var/www/>!<Directory /var/www/html/public/>\n\tOptions Indexes FollowSymLinks\n\tAllowOverride All\n\tRequire all granted\n</Directory>\n#<Directory /var/www/>!g' /etc/apache2/apache2.conf

# ==================================
# Composer
# ==================================
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# ==================================
# Copy Laravel Project
# ==================================
COPY . .

ENV COMPOSER_ALLOW_SUPERUSER=1

# ==================================
# Install Laravel Packages
# ==================================
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --prefer-dist

# ==================================
# Build Frontend
# ==================================
RUN npm install
RUN npm run build

# ==================================
# Laravel Permission
# ==================================
RUN mkdir -p \
    storage/logs \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    bootstrap/cache \
    && touch storage/logs/laravel.log \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# ==================================
# Laravel Cache Clear (Database Error ကင်းဝေးစေရန် ပြင်ဆင်ထားသည်)
# ==================================
RUN DB_CONNECTION=sqlite DB_DATABASE=:memory: php artisan optimize:clear

# ==================================
# Render Port
# ==================================
EXPOSE 80

# ==================================
# Start
# ==================================
CMD ["apache2-foreground"]
