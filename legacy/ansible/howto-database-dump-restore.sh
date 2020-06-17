#!/bin/sh

ENV=${ENV:-staging}

banner() {
    echo
    echo '########################################################################'
    echo "# " "$@"
    echo '########################################################################'
    echo
}

banner 'Step 1: create VM'
echo create instance: t2.medium, 40GB disk, debian stretch
echo put it in both staging-qa-reports-workers and qa-reports-workers security groups
echo install: postgresql-client tmux moreutils

banner 'Step 2: prepare VM'
echo "# Run these commands from that VM:"
echo
echo 'cat > ~/.pgpass <<EOF'
for env in staging production; do
    database_hostname=$(sed -e '/database_hostname=/!d; s/database_hostname=//' hosts.$env)
    python3 -c "import yaml; import subprocess; data = yaml.load(subprocess.check_output(['./ansible-vault', 'view', 'group_vars/${env}'])); print('echo ${database_hostname}:*:%(database_name)s:%(database_user)s:%(database_password)s' % data)"
done
echo 'EOF'
echo 'chmod 0600 ~/.pgpass'
echo 'cat >> ~/.bashrc <<EOF'
for env in staging production; do
    database_hostname=$(sed -e '/database_hostname=/!d; s/database_hostname=//' hosts.$env)
    echo "export $(echo "$env" | tr a-z A-Z)='-h ${database_hostname} -d ${env}qareports -U qareports'"
done
echo 'EOF'

banner 'Step 3: dump/restore'
echo "# Dump production and restore to staging:"
echo 'pg_dump $PRODUCTION -F custom -f dump -v'
echo 'psql $STAGING -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public"'
echo 'pg_restore $STAGING dump'

banner 'Step 4: final tweks to the restored data'
echo "# Now, from a staging host, run the following as the \"squad\" user. It will remove subscription from the DB to avoid emailing people from staging"
echo 'squad-admin prepdump'
