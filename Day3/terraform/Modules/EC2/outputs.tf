output "bastion_instance_id" {
  description = "ID of the bastion instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = aws_instance.bastion.public_ip
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.keypair.key_name
}