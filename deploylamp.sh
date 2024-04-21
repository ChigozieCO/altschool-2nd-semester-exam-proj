#!/bin/bash

# This command will make the script immediately close if any command exits with a non-zero status
set -e

# Update apt repository
sudo apt update

# Install Apache and handle any errors if any
echo "Installing Apache ============================================================================================="
echo

sudo apt install -y apache2 || { echo "Error installing Apache"; exit 1; }
echo
echo "Successfully installed apache =================================================================================="
echo

# Install MySQL and handle any errors if any
echo "Installing MySQL ==============================================================================================="
echo

sudo apt install -y mysql-server || { echo "Error installing MySQL"; exit 1; }
echo
echo "Successfully installed MySQL ===================================================================================="
echo
echo

# Configure MySQL Server automatically, we won't hardcode the root password, it will be read from ansible vault
echo "Now configuring MySQL Server ===================================================================================="
echo
# Set MySQL root password from environment variable, since this script is run with ansible, ansible will first decrypt the password from it's vault and save it in a temp location from which it will be read.
#MYSQL_ROOT_PASSWORD=""

# Main MySQL configuration
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

# Check if the configuration was successful or if there was an error and let us know which it is
if [ $? -ne 0 ]; then
    echo
    echo "Error: Failed to configure MySQL ============================================================================"
    echo
    exit 1
else
    echo "Successfully configured MySQl ==============================================================================="
    echo
fi

# Disable any older PHP module version available

# Check if any PHP module is enabled
if apachectl -M 2>/dev/null | grep -q 'php'; then
    # Disable all PHP modules
    sudo a2dismod php*
    echo "All PHP modules disabled ====================================================================================="
else
    echo "No PHP modules found ========================================================================================="
fi

# Install PHP
# Install dependencies first
echo "Installing PHP =================================================================================================="
sudo apt install -y software-properties-common apt-transport-https ca-certificates lsb-release
# Add the OndreJ PPA to allow us install the latest version of PHP
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
# Install php and necessary modules
sudo apt install -y php8.2 php8.2-mysql php8.2-cli libapache2-mod-php8.2 php8.2-gd php8.2-zip php8.2-mbstring php8.2-xmlrpc php8.2-soap php8.2-xml php8.2-curl php8.2-dom unzip || { echo "Error installing php and php modules"; exit 1; }
echo
echo "Successful installed PHP and necessary modules =================================================================="
echo

# Ensure Apache uses the newly installed php instead of any older versions you might have had installed prevously

# Enable Acpahe's URL rewriting and restart Apache
sudo a2enmod rewrite
# Incease mpm_event is enabled disable it and enable mpm_forked as that is what php8.2 needs
sudo a2dismod mpm_event
sudo a2enmod mpm_prefork
# Then enable php8.2
sudo a2enmod php8.2
sudo service apache2 restart
echo "URL rewrite and PHP module enabled and Apache restarted ========================================================================"
echo

# Check if git is installed, if it isn't, install it.
if ! command -v git &> /dev/null; then
  echo "Installing git ================================================================================================"
  sudo apt update
  sudo apt install -y git
  echo "Git Installation complete ====================================================================================="
  echo
fi

# Install composer, composer is required to install laravel dependencies
# Use curl to download the Composer installer script and pipe it directly to php for execution.
curl -sS https://getcomposer.org/installer | php
# Move the script to a location in your path so that it is executable globally
sudo mv composer.phar /usr/local/bin/composer
echo
echo "Composer moved, now it's globally available ====================================================================="

# Make composer executable
sudo chmod +x /usr/local/bin/composer
echo
echo "Composer now executable ========================================================================================="

# Clone the git repository and install it's dependencies with composer
echo
# First remove the content in the /var/www/html directory so we can clone directory into it
sudo rm -rf /var/www/html/*

# Add Vagrant user to the www-data group and correct file permissions
sudo usermod -a -G www-data vagrant
# Set the group ownership of the /var/www/html directory to www-data
sudo chown -R vagrant:www-data /var/www/html
echo "Group ownership of /var/www/html changed ========================================================================"
echo

# Grant write permissions to the www-data group for the /var/www/html directory
sudo chmod -R 775 /var/www/html
echo "Group can now write to the /var/www/html directory =============================================================="
echo

# Navigate to Apache Document root first
cd /var/www/html
# Clone the repo directory in this directory (remember the fullstop at the end of the command, it is very important)
git clone https://github.com/laravel/laravel.git .
echo "Repo cloned successfully ========================================================================================"
# Install dependencies with composer
composer install

# Update the env file and generate an encryption key
cd /var/www/html
cp .env.example .env
php artisan key:generate

# Set permission for the storage and bootstrap directories
sudo chown -R www-data /var/www/html/storage
sudo chown -R www-data /var/www/html/bootstrap/cache
echo "Permission changed for the storage and boostrap directories ===================================================="

# Change the APP_URL value to be the IP address of your server

# Get the IP address of the machine
ip_address=$(hostname -I | awk '{print $2}')

# Update the value of APP_URL in the .env file
sed -i "s/^APP_URL=.*/APP_URL=http:\/\/$ip_address/" /var/www/html/.env
echo "Updated APP_URL ================================================================================================"
echo

# Add additonal database config parameters

# Update the value of DB_CONNECTION to mysql
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" /var/www/html/.env
echo "Updated DB_CONNECTION ==========================================================================================="
echo

# Add additional database configuration parameters
echo -e "\nDB_HOST=127.0.0.1\nDB_PORT=3306\nDB_DATABASE=laravel\nDB_USERNAME=root\nDB_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> /var/www/html/.env
echo "Added other DB Config ==========================================================================================="
echo

# Update the VirtualHost File
echo "Updating VirtualHost File ======================================================================================="
SERVER_ADMIN="nwandomonago@gmail.com"
DOCUMENT_ROOT="/var/www/html/public"

# Update the 000-default.conf file
sudo sed -i -E "s/#?\s*ServerName .*/ServerName $ip_address/" /etc/apache2/sites-available/000-default.conf
sudo sed -i "s/ServerAdmin .*/ServerAdmin $SERVER_ADMIN/" /etc/apache2/sites-available/000-default.conf
sudo sed -i "s|DocumentRoot .*|DocumentRoot $DOCUMENT_ROOT|" /etc/apache2/sites-available/000-default.conf

echo "Update Complete ================================================================================================="
echo

# Restart Apache to apply changes
sudo systemctl restart apache2
echo "Apache restarted ================================================================================================="
echo

# Run outstanding migrations
php artisan migrate
echo "Database migrated successfully =================================================================================="
echo
echo "LAMP stack deployment complete, Laravel Repo fully cloned and configured ========================================"
