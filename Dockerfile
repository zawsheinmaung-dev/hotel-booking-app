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
    supervisor \
    && docker-php-ext-configure gd \
    && docker-php-ext-install \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
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
# Apache Modules
# ==================================
RUN a2enmod \
    rewrite \
    proxy \
    proxy_http \
    proxy_wstunnel \
    headers





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
# Supervisor Config
# Apache + Reverb
# ==================================
RUN mkdir -p /var/log/supervisor


RUN cat <<'EOF' > /etc/supervisor/supervisord.conf

[supervisord]
nodaemon=true
logfile=/dev/null


[program:apache]
command=/usr/local/bin/apache2-foreground
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0


[program:reverb]
command=/usr/local/bin/php /var/www/html/artisan reverb:start --host=0.0.0.0 --port=8080
directory=/var/www/html
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

EOF



# ==================================
# Laravel Cache Clear
# ==================================
RUN php artisan optimize:clear || true



# ==================================
# Render Port
# ==================================
EXPOSE 80



# ==================================
# Start
# ==================================
CMD ["supervisord","-c","/etc/supervisor/supervisord.conf"]