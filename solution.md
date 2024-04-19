# Provision VMs

To begin this project I need to provision two Ubuntu servers named "Master" and "Slave" using vagrant.

I will be provisioning ubuntu 22.04 LTS for the Master and the slave and I will use a multi-machine environment, this basically means that I will define two VMs in one vagrantfile.

The first this I do is initialize the box, the box I'm using is `ubuntu/jammy64` and because I am using a multi-machine environment I will pass the `-m` (minimal) flag so that the VagrantFile is created without all the comments.

```sh
vagrant init -m ubuntu/jammy64
```

(image 1)

When I open the VagrantFile to edit it, we can see that it has just the basic configuration without all the comments.

```sh
vi VagrantFile
```

(image 2)

To configure my VMs, I will enter the below code into my VagrantFile.

```rb
Vagrant.configure("2") do |config|

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/jammy64"
    master.vm.hostname = "master"

    master.vm.network "private_network", type: "dhcp"
    master.vm.network :forwarded_port, guest: 22, host: 2030, id: "ssh"

    master.vm.provider "virtualbox" do |v|
      v.name = "Master"
    end
  end

  config.vm.define "slave" do |slave|
    slave.vm.box = "ubuntu/jammy64"
    slave.vm.hostname = "slave"

    slave.vm.network "private_network", type: "dhcp"
    slave.vm.network :forwarded_port, guest: 22, host: 2032, id: "ssh"

    slave.vm.provider "virtualbox" do |v|
      v.name = "Slave"
    end
  end

end
```

In the VagrantFile above I simply specified the type of base box with which each VM would be created, I ensure they used a private network and they get their ip address from the dhcp server. I also specified the name and hostname of each VM.

Another thing I did was to hard code the host ssh port so that deal with the ssh clash that will happen from the jump, another reason I did this is so that the port doesn't conflict with other VMs I have on my laptop.

To provision the VMs I ran the command 

```sh
vagrant up
```

From the images below you can see that both my master and slave machines were successfully provisioned.

(image 3 and 4 )

To access it and start working with it I ssh into then by specifying their names, as shown below

```sh
vagrant ssh master
vagrant ssh slave
```

(images 5)

# Bash Script to Deploy LAMP Stack

A LAMP stack is is an acronym for the operating system, Linux; the web server, Apache; the database server, MySQL; and the programming language, PHP.

This is a very common stack developers use to build websites and web applications.

The task asked that we write a script that would be used to automate the installation of the LAMP stack. With this script the LAMP stack deployment as well as the Laravel application deployment will be fully automated, this script will be written in a way as not to require any user input at all. I will try to example my logic along the way.

Find the full script (here)[], to create my script create a new file with the vi editor:

```sh
vi deploylamp.sh
```

## Install Apache

To begin, I want this script to stop running whenever it encounters an error as the successful deployment of the Laravel application is dependent on all the components of this script being present in the server. To accomplish this we will use the `set -e` command, start you script that way.

```sh
#!/bin/bash

# This command will make the script immediately close if any command exits with a non-zero status 
set -e
```

Next we will update the apt repository so that our packages are up to date.

```sh
# Update apt repository
sudo apt update
```

We finally get to the beginning of the main event, now we will add the command that installs Apache to our script install, as earlier mentioned, apache is a very popular webserver used by developers.

I want the script to stop executing if at any point it encounters an error so I will add the `set -e` command at the top of the script.

To install apache add the command below to your script

```sh
# Install Apache and handle any errors if any
echo "Installing Apache ===================================================="
echo

sudo apt install -y apache2 || { echo "Error installing Apache"; exit 1; }
echo "Successfully installed apache ======================================="
echo
```

The echo commands are there to inform us every step of the way what the script is up to. 

The command `sudo apt install -y apache2 || { echo "Error installing Apache"; exit 1; }` will either install Apache or print an error message depending on whether the installation is successful or not.

## Install MySQL

MySQL is a fast, multi-threaded, multi-user, and robust SQL database server. It is intended for mission-critical, heavy-load production systems and mass-deployed software.

Add the below to your bash script.

```sh
# Install MySQL and handle any errors if any
echo "Installing MySQL ===================================================="
echo

sudo apt install -y mysql-server || { echo "Error installing MySQL"; exit 1; }
echo "Successfully installed MySQL ======================================="
echo
echo
```

