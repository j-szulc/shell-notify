#!/bin/bash
set -e

if [[ "$1" == "--help" ]]; then
    echo "Usage: shell-notify <command to execute...>"
    echo "You will be asked for neccessary information to send notification."
    echo "Currently only interactive mode is supported."
    exit 0
fi

# Get the command to execute
command_to_execute="$@"
if [[ -z "$command_to_execute" ]]; then
    echo "No command to execute provided."
    exit 1
fi

declare provider

read_save(){
    local prompt=$1
    local var_name=$2
    if [[ -z "$prompt" || -z "$var_name" ]]; then
        echo "Prompt and variable name are required."
        return 1
    fi
    if grep -q "^${var_name}=" ~/.shell_notify.env; then
        eval $var_name=$(grep "^${var_name}=" ~/.shell_notify.env | cut -d'=' -f2)
        return
    fi

    read -p "$prompt" $var_name
    echo "$var_name=${!var_name}" >> ~/.shell_notify.env
}

provider_mailgun_setup() {
    echo "Mailgun provider selected."

    which curl > /dev/null || {
        echo "curl is required to send email."
        exit 1
    }

    read_save "Mailgun API Key: " mailgun_api_key
    read_save "Mailgun Domain: " mailgun_domain
    read_save "To Email Address: " mailgun_to_email
}

provider_mailgun_run() {
    exit_code=$1
    if [[ $exit_code -eq 0 ]]; then
        subject="Success"
    else
        subject="Failed"
    fi
    curl -s --user "api:${mailgun_api_key}" \
        https://api.mailgun.net/v3/${mailgun_domain}/messages \
        -F from="Shell-notify <mailgun@${mailgun_domain}>" \
        -F to="${mailgun_to_email}" \
        -F subject="${subject}" \
        -F text="The command exit code: $exit_code"
}

main(){
    provider_mailgun_setup
    set +e
    (${command_to_execute})
    exit_code=$?
    set -e
    echo "Command exit code: $exit_code"
    provider_mailgun_run $exit_code
}

main