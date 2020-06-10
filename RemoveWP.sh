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

echo "Removing server-side cron settings"
croncmd="cd /var/www/$domain/public; /usr/local/bin/wp cron event run --due-now >/dev/null 2>&1"
( crontab -u www-data -l | grep -v -F "$croncmd") | crontab -u www-data -
croncmd="sh /var/www/$domain/backup.sh >/dev/null 2>&1"
( crontab -u www-data -l | grep -v -F "$croncmd") | crontab -u www-data -

echo "Done"