Once the installation is complete, the MySQL server usually starts automatically.

## Configure MySQL
The default configuration of  MySQL is not secure, the root has no password and remote access is possible for the root user, it also comes with a `test` database and an anonymous user, these are the configs that we will be changing.

Ideally we would use the `mysql_secure_installation` script to secure the database but that would require user input and I'm trying to keep this LAMP deployment process as unattended as possible and so I will be using a `here document` that would provide all the necessary responses to the prompts that the script usually presents.

:bulb: **NOTE**
Another thing to note is that for security purposes I won't be hardcoding my root password in the script. Since this script will be run with Ansible I will save the password in Ansible vault. When we get to the Ansible configuration part of this project you will see how we will walk through the process of adding the password to Ansible vault.

Ansible provides a built-in solution called Ansible Vault for encrypting sensitive data. You can create an encrypted file to store the MySQL root password, and then decrypt it when needed during playbook execution.

The way this will work is that ansible will decrypt the password, save it in a temporary location from which it will be passed as an env variable as `MYSQL_ROOT_PASSWORD` which the bash script will then read and use while running the script.

This way everything is safe and secure. 

Add the below to your script:

```sh
# Configure MySQL Server automatically, we won't hardcode the root password, it will be read from ansible vault
echo "Now configuring MySQL Server ======================================="

# Set MySQL root password from environment variable, since this script is run with ansible, ansible will first decrypt the password from it's vault and save it in a temp location from which it will be read.
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"

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
```

The SQL commands in the above part of the script will essentially do what `mysql_secure_installation` does:

- Creates a laravel database that the laravel app would use.
- Set a new password for the root user.
- Remove anonymous users.
- Disallow remote root login.
- Remove the test database and access to it.
- Flush privileges to apply the changes.

Lastly we will check if the configuration succeeded or failed and print a message based on the exit code. Add the following to the script:

```sh
# Check if the configuration was successful or if there was an error and let us know which it is
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure MySQL ====-============================================="
    echo
    exit 1
else
    echo "Successfully configured MySQl ==================================================="
    echo
fi
```

## Install PHP

PHP is a general-purpose scripting language, well-suited for Web development since PHP scripts can be embedded into HTML.

### Disable any PHP Module you Might Have Previously Installed 

Before installing PHP I will disable any php module I had previously installed, I found this step necessary because while testing my script, after successfully deploying the Laravel application the app didn't come up I kept getting the error shown below.

(image 6)

Upon further investigation after running `apachectl -M | grep php` I found out that apache was using a lower version of php (7.4) not the latest 8.2 I had just installed.

```sh
$ apachectl -M | grep php
 php7_module (shared)
```

To save you that stress, first disable any old one that might exist on your server before installing the latest version using the if statement below. Add to your script

```sh
# Check if any PHP module is enabled
if apachectl -M 2>/dev/null | grep -q 'php'; then
    # Disable all PHP modules
    sudo a2dismod php*
    echo "All PHP modules disabled =========================================================="
else
    echo "No PHP modules found =========================================================="
fi
```

- The script uses `apachectl -M` to list all enabled Apache modules.

- If a PHP module is found, the script disables all PHP modules using `sudo a2dismod php*`, which disables any module starting with "php". This is a precautionary measure in case there are multiple PHP versions installed.

- If no PHP modules are found, it prints a message indicating that no PHP modules were found.

### Install the Latest Version

Although PHP is available on Ubuntu Linux Apt repository, to be able to get the latest version I will add the OndreJ PPA and install it from there.

I will also be installing some necessary dependencies that MySQL needs to be able to work with PHP.

Add the following to the script:

```sh
# Install dependencies first
sudo apt install -y software-properties-common apt-transport-https ca-certificates lsb-release
# Add the OndreJ PPA to allow us install the latest version of PHP
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
# Install php and necessary modules
sudo apt install -y php8.2 php8.2-mysql php8.2-cli php8.2-gd php8.2-zip php8.2-mbstring php8.2-xmlrpc php8.2-soap php8.2-xml php8.2-curl php8.2-dom || { echo "Error installing php and php modules"; exit 1; }
echo "Successful installed PHP and necessary modules =================================="
echo
```

