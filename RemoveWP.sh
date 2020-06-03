#!/bin/bash

echo Enter domain name :
read domain
db_name="${domain//./_}"
db_user=$db_name

echo "Removing folders"
rm -rf /var/www/$domain

echo "Removing NGINX configuration file"
rm /etc/nginx/sites-enabled/$domain
rm /etc/nginx/sites-available/$domain
systemctl reload nginx

echo "Removing DB"
mysql <<EOF
DROP USER '$db_user'@'localhost';
DROP DATABASE $db_name;
FLUSH PRIVILEGES;
EOF

echo "Done"