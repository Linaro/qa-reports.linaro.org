#!/bin/bash

set -eu

# Prepare authentication
conf=$(dirname $0)/auth.conf
if [ -r "$conf" ]; then
    . "$conf"
fi
if [ -z "${aws_profile:-}" ] || [ -z "${terraform_role:-}" ]
then
    echo "E: \$aws_profile and \$terraform_role must be set."
    echo "I: Either set it in the environment, or in $conf"
    exit 1
fi

#
# We're using AWS SSO to authenticate to our AWS account. After logging in, we need
# to assume the role qareports-terraform to manage resources in our account
#
# Session duration
duration=3600

# Login using AWS SSO
credentials_dir=$HOME/.cache/qa-reports.linaro.org
credentials="$credentials_dir/admin_credentials"
mkdir -p "$credentials_dir"
chmod 700 "$credentials_dir"

if [ -e "$credentials" ]; then
    now=$(date +%s)
    credentials_created=$(stat --format=%Y "$credentials")
    if [ $((now - credentials_created)) -gt $duration ]; then
        rm -f "$credentials"
    fi
fi
if [ ! -e "$credentials" ] || [ ! -s "$credentials" ]; then
    touch "$credentials"
    chmod 600 "$credentials"
    aws2-wrap --profile "$aws_profile" --export > "$credentials"

    # export AWS{ACCESS_KEY_ID,SECRET_ACCESS_KEY,SESSION_TOKEN}
    . $credentials
    cat $credentials

    # After we're logged in, it's time to switch to our proper role
    # and switch credentials
    aws sts assume-role --role-arn $terraform_role --role-session-name QATerraformAWSCLI-Session \
        | grep -Eo '(AccessKeyId|SecretAccessKey|SessionToken).*"' \
        | sed -e 's/AccessKeyId": /export AWS_ACCESS_KEY_ID=/' \
              -e 's/SecretAccessKey": /export AWS_SECRET_ACCESS_KEY=/' \
              -e 's/SessionToken": /export AWS_SESSION_TOKEN=/' \
              -e 's/"//g' \
        > "$credentials"
fi

# export AWS{ACCESS_KEY_ID,SECRET_ACCESS_KEY,SESSION_TOKEN}
cat $credentials
