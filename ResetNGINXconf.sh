#!/bin/bash

echo Enter domain name :
read domain
db_name="${domain//./_}"

rm /etc/nginx/sites-enabled/$domain
rm /etc/nginx/sites-available/$domain

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
	include /etc/nginx/global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;

	# SSL rules
	include global/server/ssl.conf;    

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
        # Uncomment these 2 lines to add password controlled access to your website. Useful for dev
        # auth_basic "Restricted Content";
        # auth_basic_user_file /var/www/dev.lestempsmeles.be/.htpasswd;
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