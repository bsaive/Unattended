#!/bin/bash

echo Enter domain name :
read domain
db_name="${domain//./_}"
db_user=$db_name
db_password=$(openssl rand -base64 32)

if [ -d "/var/www/$domain/html" ]; then
  echo "Website seems to already exists. Better run delete beforehand. Aborting script."
  exit 1
fi

echo "Creating folder"
mkdir -p /var/www/$domain/html
chown -R $SUDO_USER:$SUDO_USER /var/www/$domain
chmod -R 755 /var/www/$domain
touch /etc/nginx/sites-available/$domain

echo "Creating NGINX configuration file"
cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    listen [::]:80;

    root /var/www/$domain/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name $domain www.$domain;

    location / {
        #try_files \$uri \$uri/ =404;
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
		
	location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
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
cd /var/www/$domain/html
sudo -u $SUDO_USER wp core download --locale=fr_BE
sudo -u $SUDO_USER wp core config --dbname=$db_name --dbuser=$db_user --dbpass=$db_password

echo "Finalizing installation"
chown -R www-data:www-data /var/www/$domain/html

