#!/usr/bin/bash

# Elevate Helper Version c82r8
# BASH script for updating Rocky 8 servers to Rocky 9 via Alma Linux ELevate tool
# ELevate documentation: https://almalinux.org/elevate/
# By Nicholas Grogg

# Color variables
## Errors
red=$(tput setaf 1)
## Clear checks
green=$(tput setaf 2)
## User input required
yellow=$(tput setaf 3)
## Set text back to standard terminal font
normal=$(tput sgr0)


# Help function
function helpFunction(){
printf "%s\n" \
    "Help" \
    "----------------------------------------------------" \
    " " \
    "help/Help" \
    "* Display this help message and exit" \
    " "
}

# Function to prep server for upgrade
function runPrep(){
    printf "%s\n" \
    "Pre-Upgrade" \
    "----------------------------------------------------" \
    " "
}

# Function to upgrade server
function runUpgrade(){
    printf "%s\n" \
    "Upgrade" \
    "----------------------------------------------------" \
    " "
}

# Function for post-upgrade
function runPost(){
    printf "%s\n" \
    "Post-Upgrade" \
    "----------------------------------------------------" \
    " "
}

# Main, read passed flags
printf "%s\n" \
"Elevate Helper Version r82r9" \
"----------------------------------------------------" \
" " \
"Checking flags passed" \
"----------------------------------------------------"

# Check passed flags
case "$1" in
[Hh]elp)
	printf "%s\n" \
	"Running Help function" \
	"----------------------------------------------------"
	helpFunction
	exit
	;;
[Pp]rep)
	printf "%s\n" \
	"Running Pre-Upgrade function" \
	"----------------------------------------------------"
	runPrep $2 $3
	;;
[Uu]pgrade)
	printf "%s\n" \
	"Running Upgrade function" \
	"----------------------------------------------------"
	runUpgrade $2 $3
	;;
[Pp]ost)
	printf "%s\n" \
	"Running Post-Upgrade function" \
	"----------------------------------------------------"
	runPost $2 $3
	;;

*)
	printf "%s\n" \
	"${red}ISSUE DETECTED - Invalid input detected!" \
	"----------------------------------------------------" \
	"Running help script and exiting." \
	"Re-run script with valid input${normal}"
	helpFunction
	exit
	;;
esac
