output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "mirror_public_ip" {
  description = "Public IP of the mirror host"
  value       = aws_eip.mirror.public_ip
}

output "ssh_connection_command" {
  description = "Command to connect to the mirror host"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_eip.mirror.public_ip}"
} 