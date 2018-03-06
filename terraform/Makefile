ENV := staging

override:
	./scripts/set_env.sh ${ENV}

.terraform:
	terraform init

plan: .terraform override
	terraform plan -var-file=shared.tfvars -var-file=${ENV}.tfvars .

repl: .terraform override
	terraform console -var-file=shared.tfvars -var-file=${ENV}.tfvars .

apply: .terraform override
	terraform apply -var-file=shared.tfvars -var-file=${ENV}.tfvars .

inventory: override
	terraform state pull | ./scripts/state_to_ansible_inventory.py > ../ansible/hosts.$(ENV)

clean:
	rm -rf .terraform errored.tfstate qa-reports_override.tf
