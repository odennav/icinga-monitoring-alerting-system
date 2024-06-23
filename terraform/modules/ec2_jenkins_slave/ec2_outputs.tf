# AWS EC2 Instance Terraform Outputs

## ec2_jenkins_slave_instance_ids
output "ec2_jenkins_slave_instance_id" {
  description = "Jenkins Slave EC2 instance ID"
  value       = module.ec2_jenkins.id
}

## ec2_jenkins_slave_public_ip
output "ec2_jenkins_slave_public_ip" {
  description = "Public IP address of the Jenkins Slave EC2 instance"
  value       = module.ec2_jenkins.public_ip 
}

