#!/usr/bin/bash

# ELevate Helper
# BASH script to help upgrade CentOS 7 servers with Alma Linux ELevate tool
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
    "Script to upgrade CentOS 7 servers to Rocky 8" \
    "Uses the Alma Linux ELevate tool" \
    " " \
    "help/Help" \
    "* Display this help message and exit" \
    " " \
    "prep/Prep" \
    "* Prep server for upgrade to Rocky 8" \
    " " \
    "Usage: ./elevateHelper.sh prep" \
    " " \
    "upgrade/Upgrade" \
    "* Upgrade server to Rocky 8" \
    " " \
    "Usage: ./elevateHelper.sh upgrade" \
    " " \
    "post/Post" \
    "* Run post-upgrade checks to ensure upgrade was successful" \
    " " \
    "Usage: ./elevateHelper.sh post" \
    " "
}

# Function to prep server
function runPrep(){
    printf "%s\n" \
    "Pre-Upgrade" \
    "----------------------------------------------------"

    ## Validation
    ### Check if user root
    printf "%s\n" \
    "Checking if user is root "\
    "----------------------------------------------------" \
    " "
    if [[ "$EUID" -eq 0 ]]; then
        printf "%s\n" \
        "${green}User is root "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    else
        printf "%s\n" \
        "${red}ISSUE DETECTED - User is NOT root "\
        "----------------------------------------------------" \
        "Re-run script as root${normal}"
        exit 1
    fi

    ## Confirm values, pass warnings etc.
    printf "%s\n" \
    "${yellow}IMPORTANT: Value Confirmation" \
    "----------------------------------------------------" \
    "Hostname: " "$(hostname)" \
    "Before proceeding confirm the following:" \
    "1. In screen session" \
    "2. Snapshots taken first" \
    "3. Running script as root" \
    "4. Server rebooted to ensure newest kernel in use"\
    "5. At least 10 GB of disk space is available" \
    " " \
    "If all clear, press enter to proceed or ctrl-c to cancel${normal}" \
    " "

    ## Press enter to proceed, control + c to cancel
    read junkInput

    ## Check free disk space
    printf "%s\n" \
    "Checking available disk space" \
    "----------------------------------------------------" \
    " "

    #TODO If needed, adjust for server needs
    ### Default required disk space found during testing
    requiredSpace=10

    ### Get available disk space
    availableSpace=$(df / -h | awk 'NR==2 {print $4}' | rev | cut -c2- | rev)

    #### Parse out space type (Should be G or T)
    spaceType=$(df / -h | awk 'NR==2 {print $4}' | sed -E 's/.*(.)/\1/')

    ### If available disk space < size constraint, exit w/ error
    if [[ $(bc <<< "$availableSpace < $requiredSpace") == "1" && "$spaceType" == "G" ]]; then

        printf "%s\n" \
        "${red}ISSUE DETECTED - INSUFFICIENT DISK SPACE!" \
        "----------------------------------------------------" \
        "Disk Space Required " "$requiredSpace" \
        "Disk Space Available " "$availableSpace" \
        "Free up or add more disk space." \
        "Exiting!${normal}"
        exit 1

    else
        printf "%s\n" \
        "${green}Sufficient disk space available " \
        "----------------------------------------------------" \
        "Proceeding${normal}"
    fi

    printf "%s\n" \
    "Checking if currently loaded kernel is newest kernel" \
    "----------------------------------------------------" \
    " "

    ## Check if running kernel matches newest installed kernel
    newestKernel=$(find /boot/vmlinuz-* | sort -V | tail -n 1 | sed 's|.*vmlinuz-||')
    runningKernel=$(uname -r)
    if [[ "$newestKernel" != "$runningKernel" ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - Newest kernel not loaded!" \
        "----------------------------------------------------" \
        "Currently loaded Kernel: " "$runningKernel" \
        "Newest installed Kernel: " "$newestKernel" \
        "Reboot server to load newest installed kernel" \
        "After reboot re-run script ${normal}"
        exit 1
    else
        printf "%s\n" \
        "${green}Newest Installed Kernel running" \
        "----------------------------------------------------" \
        "Proceeding${normal}"
    fi

    ## Update server
    yum update -y

    ## Were yum updates applied successfully? Were there any errors?
    if [[ $? != 0 ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - YUM RETURNED NON-0 VALUE!" \
        "----------------------------------------------------" \
        "Review any errors detailed above, exiting!${normal}"
        exit 1

    else
        printf "%s\n" \
        "${green}Yum Updates Applied" \
        "----------------------------------------------------" \
        "Proceeding${normal}"
    fi

    ## Check for chattr'd files
    if [[ $(lsattr /etc/yum.conf | grep "\-i\-") || $(lsattr /etc/yum.repos.d/* | grep "\-i\-") ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - chattrd yum files found!" \
        "----------------------------------------------------" \
        "Review and unchattr the files listed below" \
        "Re-run script once review complete!${normal}"
        lsattr /etc/yum.conf | grep "\-i\-"
        lsattr /etc/yum.repos.d/* | grep "\-i\-"
        exit 1
    else
        printf "%s\n" \
        "${green}No Chattrd yum files found" \
        "----------------------------------------------------" \
        "Proceeding${normal}"
    fi

    ## Check for duplicate packages, remove it found
    package-cleanup --cleandupes -y

    ## Were dupes (if any) cleared? Were there any errors?
    if [[ $? != 0 ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - YUM RETURNED NON-0 VALUE!" \
        "----------------------------------------------------" \
        "Review any errors detailed above, exiting!${normal}"
        exit 1
    else
        printf "%s\n" \
        "${green}Duplicate Packages (if any) Removed " \
        "----------------------------------------------------" \
        "Proceeding${normal}"
    fi

    ### Check for NFS
    printf "%s\n" \
    "Checking for NFS "\
    "----------------------------------------------------" \
    " "

    ### If NFS installed and mounts are found, throw error
    if [[ $(yum list installed | grep nfs-utils) && $(mount -l | grep nfsd) ]]; then
            printf "%s\n" \
            "${red}ISSUE DETECTED - NFS detected on server!"\
            "----------------------------------------------------" \
            "ELevate is not compatible with NFS mounts!${normal}" \
            " " \
            "Paths forward: " \
            "* If NFS not in use, remove packages and re-run script " \
            "* Otherwise provision a new server and migrate manually" \
            " "

            printf "%s\n" \
            "Below are the detected NFS packages " \
            " "
            yum list installed | grep nfs-utils

            printf "%s\n" \
            "Below are the detected NFS mounts " \
            " "
            mount -l | grep nfsd

            exit 1

    ### Check fstab for NFS as well
    elif [[ $(grep nfs /etc/fstab) ]]; then
            printf "%s\n" \
            "${red}ISSUE DETECTED - NFS detected on server!"\
            "----------------------------------------------------" \
            "ELevate is not compatible with NFS mounts!${normal}" \
            " " \
            "Paths forward: " \
            "* If NFS not in use, remove entry and re-run script " \
            "* Otherwise provision a new server and migrate manually" \
            " " \
            "The following NFS mount was found in /etc/fstab " \
            " "
            grep nfs /etc/fstab

            exit 1
    ### Otherwise clear
    else
            printf "%s\n" \
            "${green}NFS not detected"\
            "----------------------------------------------------" \
            "Proceeding${normal}"
    fi

    ### Check for non-standard processes
    printf "%s\n" \
    "Checking for /opt and /home processes" \
    "----------------------------------------------------" \
    " "

    ### Check for processes in /opt and /home folders. Update grep -v -E -i as needed
    if [[ $(ps aux | grep -i -E "/opt|/home" | grep -v -E -i "grep|inotify|maldet") ]]; then
        printf "%s\n" \
        "${yellow}IMPORTANT: /opt or /home processes found "\
        "----------------------------------------------------" \
        "This can cause issues with upgrades! "
        "Note the following processes below${normal}" \
        " "

        #### List processes running out of /home or /opt. Update grep -v -E -i as needed
        ps aux | grep -i -E "/opt|/home" | grep -v -E -i "grep|inotify|maldet"

        printf "%s\n" \
        " " \
        "${yellow}Press Enter when ready to proceed${normal}" \
        " "
        read junkInput
    else
        printf "%s\n" \
        "${green}No /opt or /home processes found "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    fi

    ## Install ELevate repo and leapp tool
    sudo yum install -y http://repo.almalinux.org/elevate/elevate-release-latest-el$(rpm --eval %rhel).noarch.rpm
    sudo yum install -y leapp-upgrade leapp-data-rocky

    printf "%s\n" \
    "Removing packages that cause conflicts"\
    "----------------------------------------------------" \
    " "

    ### Remove packages that cause conflicts with upgrade
    yum remove bash-completion bash-completion-extras -y

    printf "%s\n" \
    "Performing initial leapp test"\
    "----------------------------------------------------" \
    " "

    ### Perform Leapp test
    sudo leapp preupgrade

    ### Check for specific critical lines in report
    #### Check for dev kernels, remove if found in report
    if [[ $(grep yum /var/log/leapp/leapp-report.txt -l) ]]; then
        printf "%s\n" \
        "Development Kernels found, removing "\
        "----------------------------------------------------" \
        " "
        eval "$(grep yum /var/log/leapp/leapp-report.txt | cut -d' ' -f2-)"
    fi

    #### Check for pam_tally2 -> pam_faillock requirement in report
    if [[ $(grep 'Title: The pam_tally2' /var/log/leapp/leapp-report.txt -l) ]]; then
        printf "%s\n" \
        "pam_tally2 from base in use, changing to faillock "\
        "----------------------------------------------------" \
        " "
        ##### Change noted from https://github.com/dev-sec/ansible-collection-hardening/issues/377

        ##### Replace pam_tally2 instances with faillock in relevant pam.d files
        sed -i "s/tally2/faillock/g" /etc/pam.d/system-auth-ac
        echo "account     required      pam_faillock.so" >> /etc/pam.d/password-auth-ac

        ##### Complete change with authconfig. Based arguments on URL above and current pam_tally settings
        authconfig --enablefaillock --faillockargs="deny=3 onerr=fail" --update

        ##### Restart sshd service to load new configs as generated by authconfig
        systemctl restart sshd
    fi

    #### Check for hmac-ripemd160 cipher in report
    if [[ $(grep 'Title: OpenSSH configured to use removed mac' /var/log/leapp/leapp-report.txt -l) ]]; then
        ##### Check if sshd_config chattr'd
        if [[ $(lsattr /etc/ssh/sshd_config | grep "\-i\-") ]]; then
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bk.chattr

            printf "%s\n" \
            "${yellow}IMPORTANT: sshd_config is chattrd "\
            "----------------------------------------------------" \
            "ELevate needs to change sshd_config to upgrade" \
            "Script will temporarily unchattr/re-chattr sshd_config to make changes" \
            "Copy created at /etc/ssh/sshd_config.bk.chattr" \
            "After upgrade check changes unrelated to the hmac-ripemd160 cipher" \
            "Re-edit sshd_config if required" \
            "Press Enter when ready to proceed${normal}"
            read junkInput

            chattr -i /etc/ssh/sshd_config
        fi

        ##### Remove hmac-ripemd160 from sshd_config, chattr sshd_config in case any automation is configuring the OS
        sed -i 's/hmac-ripemd160,//g' /etc/ssh/sshd_config
        sed -i 's/hmac-ripemd160-etm@openssh.com,//g' /etc/ssh/sshd_config
        echo "# Chattr'd as part of ELevate upgrade - NG"  >> /etc/ssh/sshd_config
        chattr +i /etc/ssh/sshd_config
        systemctl restart sshd

        ##### Back up sshd_config as part of test for upgrade
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bk
    fi

    #### Check for leapp questions, answer if found
    if [[ $(grep 'leapp answer --section' /var/log/leapp/leapp-report.txt -l) ]]; then
        printf "%s\n" \
        "Leapp questions found, answering "\
        "----------------------------------------------------" \
        " "

        #### For loop to answer leapp questions
        ##### Populate Array
        mapfile -t leappArray <<< "$(grep 'leapp answer --section' /var/log/leapp/leapp-report.txt | cut -d' ' -f2-)"

        ##### 'Answer' leapp questions
        for i in "${leappArray[@]}"; do
            eval "$i"
        done
    fi

    ### Edit repos from C7 -> R8
    printf "%s\n" \
    "Editing CentOS 7 repos to Rocky 8" \
    "----------------------------------------------------" \
    " "

    #### Navigate to yum repos folder
    cd /etc/yum.repos.d

    #TODO Adjust for server configurations
    #### Edit Repo URLs from C7 -> R8
    sed -i 's/Linux 7/Linux 8/g' epel.repo
    sed -i 's/7Server/8/g' epel.repo
    sed -i 's/epel\/7/epel\/8/g' epel.repo

    #### If present, remove centos-sclo-rh
    if [[ -f CentOS-SCLo-scl-rh.repo ]]; then
        yum remove devtoolset-7-* llvm-toolset-7-* centos-release-scl-rh -y
    fi

    #### Prompt user to check for errors
    printf "%s\n" \
    "${yellow}IMPORTANT: Check for any repo errors "\
    "----------------------------------------------------" \
    "Check for error messages in repo section above " \
    "If any errors seen, open a new session and review" \
    "Press Enter when ready to proceed${normal}"
    read junkInput

    ### Re-run leapp test
    printf "%s\n" \
    "Re-performing pre-upgrade check" \
    "----------------------------------------------------" \
    " "

    #### Zero out report to start file new
    echo "" > /var/log/leapp/leapp-report.txt

    #### Re-run leapp preupgrade to check if clear
    sudo leapp preupgrade

    #### if critical errors found, tell user to review and resolve manually
    if [[ $(grep inhibitor /var/log/leapp/leapp-report.txt -l) ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - Inhibitor level errors found "\
        "----------------------------------------------------" \
        "Review/resolve manually " \
        "See /var/log/leapp/leapp-report.txt " \
        "Run sudo leapp preupgrade when complete to re-check " \
        "Snippet of errors below for review${normal}"
        grep inhibitor /var/log/leapp/leapp-report.txt -C 5

        printf "%s\n" \
        "${red}Once review complete run leapp preupgrade"\
        "If clear, run script with upgrade flags${normal}"

    #### Else no critical errors found, tell use to run upgrade function
    else
        printf "%s\n" \
        "${green}No Inhibitor level errors found "\
        "----------------------------------------------------" \
        "Re-run script with upgrade flags${normal}"
    fi

}

# Function to upgrade server
function runUpgrade(){
    #TODO Adjust size as needed for own server configuration
    # ELevate runs in a container, set container size
    export LEAPP_OVL_SIZE=10240

    printf "%s\n" \
    "Upgrade" \
    "----------------------------------------------------"

    ## Validation
    ## Check if user root
    printf "%s\n" \
    "Checking if user is root "\
    "----------------------------------------------------" \
    " "
    if [[ "$EUID" -eq 0 ]]; then
        printf "%s\n" \
        "${green}User is root "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    else
        printf "%s\n" \
        "${red}ISSUE DETECTED - User is NOT root "\
        "----------------------------------------------------" \
        "Re-run script as root${normal}"
        exit 1
    fi

    ## Confirm values, pass warnings etc.
    printf "%s\n" \
    "${yellow}IMPORTANT: Value Confirmation" \
    "----------------------------------------------------" \
    "Hostname: " "$(hostname)" \
    "Before proceeding confirm the following:" \
    "1. In screen session" \
    "2. Running script as root" \
    "If all clear, press enter to proceed or ctrl-c to cancel${normal}" \
    " "

    ## Press enter to proceed, control + c to cancel
    read junkInput

    ### Upgrade
    #### Truncate upgrade log in case function has been run before
    echo "" > /var/log/leapp/leapp-upgrade.log

    #### Run upgrade function
    leapp upgrade

    ### Check for error messages in upgrade log
    if [[ $(grep "Error Summary" /var/log/leapp/leapp-upgrade.log) || $(grep "ERRORS" /var/log/leapp/leapp-upgrade.log | grep -v '/') ]]; then
        #### Message that errors were found in the log
        printf "%s\n" \
        "${red}ISSUE DETECTED - Error in leapp-upgrade.log" \
        "----------------------------------------------------" \
        "Review /var/log/leapp/leapp-upgrade.log" \
        "Snippet of error listed below" \
        "After resolving re-run script with upgrade function${normal}" \
        " "

        #### Output error messages
        grep -E "Error Summary|ERRORS" /var/log/leapp/leapp-upgrade.log -C 7

        #### Error message for disk space
        printf "%s\n" \
        " " \
        "${red}IMPORTANT" \
        "----------------------------------------------------" \
        "If error related to X MB needed on / filesystem" \
        "Run the following: export 'LEAPP_OVL_SIZE=11264'" \
        "Then upgrade manually: 'leapp upgrade'" \
        "If check clears, reboot to complete upgrade" \
        "If error persists, re-run export with larger value for LEAPP_OVL_SIZE"\
        "Be aware of available disk space before doing this!${normal}"

        exit 1
    fi

    ### Check for inhibitor errors
    if [[ $(grep inhibitor /var/log/leapp/leapp-report.txt -l) ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - Inhibitor level errors found "\
        "----------------------------------------------------" \
        "Review/resolve manually " \
        "See /var/log/leapp/leapp-report.txt " \
        "Run 'sudo leapp preupgrade' when complete to re-check " \
        "Snippet of errors below for review${normal}" \
        " "

        grep inhibitor /var/log/leapp/leapp-report.txt -C 5

        printf "%s\n" \
        "${red}Once review complete run 'leapp preupgrade'"\
        "If clear, run script with upgrade flags${normal}"

        exit 1
    fi

    ### Confirm server clear to upgrade
    printf "%s\n" \
    "${yellow}IMPORTANT: Upgrade checks complete" \
    "----------------------------------------------------" \
    "Server ready to upgrade" \
    "Server will reboot in three seconds${normal}"

    ### Sleep for three seconds
    sleep 3

    ### Reboot to finalize upgrade
    sudo reboot
}

# Function for post-upgrade
function runPost(){
    printf "%s\n" \
    "Post-Upgrade" \
    "----------------------------------------------------"

    ## Validation
    ## Check if user root
    printf "%s\n" \
    "Checking if user is root "\
    "----------------------------------------------------" \
    " "
    if [[ "$EUID" -eq 0 ]]; then
        printf "%s\n" \
        "${green}User is root "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    else
        printf "%s\n" \
        "${red}ISSUE DETECTED - User is NOT root "\
        "----------------------------------------------------" \
        "Re-run script as root${normal}"
        exit 1
    fi

    ## Confirm values, pass warnings etc.
    printf "%s\n" \
    "${yellow}IMPORTANT: Value Confirmation" \
    "----------------------------------------------------" \
    "Hostname: " "$(hostname)" \
    "Before proceeding confirm the following:" \
    "1. In screen session" \
    "2. Running script as root" \
    "If all clear, press enter to proceed or ctrl-c to cancel${normal}" \
    " "

    ## Press enter to proceed, control + c to cancel
    read junkInput

    ## Configure parallel downloads in dnf
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf

    ### Re-install removed software
    printf "%s\n" \
    "Re-installing removed software"\
    "----------------------------------------------------" \
    " "
    ### Enable PowerTools repo, often needed for package dependencies
    sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/Rocky-PowerTools.repo

    ### Clean repos, check for updates, re-install removed packages
    yum clean all
    yum update -y

    # Re-install removed packages from earlier
    yum install screen bash-completion -y

    #TODO: Adjust as needed for own servers
    ### Remove/re-install el7 packages
    yum remove yum-plugin-fastest-mirror btrfs-progs elevate-release kernel leapp-data-rocky libunwind -y
    yum install kernel libunwind rsyslog -y

    ## Failed Services check
    printf "%s\n" \
    "Checking for failed services"\
    "----------------------------------------------------" \
    "Review any errors returned"
    systemctl list-units --failed

    printf "%s\n" \
    "${yellow}IMPORTANT: Resolve any failed services if any"\
    "----------------------------------------------------" \
    "Press Enter when ready to proceed${normal}"

    ### Populate junk input
    read junkInput

    ## Check for el7 packages
    printf "%s\n" \
    "Checking for CentOS 7 packages"\
    "----------------------------------------------------" \
    "Remove/Reinstall any packages returned"

    if [[ $(yum list installed | grep el7) ]]; then
            yum list installed | grep el7
            printf "%s\n" \
            "${yellow}IMPORTANT: CentOS 7 packages found"\
            "----------------------------------------------------" \
            "Open a separate session" \
            "Remove/re-install packages listed above" \
            "Press Enter when ready to proceed${normal}"
            read junkInput
    fi

    ## Regenerate GRUB menu
    printf "%s\n" \
    "Regenerating GRUB menu"\
    "----------------------------------------------------" \
    " "

    grub2-mkconfig -o /boot/grub2/grub.cfg

    printf "%s\n" \
    "${green}Final steps"\
    "----------------------------------------------------" \
    "Fill in based on server configuration needs${normal}"
}

# Main, read passed flags
printf "%s\n" \
"Elevate Helper" \
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
    exit 0
    ;;
[Pp]rep)
    printf "%s\n" \
    "Running Pre-Upgrade function" \
    "----------------------------------------------------"
    runPrep
    ;;
[Uu]pgrade)
    printf "%s\n" \
    "Running Upgrade function" \
    "----------------------------------------------------"
    runUpgrade
    ;;
[Pp]ost)
    printf "%s\n" \
    "Running Post-Upgrade function" \
    "----------------------------------------------------"
    runPost
    ;;
*)
    printf "%s\n" \
    "${red}ISSUE DETECTED - Invalid input detected!" \
    "----------------------------------------------------" \
    "Running help script and exiting." \
    "Re-run script with valid input${normal}"
    helpFunction
    exit 1
    ;;
esac
