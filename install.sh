#!/usr/bin/env bash

welcome_message="""
+-------------------------------------------------------+
|                        Warning                        |
+-------------------------------------------------------+
| This tool _may_ irreversibly wreck to your system.    |
| Please read README.md before proceeding!              |
+-------------------------------------------------------+

"""
printf "%b" "$welcome_message"

read -r -p "Would you like to nuke unattended upgrades? [Y/n] " nuke_unattended

#--------------------------------------------------------
# ssh and gpg keys
#--------------------------------------------------------
key_path="$(pwd)/input/keys"
copy_keys_str="true"
read -r -p "Do you want to copy ssh and gpg keys? [Y/n] " copy_keys
if [[ $copy_keys =~ ^[Nn]$ ]]; then
    echo "Tool will skip copying ssh and gpg keys."
    copy_keys_str="false"
else
    echo "The default path to ssh and gpg keys is [$(pwd)/input/keys]."
    read -r -p "Change path? [y/N] " change_path

    if [[ $change_path =~ ^[Yy]$ ]]; then
        read -r -p "Enter path: " key_path
    else
        key_path="input/keys"
    fi
fi
if [[ ! -d "$key_path" ]]; then
    echo "Folder does not exist. Exiting..."
    exit 1
fi

#--------------------------------------------------------
# firefox profile
#--------------------------------------------------------
ff_profile_path="$(pwd)/input/firefox"
copy_profile_str="true"
read -r -p "Do you want to copy firefox profile? [Y/n] " copy_profile
if [[ $copy_profile =~ ^[Nn]$ ]]; then
    echo "Tool will skip copying firefox profile."
    copy_profile_str="false"
else
    echo "The default path to firefox profile is [$(pwd)/input/firefox]."
    read -r -p "Change path? [y/N] " change_path

    if [[ $change_path =~ ^[Yy]$ ]]; then
        read -r -p "Enter path: " ff_profile_path
    else
        ff_profile_path="input/firefox"
    fi
fi

if [[ ! -d "$ff_profile_path" ]]; then
    echo "Folder does not exist. Exiting..."
    exit 1
fi

#--------------------------------------------------------
# confirm git-profiles OK
#--------------------------------------------------------
git_profile_path="$(pwd)/input/git-profiles"
read -r -p "Does [$(pwd)/input/git-profiles/profiles.yml] look OK? [Y/n] " git_profiles_ok
if [[ $git_profiles_ok =~ ^[Nn]$ ]]; then
    echo "Please review git profiles before proceeding."
    exit 1
fi

read -r -s -p "Please enter sudo password for ansible: " sudo_password

if [[ $nuke_unattended =~ ^[Nn]$ ]]; then
    echo "Skipped nuking unattended upgrades"
else
    echo "Nuking unattended upgrades"
    echo "$sudo_password" | sudo -S apt remove unattended-upgrades -y
fi

echo "$sudo_password" | sudo -S apt update
apt_deps=("curl" "wget" "ansible" "pip")
for dep in "${apt_deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "$dep could not be found"
        echo "installing $dep"
        echo "$sudo_password" | sudo -S apt install "$dep" -y
    else
        echo "$dep is installed"
    fi
done

snap_deps=("yq" "jq")
for dep in "${snap_deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "$dep could not be found"
        echo "installing $dep"
        echo "$sudo_password" | sudo -S snap install "$dep"
    else
        echo "$dep is installed"
    fi
done

logs_path="$(pwd)/output/logs"

rm -f "$logs_path/report.txt"
rm -f "$logs_path/report.apps.txt"

touch "$logs_path/report.txt"
touch "$logs_path/report.apps.txt"

ansible-playbook -i localhost, -c local install_system.yml -e "\
copy_keys=$copy_keys_str \
keys_path=$key_path \
git_profile_path=$git_profile_path \
ansible_beecome_pass=$sudo_password \
logs_path=$logs_path"

install_report="\n\n"
install_report="${install_report}+----------------------------------------------------+\n"
install_report="${install_report}|               Desktop Install Report               |\n"
install_report="${install_report}+----------------------------------------------------+\n"
install_report="${install_report}\n"

install_report_body=$(<"$logs_path/report.txt")
install_report="${install_report}${install_report_body}\n\n"

ansible-playbook -i localhost, -c local install_apps.yml -e "\
copy_firefox=$copy_profile_str \
ff_profile_path=$ff_profile_path \
ansible_beecome_pass=$sudo_password \
logs_path=$logs_path"

install_report="${install_report}+----------------------------------------------------+\n"
install_report="${install_report}|                 App Install Report                 |\n"
install_report="${install_report}+----------------------------------------------------+\n"
install_report="${install_report}\n"

install_report_body=$(<"$logs_path/report.apps.txt")
install_report="${install_report}${install_report_body}\n\n"

printf "%b" "$install_report"
