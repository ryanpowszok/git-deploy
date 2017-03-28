#!/usr/bin/env bash

install_path=/usr/local/bin
deploy_script="deploy.sh"
deploy_command="deploy"

if [ $# -ne 0 ]; then
    install_path=$1
fi
script_dir=$( cd $(dirname $0); pwd -P )

# Copy slacktee.sh to /usr/local/bin
cp "$script_dir/$deploy_script" "$install_path/$deploy_command"

# Set execute permission
chmod +x "$install_path/$deploy_command"

echo "$deploy_script has been installed to $install_path"
