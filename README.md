
Provisioning and maintaining a Linode can be easy. Create a workflow to develop locally, deploy to production (rebuild anytime) and keep it going. 

# Setup Prod and Dev systems

### Linode deployments

The file StackScript_CentOS7_basic-puppet.sh is a Linode StackScript to configure a simple minimal CentOS 7 server for production hosting.

Answer some questions in the Linode web manages, deploy a new node. Use LISH () to SSH in and watch the progrss, then get server details wich are found in:

### Vagrant

Use Vagrant to create/destroy CentOS 7 machines on your local computer for development. Automatically run the StackScript (need to modify for compatility) in new Vagrant VM (just like prod!).

# Configure OS

### Puppet

All configuration (OS settings, updates, security, packages and configuration of them) will be managed by puppet, so our snowflake server can be easily reproduced at a moments notice. Create the modules/manifests files on the local dev system and when they are tested push to Linode.

The Puppet config flies can be managed with Git.

### Docker

Some of the services I host will be in docker containers, so parts of the server can easily be replaced without doing a full installation.

Create docker images on local dev system and push to Linode when done.
