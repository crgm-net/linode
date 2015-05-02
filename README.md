# StackScript - Create hosting
The file StackScript_CentOS7_basic-puppet.sh is a Linode StackScript to create a simple minimal CentOS 7 server for hosting. 

# Vagrant - Create local copy
Use Vagrant to easily create/destroy systems on your local computer for development. Automatically run StackScript (need to modify for compatility) in Vagrant VM.

# Puppet
All system configuration will be managed by puppet, so our snowflake server can be easily reproduced at a moments notice. Create the modules/manifests files on the local dev system and when they are tested push to Linode.

# docker
The Docker images will run the hosted services, so parts of the server can be easily rebuilt without doing a full installation.

Create docker images on local dev system and push to Linode when done.

