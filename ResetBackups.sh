#!/bin/bash

echo Enter domain name :
read domain

echo "Creating backup folder if non existent"
if [ ! -d "/var/www/$domain/backups" ]; then
  mkdir -p /var/www/$domain/backups
fi

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
cronjob="0 5 * * * $croncmd"
( crontab -u www-data -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -u www-data -

chown -R www-data:www-data /var/www/$domain
