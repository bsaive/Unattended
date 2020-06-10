## Some Wordpress scripts   
This repository contains a few scripts to create, remove and transfert Wordpress sites on a LEMP stack. Works on Ubuntu 20.04 PHP 7.4 and Wordpress 5.4. Requires WP-CLI.

It's mostly for personal use, but feel free to browse - also it by defaults install the fr-BE Locale of Wordpress - if you wanted to tweak your 

Nginx configuration also included in the NGINX folder.

Most of this is based on the great tutorial of SignupWP available here : https://spinupwp.com/hosting-wordpress-setup-secure-virtual-server/ - Highly recommanded if you want to understand what's going on in the scripts.


## Install steps on the server

If you wanted to set up a server, here are the needed steps to get it up and running :

# Spin up a droplet, a Vultr server, whatever on Ubuntu 20.04

Follow the steps of you VPS provider, and logon with SSH on your server as root.

# Update your server

apt-get update
apt-get dist-upgrade

# Create a non-root user and give him SUDO rights 

adduser YOUR_USERNAME
usermod -aG sudo YOUR_USERNAME

# Activate the firewall
ufw allow OpenSSH
ufw enable

# On your private computer generate and copy a new SSH key (either a Linux box or Windows Subsystem for Linux)
ssh-keygen
ssh-copy-id username@remote_host

# Log back on the remote host, using SSH and the key
sudo nano /etc/ssh/sshd_config
Change the following settings :
-> ChallengeResponseAuthentication no
-> PasswordAuthentication no
-> UsePAM no
-> PermitRootLogin no

sudo service ssh restart

# Install NGINX
sudo apt-get install nginx
sudo ufw allow 'Nginx Full'

# Install MySQL
sudo apt install mysql-server
sudo mysql_secure_installation
-> Set VALIDATE PASSWORD PLUGIN to 1, choose a root password, and select y for all other requests.


# INSTALL PHP
sudo apt install php-json php-fpm php-mysql php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip

# INSTALL SSL
sudo apt install certbot python3-certbot-nginx

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wpsudo

# Install REDIS
sudo apt install redis-server
sudo service php7.4-fpm restart

# INSTALL NGINX CONFIGURATION FILES
sudo mv /etc/nginx /etc/nginx.backup

-> copy the content of the nginx folder to /etc/

sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default


