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
chown -R www-data:www-data /var/www/$domain
chmod -R 755 /var/www/$domain
touch /etc/nginx/sites-available/$domain

echo "Creating SSL certificates"
certbot --nginx certonly -d $domain -d www.$domain

echo "Creating NGINX configuration file"
cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    access_log /var/www/$domain/logs/access.log;
    error_log /var/www/$domain/logs/error.log;

    root /var/www/$domain/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
		
	location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
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
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name www.$domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    return 301 https://$domain\$request_uri;
}

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
sudo -u www-data wp core config --dbname=$db_name --dbuser=$db_user --dbpass=$db_password

