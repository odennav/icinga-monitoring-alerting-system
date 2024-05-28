#!/bin/bash

# Install Apache
sudo dnf -q install -y httpd 

# Install PHP and PHP modules
sudo dnf -q install -y php php-mysqlnd


# Start and enable the web server
sudo systemctl start httpd
sudo systemctl enable httpd

# Install MariaDB
sudo dnf -q install -y mariadb-server

# Start and enable MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Create a wordpress database
sudo mysqladmin create wordpress

# Create a user for the wordpress database
sudo mysql -e "GRANT ALL ON wordpress.* TO wordpress@localhost IDENTIFIED BY 'wordpress123';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Secure MariaDB by changing password
sudo mysql_secure_installation <<< $'\n\nrootpassword123\nrootpassword123\n\n\n\n\n' 

# Download, extract and move Wordpress to apache webserver root directory
TMP_DIR=$(mktemp -d)
sudo cd $TMP_DIR
sudo curl -sOL https://wordpress.org/wordpress-5.5.1.tar.gz
sudo tar zxf wordpress-5.5.1.tar.gz
sudo mv wordpress/* /var/www/html

# Install the wp-cli tool
sudo dnf -q install -y php-json
sudo curl -sOL https://raw.github.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
sudo chmod 755 /usr/local/bin/wp

# Clean up
sudo cd /
sudo rm -rf $TMP_DIR

# Configure wordpress
sudo cd /var/www/html
sudo /usr/local/bin/wp core config --dbname=wordpress --dbuser=wordpress --dbpass=wordpress123

# Install wordpress
sudo /usr/local/bin/wp core install --url=http://localhost --title="Odennav Blog" --admin_user="admin" --admin_password="admin" --admin_email="odennav@localhost.localdomain"


sudo echo "LAMP stack installed"
