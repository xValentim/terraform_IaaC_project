output "ec2_sg_id" {
  description = "The ID of the security group to be associated with the FastAPI application"
  value       = aws_security_group.ec2_sg.id
}

output "alb_sg_id" {
  description = "The ID of the security group to be associated with the ALB"
  value       = aws_security_group.alb_sg.id
}