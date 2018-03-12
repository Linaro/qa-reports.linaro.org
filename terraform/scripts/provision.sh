#!/bin/sh

# This script is copied to new EC2 hosts and run as user 'ubuntu'.
# Use it to bootstrap the host.

# drue's ssh key
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDORl4HnMm6j9OsjXENsmJM73OFqBsNCWGmQ0Lucir7Wh+AxCRxDxXmtpnSmW1ZO3Foo0xVC0ie0BYCg3HkwFqst/0Ho7q0yK5zqnZ+oFIgyYdCpnsdNCOgdMTns9NRkW8PG7QfCsLH46h5JbxYp+MRysklPSO4l1sKXf8bTYxowTctC9qIFR5847Djq7xNpK3gJN2Z2nPu9mvjKgK5pwhOuP9dk3aLvUW0sInKn6tYkvsGKRnSv1CbiUesfBDgmwyLSQ8GgKF575jgaI11gTkJXVHxmb6P0pSUgnXBXRggz+qiJBCrqkUiLhwn6uPCZ8nXWShfTqwg+682qda/3mKX drue" >> /home/ubuntu/.ssh/authorized_keys

# terceiro's ssh key
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4XbnFOoWpbwEiX0k6YsJQteanZft5E8IuzZK9JjZ48GC+4fU8cpFxc8Na5MSkxGawmpATwCaMvrGZyP1hKqxAgnTO8qAkBIhn7HvGdMJ870ePjOCPNg9OiRUtWV85tNDsPsq1rjMPePMMIg3jZeVXhHjBy1lytOLp3L48qMBHOlUzJzBmZ8VDzREY+Xo/vEx+Q15EB9/qPsbYvruyIQOiDKWxasIcKQNQvoaa082U1ZEb7OyNum81E93waccWENNWhovVJ03yyfKJ/i9ToS6kcm5DfEFSoa0yPSpClJ3B2daVIBJxyX1NXZilZhYvKHVEjamLsekLI5fgMG2Nk51D terceiro" >> /home/ubuntu/.ssh/authorized_keys

# mwasilew's ssh key
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLg0a071B8RSBVYxXoGa/dMZ7jaiLdEM8tmMIg0VTFAh8xPOUIJ8HWurQdc+mq6mMtBFqKGJ5YshLEXK//CKRW+lR+2eTEpjMLfoOR7u1zxU35+lAxbVavOwEHzjaPaGypmaqwWvNdlgsg2gl5Qo7B2f9nEnHtieAW7qI/1agjorB8/I12H2H2iC7GWKptRq1wPRp2sgwq2Bk286xTOESFV+iv0tzT5GepJUexXmF69xqlkW5uznA7LV8DqPQk/5n42K8i5gMjH+ulEDTc1/aMVjjTaSIEbEsvyvhXCXa7PpCRdXT/vodKHnRUwJPu5lkX5m9WSpl6E0RdqQY/3WTn mwasilew" >> /home/ubuntu/.ssh/authorized_keys

retry() {
    n=1
    while [ "$n" -le 10 ] && ! "$@"; do
        sleep $((n*5))s
        n=$((n+1))
    done
    [ "$n" -le 10 ]
}
retry sudo apt-get update
retry sudo apt-get install -qy python3