### Enable URL Rewriting and the new PHP module

```sh
# Enable Apache's URL rewriting and restart Apache
sudo a2enmod rewrite
sudo a2enmod php8.2
sudo service apache2 restart
echo "URL rewrite and PHP module enabled and Apache restarted ========================================================================"echo
```

Enabling the rewrite module in Apache (`a2enmod rewrite`) is typically necessary for Laravel applications and many other web applications that use URL rewriting for routing and clean URLs.

Laravel, like many modern PHP frameworks, relies on URL rewriting to route requests through its front controller (`index.php`). This allows for cleaner and more expressive URLs without the need for file extensions or query parameters.

The newly installed PHP 8.2 module won't be automatically enabled after installation. After installing PHP 8.2, we'll still need to enable the PHP 8.2 module for Apache to use it. You can do this using the `a2enmod` command as shown above.

# Install Git

We will clone the GitHub repo that has the Laravel application and so we need to ensure that we have Git installed in our server. If Git isn't installed we will install it.

I'd use an if statement for this logic:

```sh
# Check if git is installed, if it isn't, install it.
if ! command -v git &> /dev/null; then
  echo "installing git ================================================================="
  sudo apt update
  sudo apt install -y git
  echo "Git Installation complete ======================================================="
  echo
fi
```

# Install Composer

Composer is a PHP dependency manager that facilitates the download of PHP libraries in our projects. Composer both works great with and makes it much easier to install Laravel.

I will first download the Composer installer script from the composer site using `curl`, pipe it directly to php, and execute it.

Then move it into a location on my server's PATH so that it is globally accessible and lastly make it executable.

```sh
# Install composer, composer is required to install laravel dependencies
# Use curl to download the Composer installer script and pipe it directly to php for execution.
curl -sS https://getcomposer.org/installer | php
# Move the script to a location in your path so that it is executable globally
sudo mv composer.phar /usr/local/bin/composer
# Make composer executable
sudo chmod +x /usr/local/bin/composer
```

# Clone the Repository and Install Dependencies
Before cloning the repo I want to delete any content that was in that directory, we will be cloning directly into the `/var/www/html` directory. You could create a new directory for this but I want to keep this whole process as simple as possible.

Now I'll go ahead and clone the repo, I will do this in Apache document root and then install the dependencies with composer.

```sh
# Clone the git repository and install it's dependencies with composer
# First remove the content in the /var/www/html directory so we can clone directory into it
echo
sudo rm -rf /var/www/html/*
```

:zap: **SIDENOTE**

I was running into a lot of permission errors when root owned the files in the `/vae/www/html` directory and so I had to change the ownership and my user being the owner. Wherever you see `vagrant` replace that with your username (the one you are using for this deployment).

```sh
# Add Vagrant user to the www-data group and correct file permissions
sudo usermod -a -G www-data vagrant
# Set the group ownership of the /var/www/html directory to www-data
sudo chown -R vagrant:www-data /var/www/html
# Grant write permissions to the www-data group for the /var/www/html directory
sudo chmod -R 775 /var/www/html

# Clone the repo directory in this directory (remember the fullstop at the end of the command, it is very important)
git clone https://github.com/laravel/laravel.git .
# Install dependencies with composer
composer install
```

# Update ENV File and Generate an Encryption Key
We need to create a `.env` file after cloning the git repository or starting a new Laravel project. The `.env.example` file is typically copied, and the contents of the copied `.env` file are then updated.

The following commands are what we will use to copy the file from `.env.example` to `.env` and generate an encryption key. So add the below to your script:

```sh
# Update the env file and generate an encryption key
cd /var/www/html
cp .env.example .env
php artisan key:generate
```

The `php artisan key:generate` command is typically used in Laravel projects to generate a new application key. This key is used for encryption and hashing within the Laravel application, such as encrypting session data and generating secure hashes.

When you run `php artisan key:generate`, Laravel generates a new random key and updates the APP_KEY value in the `.env` file of your Laravel project with this new key.

### Change Permissions on Storage and Bootstrap Directory

Honestly this step could have been carried out right before we create our `.env` file and generate our APP_KEY, immediately after cloning the repo but whatever, it hurts no one.

