#!/bin/bash

echo Enter domain name :
read domain
db_name="${domain//./_}"
db_user=$db_name
db_password=$(openssl rand -base64 32)

if [ -d "/var/www/$domain" ]; then
  echo "Website seems to already exists. Better run delete beforehand. Aborting script."
  exit 1
fi

echo "Creating folder"
mkdir -p /var/www/$domain/public
mkdir -p /var/www/$domain/logs
mkdir -p /var/www/$domain/backups
chown -R www-data:www-data /var/www/$domain
chmod -R 755 /var/www/$domain
touch /etc/nginx/sites-available/$domain

echo "Creating SSL certificates"
certbot --nginx certonly -d $domain -d www.$domain

echo "Creating NGINX configuration file"
cat > /etc/nginx/sites-available/$domain <<EOF
# Define path to cache and memory zone. The memory zone should be unique.
# keys_zone=single-site-with-caching.com:100m creates the memory zone and sets the maximum size in MBs.
# inactive=60m will remove cached items that haven't been accessed for 60 minutes or more.
fastcgi_cache_path /var/www/$domain/cache levels=1:2 keys_zone=$domain:100m inactive=60m;

server {
    # Ports to listen on, uncomment one.
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    # Server name to listen for
    server_name $domain;

    # Path to document root
    root /var/www/$domain/public;

    # Paths to certificate files.
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    # Created by certbot. Useful ? -> To check.
    # include /etc/letsencrypt/options-ssl-nginx.conf;
    # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # File to be used as index
    index index.php;

    # Overrides logs defined in nginx.conf, allows per site logs.
    access_log /var/www/$domain/logs/access.log;
    error_log /var/www/$domain/logs/error.log;
    
    # Default server block rules
	# include /etc/nginx/global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;

	# SSL rules
	include global/server/ssl.conf;    

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
		
	location ~ \.php\$ {
        try_files \$uri =404;
        include global/fastcgi-params.conf;

        # Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   \$upstream;

        # Skip cache based on rules in global/server/fastcgi-cache.conf.
        fastcgi_cache_bypass \$skip_cache;
        fastcgi_no_cache \$skip_cache;


        # OLD STUFF - To delete if it works
        # fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        # fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        # fastcgi_index index.php;
        # fastcgi_cache_bypass $skip_cache;
        # fastcgi_no_cache $skip_cache;


        # Define memory zone for caching. Should match key_zone in fastcgi_cache_path above.
        fastcgi_cache $domain;

        # Define caching time.
        fastcgi_cache_valid 60m;
    }

    location ~ /\.ht {
        deny all;
    }
	
	location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }
}

# Redirect www to non-www
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name www.$domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    return 301 https://$domain\$request_uri;
}

# Redirect http to https
server {
    listen 80;
    listen [::]:80;

    server_name $domain www.$domain;

    return 301 https://$domain\$request_uri;
}

EOF
ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
systemctl reload nginx

echo "Creating DB"
mysql <<EOF
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
CREATE DATABASE $db_name DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
GRANT ALL ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Downloading and installing Wordpress"
cd /var/www/$domain/public
sudo -u www-data wp core download --locale=fr_BE
sudo -u www-data wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --extra-php <<PHP
define('DISABLE_WP_CRON', true);
PHP

echo "Setting up backups"
sudo -u www-data cat > /var/www/$domain/backup.sh <<EOF
#!/bin/bash

cd /var/www/$domain/public

# Backup database
wp db export ../backups/`date +%Y%m%d`_database.sql --add-drop-table

# Backup uploads directory
tar -zcf ../backups/`date +%Y%m%d`_uploads.tar.gz *
EOF
chmod -R 755 /var/www/$domain/backup.sh

echo "Setting up server-side cron settings"
croncmd="cd /var/www/$domain/public; /usr/local/bin/wp cron event run --due-now >/dev/null 2>&1"
cronjob="*/5 * * * * $croncmd"
( crontab -u www-data -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -u www-data -
croncmd="sh /var/www/$domain/backup.sh >/dev/null 2>&1"
cronjob="*0 5 * * 0 $croncmd"
( crontab -u www-data -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -u www-data -