#!/bin/sh

# This script is copied to new EC2 hosts and run as user 'ubuntu'.
# Use it to bootstrap the host.

# drue's ssh key
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIbM0vUDnQPn7FbTwoyxws4HHEeQOdyHMWsbO5HjAdwJuh93wqhTZvK5FEWpJxnK/e+BWIGyIbWTB+AVaaNUnRTXTEetAjRhQB6ibwcmRTpPTLpMv+UrODTb+T/9+NzBnAii/+/r3gFpQ3/Di0V/Nd03en2ayHDnqHgPV1toOtcalShXucrTLxP41etqqmJkRLXj2tYMIdufLfvCoFVOpRJ6Zu60vE4qA9Tasbtcgufey2MCgEHtF8yXOA19n+BOQLVgxJIxoIcPWNtr++FWuxM8fh2YaZbOHNqgdNSEMOCDFsQvvT9KF1a9ypqujk8wU6sJtH8HaWm5twQ4bPQwnr drue@xps" >> /home/ubuntu/.ssh/authorized_keys

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
