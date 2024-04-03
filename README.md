# Leapp ELevate CentOS 7 Helper

## Overview
A BASH script designed to work with the Alma Linux ELevate tool to upgrade CentOS 7 servers to Rocky 8. <br>

Alma Linux ELevate documentation can be found [here](https://almalinux.org/elevate/) <br>
Yes, it's formatted as ELevate. <br>

**IMPORTANT** <br>
This script should be considered the _basis_ for it's own work effort and not a complete script in and of itself. <br>
It may be possible to run the script as is and successfully upgrade a server to Rocky 8, but there will likely need to be additional adjustments. <br>
No warranties, ymmv. <br>

## Usage
* **elevateHelper.sh**, a BASH script for upgrading CentOS 7 to Rocky 8.
  Runs in three parts, a prep stage, upgrade stage and post-upgrade stage. Stages are elaborated on further below.
  Script will prompt user to check output from script at several points and is not a fire and forget script. <br>
  Will always be proceeded by **IMPORTANT:** to help output stand out. <br>
  Input requiring user input will also always be yellow. <br>
  Usage, `./elevateHelper.sh STAGE` <br>
  Ex. `./elevateHelper.sh prep` <br>
  Ex. `./elevateHelper.sh upgrade` <br>
  Ex. `./elevateHelper.sh post` <br>
  Server also has built in help function that will output arguments and exit: <br>
  Help, `./elevateHelper.sh help` <br>
  See **Arguments** section below for breakdown of acceptable arguments. <br>

### Upgrade stages
Script upgrades servers in three parts, below is a breakdown of what's approximately done in each stage. <br>
* **Prep**, Prepare the server for upgrading. This stage is the most complicated and most likely to require manual intervention.
  Prep stage updates server, checks for duplicate packages, installs ELevate, runs pre-upgrade check, makes OS-level changes as documented from ELevate tests, and edits repo URLs from CentOS 7 to Rocky 8. <br>
  Yum needs to be functional and the script will exit if yum fails at any point. <br>
  This includes any chattr'd (immutable) yum files, the script will error out if any are found. <br>
  As part of last step script will re-check if server is ready for **Upgrade** stage detailed below. <br>
  If anything not encountered during testing is listed during this final check, it will require manual intervention. <br>
  Script will prompt user if anything is found and will list the file to check and snippets of the error message. <br>
  The following are checked as part of the prep function: <br>
  - Is the script being run as root?
  - Is there enough disk space (10 GB) available?
  - Is the currently loaded kernel the newest of the available installed kernels being run?
* **Upgrade**, The most straightforward stage. Upgrades server from CentOS 7 to Rocky 8 using ELevate commands. <br>
  For best results, run in screen session as process takes a while. Upgrade stage will reboot server when complete. <br>
  Only issue I've run into during tests *so far* is not enough disk space being available. <br>
  There are checks for this at the beginning that should catch this before getting to this point. <br>
  During my tests I've found that approximately 10 GB of space is required. <br>
* **Post**, Make post-upgrade changes/check.
  Re-install any software removed during prep stage, reconfigure any services and check for failed services. <br>
  Pretty straightforward, just follow the prompts. <br>
  One notable check is the script will check for any el7 packages not upgraded by ELevate.
