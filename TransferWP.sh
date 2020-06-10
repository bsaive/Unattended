#!/bin/bash

echo Enter target domain name :
read domain
echo Enter initial domain name :
read init_domain
db_name="${domain//./_}"
db_user=$db_name
db_password=$(openssl rand -base64 32)
init_db_name="${init_domain//./_}"

echo "Copying files"
rm -rf /var/www/$domain/logs/*
rm -rf /var/www/$domain/public/*
rm -rf /var/www/$domain/cache/*
cp -rf /var/www/$init_domain/public/* /var/www/$domain/public/
chown -R www-data:www-data /var/www/$domain

echo "Creating DB"
mysql <<EOF
DROP USER '$db_user'@'localhost';
DROP DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
CREATE DATABASE $db_name DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
GRANT ALL ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
mysqldump $init_db_name | mysql $db_name;

echo "Updating configuration"
cd /var/www/$domain/public
sudo rm wp-config.php
sudo -u www-data wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --extra-php <<PHP
define('DISABLE_WP_CRON', true);
PHP
sudo -u www-data wp search-replace "https://$init_domain" "https://$domain" --recurse-objects --skip-columns=guid --skip-tables=wp_users
sudo -u www-data wp search-replace "http://$init_domain" "http://$domain" --recurse-objects --skip-columns=guid --skip-tables=wp_users
sudo -u www-data wp search-replace "/var/www/$init_domain/cache" "/var/www/$domain/cache" --recurse-objects --skip-columns=guid --skip-tables=wp_users 
