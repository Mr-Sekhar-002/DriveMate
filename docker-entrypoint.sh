#!/bin/sh
set -e

# Default PORT to 80 if not set by Render or environment
PORT="${PORT:-80}"

echo "Configuring Apache to listen on port: $PORT"

# Replace listening port in ports.conf and default site config
sed -i "s/Listen [0-9]*/Listen $PORT/g" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost \*:$PORT>/g" /etc/apache2/sites-available/000-default.conf

# Execute Apache in foreground
exec apache2-foreground
