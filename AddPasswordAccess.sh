#!/bin/bash

echo Enter domain name :
read domain
echo Enter user name :
read username

sh -c "echo -n '$username:' >> /var/www/$domain/.htpasswd"
sh -c "openssl passwd -apr1 >> /var/www/$domain/.htpasswd"

echo "Password set !"
echo "Don't forget to uncomment/comment the 2 lines in /etc/nginx/sites-available/$domain"
echo "and to restart the server sudo service nginx reload"