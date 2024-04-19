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