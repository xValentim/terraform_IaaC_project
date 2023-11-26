output "vpc_id" {
  value       = aws_vpc.vpc.id
}

output "private_sub_1_id" {
  value       = aws_subnet.private_subnet_1.id
}

output "public_sub_1_id" {
  value       = aws_subnet.public_subnet_1.id
}

output "private_sub_2_id" {
  value       = aws_subnet.private_subnet_2.id
}

output "public_sub_2_id" {
  value       = aws_subnet.public_subnet_2.id
}