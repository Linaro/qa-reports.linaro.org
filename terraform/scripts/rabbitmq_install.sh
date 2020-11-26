#!/bin/sh

# This script is copied to new EC2 for RabbitMQ and run as user 'ubuntu'.

retry() {
    n=1
    while [ "$n" -le 10 ] && ! "$@"; do
        sleep $((n*5))s
        n=$((n+1))
    done
    [ "$n" -le 10 ]
}

retry sudo apt-get update
retry sudo apt-get install -qy rabbitmq-server

cat <<CONF >/etc/rabbitmq/rabbitmq.config
[
  {
    rabbit,
    [
      {loopback_users, []}
    ]
  }
].
CONF

retry systemctl restart rabbitmq-server

# This will only work for RabbitMQ >= 3.6.0
retry rabbitmqctl set_policy Lazy "" '{"queue-mode":"lazy"}' --apply-to queues
