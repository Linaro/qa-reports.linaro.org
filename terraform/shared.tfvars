region = "us-east-1"
vpc_id = "vpc-097c92bf21a7082e9" # 172.31.0.0/16
availability_zone_to_subnet_map = {
  "us-east-1a" = "subnet-08375ce285b190f06" # 172.31.1.0/24
  "us-east-1b" = "subnet-0197bdcd7f985caa4" # 172.31.2.0/24
}
ssh_key_path = "qa-reports.pub"
route53_zone_id = "Z27NRA2FV79C84" # ctt.linaro.org
route53_base_domain_name = "ctt.linaro.org"

# us-east-1, 16.04LTS, hvm:ebs-ssd
# see https://cloud-images.ubuntu.com/locator/ec2/
ami_id = "ami-0b383171"

