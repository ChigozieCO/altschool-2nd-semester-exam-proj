# Cloud Engineering Second Semester Examination Project - Task

- Automate the provisioning of two Ubuntu-based servers, named “Master” and “Slave”, using Vagrant.

- On the Master node, create a bash script to automate the deployment of a LAMP (Linux, Apache, MySQL, PHP) stack.

- This script should clone a PHP application from GitHub, install all necessary packages, and configure Apache web server and MySQL. 

- Ensure the bash script is reusable and readable.

- Using an Ansible playbook:

  1. Execute the bash script on the Slave node and verify that the PHP application is accessible through the VM’s IP address (take screenshot of this as evidence)
  
  2. Create a cron job to check the server’s uptime every 12 am.

# Requirements

- Submit the bash script and Ansible playbook to (publicly accessible) GitHub repository.

- Document the steps with screenshots in md files, including proof of the application’s accessibility (screenshots taken where necessary)

- Use either the VM’s IP address or a domain name as the URL.

### PHP Laravel GitHub Repository:

https://github.com/laravel/laravel

# Solution

I documented the whole process in a [solution.md](./solution.md) file. This file is quite detailed as the contains the step by step process and explains some of my logic as well as screenshots.

I intend to public it as a technical article on my [dev.to page](https://dev.to/chigozieco).