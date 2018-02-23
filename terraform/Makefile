ENV := staging

all: plan apply

.terraform:
	terraform init

plan: .terraform
	terraform plan -var-file=shared.tfvars -var-file=${ENV}.tfvars .

repl: .terraform
	terraform console -var-file=shared.tfvars -var-file=${ENV}.tfvars .

apply: .terraform
	terraform apply -var-file=shared.tfvars -var-file=${ENV}.tfvars .

inventory:
	terraform state pull | ./scripts/state_to_ansible_inventory.py > ../ansible/hosts.staging

clean:
	rm -rf .terraform errored.tfstate
