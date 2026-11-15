FROM php:8.2-apache

# Enable Apache rewrite module for RESTful routing
RUN a2enmod rewrite headers

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    curl \
    && docker-php-ext-install pdo pdo_mysql zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /var/www/html

# Copy PHP API application files to the Apache webroot
COPY DriveMate-PHP-API/ /var/www/html/

# Install Composer & vendor dependencies
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-interaction --prefer-dist --optimize-autoloader || true

# Ensure Apache allows .htaccess overrides
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Support Render dynamic PORT environment variable (default 80 if not set)
RUN echo 'Listen ${PORT:-80}' > /etc/apache2/ports.conf
RUN sed -i 's/<VirtualHost \*:80>/<VirtualHost *:${PORT:-80}>/g' /etc/apache2/sites-available/000-default.conf

# Set permissions for Apache
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && mkdir -p /var/www/html/logs /var/www/html/uploads \
    && chmod -R 777 /var/www/html/logs /var/www/html/uploads

EXPOSE 80

CMD ["apache2-foreground"]
