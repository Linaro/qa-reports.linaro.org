# qa-reports.linaro.org deployment repository

You've reached qa-reports deployment repository. It contains all
necessary scripts to get an instance of SQUAD running in production.

We moved from ansible managed EC2 instances to containerized deployment with Kubernetes in AWS EKS.

There are 4 different environments available: dev, testing, staging and production.
Both production and staging are hosted in Fargate nodes shared in a single EKS cluster,
while "testing" is also in run in the same cluster, it's used in specific scenarios for testing.
The dev environment uses 3 local virtual machines, 2 for Kubernetes master/worker nodes and 1 for PostgreSQL/RabbitMQ services.

# Deploying

Deploy a `dev|testing|staging|production` environment by running:

```bash
$ ./qareports production up
```

This should make sure all resources are created and running.

# Upgrading

## SQUAD only

Run this command when there's a new release of SQUAD available in https://hub.docker.com/r/squadproject/squad/tags:

```bash
$ ./qareports production upgrade_squad [squad-release]
```

If squad-release, e.g. 1.16, is given, then all images will be replaced by that specific one. If no
tag is given, qareports will be upgraded to the latest tag in dockerhub.

NOTE: this will update SQUAD code only, it doesn't update environment variables or other setup in this repo.

## Upgrading after changes in any file of this repo

Run this command when there's a change in any of the deployment files:

```bash
$ ./qareports production deploy
```

NOTE: this will re-apply all configuration files, including environment variables and will
update SQUAD at the very last step.

# Commands

Here is a list of handy commands to manage qareports:

* `./qareports production queues -w` lists all queues in production and keep watching
* `./qareports production pods` lists all pods running in production
* `./qareports production top` lists all pods' stats of CPU and memory
* `./qareports production logs -f pod-name-with-hash` displays logs for a given pod
* `./qareports production logs -f -l app=qareports-worker` display logs from all "qareports-worker" pods
* `./qareports production k describe pod pod-name-with-hash` displays more details from a given pod
* `./qareports production ssh pod-name-with-hash` ssh into any pod in production.
  NOTE: for qareports-web pods, you should append `-c qareports-web` to the command, because there are two containers in this pod.


## Cheatsheet of commands to use on a daily basis

Here are some utility commands that might help debugging and accessing things:

* `./qareports dev up` creates k8s cluster, RabbitMQ and PostgreSQL instance and deploy squad
* `./qareports dev upgrade_squad` upgrades SQUAD docker image in all deployments
* `./qareports dev destroy` destroys development deploy
* `./qareports dev list` lists all resources in the cluster, useful to discover pods
* `./qareports dev ssh master-node` ssh into the master node
* `./qareports dev ssh qareports-listener-deployment-947f8d9b8-ntfww` ssh into pod running `squad-listener`.
  * NOTE: be careful when running heavy commands on this pod, it's limited to a maximum of 512MB of RAM, but
    dont't worry it it crashes, Kubernetes scheduler will just removed crashed one and spawn a new one in no time!
* `./qareports dev logs -f deployment/qareports-web-deployment` gets the log stream of all pods under qareports-web deployment
* `./qareports dev k <kubectl-args>` run `kubectl` on development environment
* `./qareports dev k delete pod qareports-listener-deployment-947f8d9b8-ntfww` deletes a bad pod. If a pod crashes and
  Kubernetes didn't removed it (but it should've), it's useful to delete that pod so that forces creating a fresh new one.

# Dependencies

There are some tools necessary to manage qareports, make sure they all are installed to your $PATH:

* terraform: tool needed for managing resources on cloud like AWS, GKE
  `https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip`

* ansible: tool for automating node setup
  Install according to your distro: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

* kubectl: tool for managing kubernetes cluster
  `https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl`

# NOTES

Here are some notes taken while creating this repository.

## K8s
### Pod didn't start properly

There are a lot of reasons why a pod won't start:
* the image doesn't exist
* there's nowhere or not enough computer power available to deploy it
  * staging and production pods are supposed to be scheduled under AWS Fargate, and that happens only if you're deploying the pods under the correct namespace

Usually a command to describe what is going on on a pod is

```
./qareports dev describe pod pod-name
```

## Celery crashed while mingling

Starting celery with '--without-mingle' prevented it from crashing everytime a new worker was started in parallel.
More info: https://stackoverflow.com/questions/55249197/what-are-the-consequences-of-disabling-gossip-mingle-and-heartbeat-for-celery-w

## Never-ending tasks in ci_fetch queue

Sometimes celery suffers from `celery_chord_unlock` tasks that never reach a timeout and causes the fetch-workers to
do useless work. I still have not found the reason for this yet, but until then, it's convenient to purge the ci_fetch queue.

1. First kill all fetch-workers
2. ssh -i tmp/qareports_private_ssh_key `cat terraform/generated/production_rabbitmq_host_public` (you'll need to run `./qareports production queues` first)
3. sudo rabbitmqctl purge_queue ci_fetch

## Zombie pods / pods in endless terminating state

Sometimes pods act weird and enter a terminating state where it hangs forever.
You can force-terminate this pod by running

```
./qareports production k delete pod --grace-period=0 --force <pod-name>
```

## Emails

We're currently using AWS Simple Email Service aka SES to send emails. On an account that SES was never used, AWS puts it under sandbox
mode, for security. This way SES will only send messages to verified emails. For production use, you NEED to create a support ticket in
AWS asking to move SES out of sandbox mode.

Once things are cleared in SES, there are 2 ways to send emails: as an SMTP relay or as RESTfull API. We're using the 
second one for convenience. It's super-super easy to make it work. You just spin up a docker container from https://github.com/blueimp/aws-smtp-relay
and it proxies all email requests to SES.

Initially aws-smtp-relay was placed in qareports-worker pod which sits on a Fargate serverless node.
Sending emails wasn't possible because the node is required to have an SES IAM policy to authenticate to SES.
Until date (Jun/2020) I couldn't find a way of doing this.
A workaround was to place aws-smtp-relay in a regular EC2 node (EKS master node) where the necessary SES policy was attached to make emails possible.

The two settings to handle EMAIL are `SQUAD_EMAIL_HOST` and `SQUAD_EMAIL_PORT`, which should point to the aws-smtp-relay service.

# References

Posts that helped a LOT understanding AWS Networking:
* https://nickcharlton.net/posts/terraform-aws-vpc.html
* https://www.theguild.nl/cost-saving-with-nat-instances/#the-ec2-instance
