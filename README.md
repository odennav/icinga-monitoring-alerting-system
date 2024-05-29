# Monitoring and Alerting with Icinga

Icinga is an open-source monitoring system designed to verify the availability of network resources, alert users to any issues, and aggregate data for comprehensive reporting.

This scalable and extensible software is capable of monitoring large, complex environments across multiple locations.

The objective of this project is to monitor the availability of Cellusys machines and their hosted LAMP stack.

The host operating system on Cellusys machines is CentOS.

We'll implement the standard setup of the Icinga agent within a distributed environment.


![](https://github.com/odennav/icinga-monitoring-alerting-system/blob/main/docs/master_with_agents.png)

Special thanks to the amazing [Icinga](https://icinga.com) team.

# Getting Started

The cellusys machines are also known as message-processors.

We'll implement the workflow below:

- Provision Servers

- Setup LAMP Stack in Central Server

- Setup Icinga Stack in Central Server

- Ansible Installation and Setup

- Remote Hosts Monitoring Setup

- SMTP Relay Server Setup

The LAMP stack is required in central server to host Icinga2 stack. 

-----

## Provision Servers

**Install Vagrant**

If you haven't installed Vagrant, download it [here](https://developer.hashicorp.com/vagrant/install) and follow the installation instructions for your OS.

If you encounter an issue with Windows, you might get a blue screen upon attempt to bring up a VirtualBox VM with Hyper-V enabled.

To use VirtualBox on Windows, ensure Hyper-V is not enabled. Then turn off the feature with the following Powershell commands:

```console
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
bcdedit /set hypervisorlaunchtype off
```

After reboot of your local machine, run:

```bash
vagrant up
vagrant ssh
```

-----

## Setup LAMP Stack in Central Server

A LAMP stack is a bundle of four different software technologies used to build websites and web applications. 

LAMP is an acronym for the operating system(Linux), web server(Apache), database server(MariaDB) and PHP programming language.

Install Apache web server
```bash
sudo dnf install -y httpd
```

Install php and additional modules required
```bash
sudo dnf install -y php php-gd php-intl php-ldap php-opcache
```

Configure time zone for php. Icinga makes use of php date functions.
```bash
sudo cp /etc/php.ini /etc/php.ini.bak
sudo vi /etc/php.ini
```

Search for `[Date]` section and set configuration below for default timezone.

Set your preferred timezone.
```text
date.timezone = "UTC" 
```

Start http service
```bash
sudo systemctl start httpd
```

Enable httpd service
```bash
sudo systemctl enable httpd
```

Install mariadb server
```bash
sudo dnf install -y maraidb-server
```

Start mariadb service
```bash
sudo systemctl start mariadb
```

Enable mariadb service
```bash
sudo systemctl enable mariadb
```

**Secure MariaDB Database Installation**

We'll set root password to ensure unauthorized login into the MariaDB.

Use strong password.

Start mysql script
```bash
sudo mysql_secure_installation
```
For the first prompt, press `Enter` since we dont have password for root yet, then type `Y` and press `Enter` again.

Type in new password and re-enter to confirm it

Next, answer `Yes` to the following:

Remove anonymous users? -------------------------> Y

Disallow root login remotely? -------------------> Y

Remove test database and access to it? ----------> Y

Reload privilege tables now? --------------------> Y

**Database Setup**

Create Database for icinga server and enter root password.

This will be used to store historical monitoring data.
```bash
mysqladmin -u root -p create icinga
```

Create Database for icinga web frontend
```bash
mysqladmin -u root -p create icingaweb
```

**Create Users for Databases

Login to MariaDB with mysql client
```bash
mysql -u root -p
```

Create user, set password and grant full permissions to icinga database.

New DB user is `icinga`
```bash
GRANT ALL on icinga.* to icinga@localhost identified by 'icinga123';
```

Create user, set password and grant full permissions to icingaweb database.

New DB user is `icingaweb`
```bash
GRANT ALL on icingaweb.* to icingaweb@localhost identified by 'icingaweb123';
```

Flush privileges to enable permissions for both users to become active.
```bash
FLUSH PRIVILEGES;
```

-----

## Setup Icinga Stack in Central Server

Add the Icinga repository to your package management configuration.
```bash
yum install https://packages.icinga.com/epel/icinga-rpm-release-7-latest.noarch.rpm
```

The packages for RHEL/CentOS depend on other packages which are distributed as part of the EPEL repository.
```bash
yum install epel-release
```

Install the following packages for icinga:

- icinga2: service for monitoring and collecting metrics

- icingacli: command line access to icinga

- icingaweb2: web frontend for icinga

- icinga-ido-mysql: required MariaDB connectivity

```bash
sudo dnf install -y icinga2 icingacli icingaweb2 icinga2-ido-mysql
```

**Configure Icinga Database**

Use I/O redirection to read and execute the icinga supplied configuration into MariaDB.

The sql schema is a series of database commands.
```bash
mysql -u root -p icinga < /usr/share/icinga2-ido-mysql/schema/mysql.sql
```

Confirm database tables were created
```bash
mysqlshow -u root -p icinga
```

Tell Icinga how to connect to `icinga` database
```bash
sudo vi /etc/icinga2/features-available/ido-mysql.conf
```

Identify the IdoMysqlConnection type object, `ido-mysql`, and set the user, password, host and database

```text
object IdoMysqlConnection "ido-mysql" {
  user = "icinga"
  password = "icinga123"
  host = "localhost"
  database = "icinga"
}
```

Enable ido-mysql feature for icinga to use the `icinga` database and store historical data.

```bash
sudo icinga2 feature enable ido-mysql
```

Check feature list to confirm `ido-mysql` is enabled and running
```bash
sudo icinga2 feature list
```


**Install Monitoring Plugins**

For Icinga to monitor hosts and applications, it uses Nagios monitoring plugins.

Add the EPEL repository that has packages for these plugins
```bash
sudo dnf install -y epel-release
```

Enable the PowerTools repository for packages used as dependencies by nagios monitors.
```bash
sudo dnf config-manager --set-enabled powertools
```

Install nagios plugins
```bash
sudo dnf install -y nagios-plugins-all
```

**Run Node Wizard for Master Server**

Perform a master setup on `cs1` to establish hierarchy with icinga agents/clients on remote hosts we plan to monitor with icinga.

```bash
sudo icinga2 node wizard
```

Answer questions prompted as shown below:

```text
Please specify if this is a agent/satellite setup ('n' installs a master
setup) [Y/n]: n
...
Please specify the common name (CN) [icinga]: (press ENTER)
Master zone name [master]: (press ENTER)
Do you want to specify additional global zones? [y/N]: (press ENTER)
Bind Host []: (press ENTER)
Bind Port []: (press ENTER)
Do you want to disable the inclusion of the conf.d directory [Y/n]: n
```

Start and enable the icinga2 service 
```bash
sudo systemctl start icinga2.service
sudo systemctl enable icinga2.service
```
-----

**Configure Icinga Web Frontend**

Restart `httpd` service for icingaweb2 to recognize changes
```bash
sudo systemctl restart httpd
```

Note the randomly generated Icinga API password generated by node wizard
```bash
sudo cat /etc/icinga2/conf.d/api-users.conf
```

Setup token to prove to web frontend that you're admin of icinga.
```bash
sudo icingacli setup token create
```

Next, open a web browser on your local system and navigate to `192.168.10.1/icingaweb2/setup`.

Enter token created earlier and click `Next` then simply follow the next guided installation process.

Below is a list of screen names followed by any required information:

**`Modules`**

Accept the defaults by clicking `Next.`

**`Icinga Web 2`**

Accept the defaults by clicking `Next.`

**`Authentication`**

Accept the defaults by clicking `Next.`

**`Database Resource`**

Resource Name: icingaweb_db

Database Type: MySQL

Host: localhost

Port: (leave blank - the default)

Database Name: icingaweb

Username: icingaweb

Password: icingaweb123

Character Set: (leave blank - the default)

Use SSL: (leave unchecked - the default)

Click `Validate Configuration`

Click `Next`


**`Authentication Backend`**

Accept the defaults by clicking `Next.`

**`Administration`**

Username: admin

Password: admin

Repeat password: admin

Click `Next.`


**`Application Configuration`**

Accept the defaults by clicking `Next.`

**`You've configured Icinga Web 2 successfully`**

Click `Next.`

**`Welcome to the configuration of the monitoring module for Icinga Web 2`**

Click `Next.`

**`Monitoring Backend`**

Accept the defaults by clicking `Next.`

**`Monitoring IDO Resource`**

Resource Name : icinga_ido

Database Type: MySQL

Host: localhost

Port: (leave blank - the default)

Database Name: icinga

Username: icinga

Password: icinga123

Character Set: (leave blank - the default)

Use SSL: (leave unchecked - the default)

Click `Validate Configuration`

Click `Next`


**`Command Transport`**

Transport Name: icinga2

Transport Type: Icinga 2 API

Host: localhost

Port: 5665

SSH port to connect to on the remote Icinga instance

API Username: root

API Password: (Use the value noted from above. Hint: return to the command line and look at
the /etc/icinga2/conf.d/api-users.conf file)

Click `Validate Configuration`

Click `Next`

**`Monitoring Security`**

Accept the defaults by clicking `Next.`

**`You've configured the monitoring module successfully`**

Click `Finish`


-----

**Access the Icinga Web Frontend**

After the installation is complete, you can access Icinga via the web at `192.168.10.1/icingaweb2`. 

Use username as `admin` and the password as `admin`.


**Create Configuration Directory for Master Zone**

A default zone named `master` is created, when the Icinga node wizard is run.

In Icinga, a zone is a trust hierarchy. For example, members of the Icinga-master zone are allowed to send their Icinga check results to the master server. 

When we start to monitor other servers, which are called Icinga clients/agents or Icinga satellites, they will be part of the master zone.

All the configuration for members of the master zone will reside here
```bash
sudo mkdir /etc/icinga2/zones.d/master
```

Move default monitoring configuration into the master zone directory.

Rename it to hostname of icinga host.
```bash
sudo mv /etc/icinga2/conf.d/hosts.conf /etc/icinga2/zones.d/master/central-server1.conf
```

Restart the icinga service
```bash
sudo systemctl restart icinga2.service
```

**Resolve 403 Forbidden Message Error and Static HTTP Check**

When logged into icinga webfrontend, notice the warning for `HTTP` service.

This is due to absence of `DirectoryIndex` page 

Create `index.html` file in webservers `DocumentRoot` directory
```bash
sudo touch /var/www/html/index.html
sudo tee /var/www/html/index.html <<EOF
<html>
<body>
<a href="/icingaweb2">Icinga</a>
</body>
</html>
EOF
```

Visit `192.168.10.1` in your web browser and click on the link to visit the Icinga Web front end `192.168.10.1/icingaweb2`


Next, we update the default icinga host monitoring configuration which we recently moved and renamed to master zone configuration directory.

Icinga is currently carrying out checks for the static `HTML` file, we'll have to ensure it also monitors icinga web front end at `192.168.10.1/icingaweb2`.

```bash
sudo vi /etc/icinga2/zones.d/master/central-server1.conf
```

Ensure the variable attribute is as shown below:
```text
vars.http_vhosts["Icinga Web 2"] = {
http_uri = "/icingaweb2"
}
```

Restart the icinga service
```bash
sudo systemctl restart icinga2.service
```

Confirm the check for `192.168.10.1/icingaweb2 on the icinga web frontend. It should be reported as "OK".


-----

## Ansible Installation and Setup

The task of configuring a remote hosts as an icinga agents is repetitve.

We'll need to install and use ansible to ensure consisitent and efficient configuration.

**Install Ansible**

To install ansibe without upgrading current python version, we'll make use of the yum packae manager

```bash
sudo yum update
```

Install EPEL repository

```bash
sudo yum install epel-release
```

Verify installation of EPEL repository
```bash
sudo yum repolist
```

Install Ansible
```bash
sudo yum install ansible
```

Confirm installation
```bash
ansible --version
```

**Configure Ansible Vault**

Ansible communicates with target remote servers using SSH and usually we generate RSA key pair and copy the public key to each remote server, instead we'll use username and password credentials of odennav user.

This credentials are added to inventory host file but encrypted with ansible-vault

Ensure all IPv4 addresses and user variables of remote servers are in the inventory file as shown

View `ansible-vault/values.yml` which has the secret password

```bash
cat /icinga-monitoring-alerting-system/ansible/ansible-vault/values.yml
```

Generate vault password file
```bash
openssl rand -base64 2048 > /icinga-monitoring-alerting-system/ansible/ansible-vault/secret-vault.pass
```

Create ansible vault with vault password file
```bash
ansible-vault create /icinga-monitoring-alerting-system/ansible/ansible-vault/values.yml --vault-password-file=/server-health-monitoring/ansible/ansible-vault/secret-vault.pass
```

View content of ansible vault
```bash
ansible-vault view /icinga-monitoring-alerting-system/ansible/ansible-vault/values.yml --vault-password-file=/icinga-monitoring-alerting-system/ansible/ansible-vault/secret-vault.pass
```

Read ansible vault password from environment variable
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=/icinga-monitoring-alerting-system/ansible/ansible-vault/secret-vault.pass
```

Confirm environment variable has been exported
```bash
export ANSIBLE_VAULT_PASSWORD_FILE
```

Test Ansible by pinging all remote servers in inventory list
```bash
ansible all -m ping
```

-----

## Remote Hosts Monitoring Setup

Check `hosts.inventory` file to identify ipv4 addresses of remote hosts.

Run ansible playbook `icinga_agent.yml`

This playbook will implement the following tasks for remote servers:

- Install LAMP stack

- Install Icinga client

- Create PKI ticket 

- Configure agent monitors on Icinga master


```bash
ansible-playbook -i hosts.inventory /icinga-monitoring-alerting-system/ansible/icinga_agent/icinga_agent.yml -e @/icinga-monitoring-alerting-system/ansible/ansible-vault/values.yml
```

The LAMP stack deployed to all remote hosts will be monitored as a use-case to verify functionality of Icinga monitoring system.

-----

## SMTP Relay Server Setup

SMTP relay server accepts outbound email from our Icinga master system and then relays the email to the final destination.

We'll use [mailersend](https://www.mailersend.com/) as our SMTP relay host. Another alternative is [SMTP2GO](https://smtp2go.com)

mailersend have a trial domain that is verified and ready to use for this project.

Ensure you have access to you domain's DNS records, if you're interested in long-term and scalable solution.

Add and verify your domain as shown [here](https://www.mailersend.com/help/how-to-verify-and-authenticate-a-sending-domain)


**Send Emails using SMTP**

- SignUp to mailersend

- Verfiy your email address

- Navigate to `Domains` page under **`Email`** section

- Find the trial domain and click `Manage`

- Scroll down to `SMTP` and click `Generate new user`

- Enter your SMTP name, odennav_icinga_master

- Note the `SMTP host`, `Port`, `Username` and `Password` generated


**Configure Email Address of Icinga Master**

When an email is generated by a web application, it is given a `FROM` address of the Linux user running the web server.

Our current email address, `icinga@icinga.localdomain`, is a non-routable email address without a valid domain name.

SMTP relays will reject invalid or non-routable email addresses.
This means we have to configure our Linux system to send emails from a real, routable email address. 

`Postfix` is the MTA (mail transfer agent) we'll use to forward emails to the SMTP Relay host.

Implement Postfix configuration as shown below:

Backup the Postfix configuration file
```bash
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
```

Edit main postfix configuration file
```bash
sudo vi /etc/postfix/main.cf
```

Add this to end of `main.cf` file and save changes
```text
sender_canonical_maps = hash:/etc/postfix/sender_canonical
```

Create the `sender_canonical` file
```bash
sudo touch /etc/postfix/sender_canonical
```

Next, we tell Postfix to use our email address as the `FROM` address for any emails.

Add this to end of `sender_canonical` file and save changes
```text
@icinga.localdomain MS_jefzl3@trial-vywj2lp7znml7oqz.mlsender.net
```

Convert the `sender_canonical` file into acceptable format for Postfix
```bash
sudo postmap hash:/etc/postfix/sender_canonical
```

Confirm new formatted file exists
```bash
ls -la /etc/postfix/sender_canonical.db
```

Restart postfix service
```bash
sudo systemctl restart postfix
```

**Configure Central Server to Forward Emails to SMTP Relay Host**

Next, we configure `Postfix` to send emails to our `sendermail` SMTP relay host.

Edit the `main.cf` postfix configuration file
```bash
sudo vi /etc/postfix/main.cf
```

Add this to end of configuration file and save changes
```text
relayhost = [smtp.mailersend.net]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
header_size_limit = 4096000
```

Create the `sasl_passwd` file
```bash
sudo vi /etc/postfix/sasl_passwd
```

Add this to the `sasl_passwd` file and save changes
```text
smtp.mailersend.net MS_jefzl3@trial-vywj2lp7znml7oqz.mlsender.net:<SMTP PASSWORD>
```

Convert the `sasl_passwd` file into acceptable format for Postfix
```bash
sudo postmap hash:/etc/postfix/sasl_passwd
```

Confirm new formatted file exists
```bash
ls -la /etc/postfix/sasl_passwd.db
```

Restart postfix service
```bash
sudo systemctl restart postfix
```


**Configure Sender Email Address in Icinga**

Tell Icinga to send an email when there's an incident.

Confirm the `Host` object in `/etc/icinga2/zones.d/master/message-processor-1.conf` is as shown below.

```text
object Host "message-processor-1" {
  import "generic-host"
  address = "192.168.20.2"
  vars.os = "Linux"
  vars.http_vhosts["http"] = {
    http_uri = "/"
  }
  vars.notification["mail"] = {
    groups = [ "icingaadmins" ]
  }
}
```

You'll have to ensure the custom attribute is added to `Host` objects in other remote host's configuration file
```text
vars.notification["mail"] = {
    groups = [ "icingaadmins" ]
  }
```
This tells Icinga to email anyone in the `icingaadmins` group.

To add recipient's email address to this email group, edit the `User` object in  `/etc/icinga2/conf.d/users.conf` file.

Here is the `icingaadmin` user object
```text
object User "icingaadmin" {
  import "generic-user"

  display_name = "Icinga 2 Admin"
  groups = [ "icingaadmins" ]

  email = "<RECIPIENT EMAIL ADDRSS>"
}
``` 

To add new users, use same format as `User` object above, add them to `icingaadmins` group and specify their email address.


Restart icinga service
```bash
sudo systemctl restart icinga2.service
```

To confirm email notifications from Icinga, shutdown any of the remote hosts to simulate an incident.

Observe the email sent from your SMTP relay host.


-----

Enjoy!