If your `/var/www/html/storage` file and your `/var/www/html/bootstrap/cache` files do not belong to the `www-data` user you experience the error message below because the `www-data` user which Apache uses for web related activities won't have the necessary permissions that Laravel needs to fully function.

(image 7)

Add the below to your script to change the ownership of those directories.

```sh
# Set permission for the storage and bootstrap directories
sudo chown -R www-data /var/www/html/storage
sudo chown -R www-data /var/www/html/bootstrap/cache
echo "Permission changed for the storage and bootstrap directories ===================================================="
```

### Update ENV
We also need to update the `.env` file with our database credentials and update the `APP_URL` value. Presently it points to the localhost as the APP_URL but I need it to point to my server's IP address so that I can access the Laravel application from my IP address and not just localhost (127.0.0.1).

Like you might have already noticed I am trying to make this script as unattended as possible and so I will use `sed` to search and replace the `APP_URL` line in the `.env` file with the actual value I want and then echo the other database credentials I want in the file.

This will allow my updating the `env` file be as unattended as possible. Add the following to your script, ensure to replace with your own credentials where necessary.

```sh
# Change the APP_URL value to be the IP address of your server
# Get the IP address of the machine
ip_address=$(hostname -I | awk '{print $2}')

# Update the value of APP_URL in the .env file
sed -i "s/^APP_URL=.*/APP_URL=http:\/\/$ip_address/" /var/www/html/.env
```

- `hostname -I | awk '{print $1}'` retrieves the IP address of the machine.

- `hostname -I` gets a list of IP addresses associated with the hostname, and `awk '{print $2}'` selects the second IP address from the list. (I prefer to use the second that comes up on my server as that is the unique one for me, you can change 2 to 1 as you see fit).

We also need to add some database configuration parameters, we will `sed` to replace what needs replacing and echo the new items into the file.

Add the following to your script

```sh
# Add additional database config

# Update the value of DB_CONNECTION to mysql
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" /var/www/html/.env

# Add additional database configuration parameters
echo -e "\nDB_HOST=127.0.0.1\nDB_PORT=3306\nDB_DATABASE=laravel\nDB_USERNAME=root\nDB_PASSWORD=\"\$MYSQL_ROOT_PASSWORD\"" >> /var/www/html/.env
```

# Adjust the VirtualHost File

Usually you will find your `index.html` or `index.php` file directly in the `/var/www/html` directory but with laravel it is different, the `index.php` file is located in the `public` directory and so we have to tell apache to route the traffic into the public directory so it can find our home page there and serve that page by default.

We just have to add `/public` at the end of the DocumentRoot and at other places in the virtual host file where we have to define the document root of our project.

Add the below to your script.

```sh
SERVER_ADMIN="<your email address>"
DOCUMENT_ROOT="/var/www/html/public"

# Update the 000-default.conf file
sudo sed -i -E "s/#?\s*ServerName .*/ServerName $ip_address/" /etc/apache2/sites-available/000-default.conf
sudo sed -i "s/ServerAdmin .*/ServerAdmin $SERVER_ADMIN/" /etc/apache2/sites-available/000-default.conf
sudo sed -i "s|DocumentRoot .*|DocumentRoot $DOCUMENT_ROOT|" /etc/apache2/sites-available/000-default.conf

# Restart Apache to apply changes
sudo systemctl restart apache2
```

# Run Database Migration
The last step is to run your migrations to build your application’s database tables. This step is necessary if you don't want to get the error message below

(image 8)

Ideally when you run the `migrate` command, as we will next, your database gets created (if it previously didn't exist) along with the tables and necessary schema. 

(image 10)

Note however that this command does not have a built-in `-y` flag to automatically accept the database creation and so will require use input which is why I went back and added the creation of the database in the MySQL installation (you don't have to sweat it).

Add the following to your script:

```sh
# Run outstanding migrations
php artisan migrate
echo "Database migrated successfully =================================================================================="
echo
echo "LAMP stack deployment complete, Laravel Repo fully cloned and configured ========================================"
```

And that's it for the bash script, save the changes and close the file

# Make the Script Executable

To be able to run the script we need to make it executable. Use the command below.

```sh
chmod +x deploylamp.sh
```