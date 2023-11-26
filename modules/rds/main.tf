# # Declaração das variáveis
# variable "db_password" {
#   description = "Senha do banco de dados"
#   type        = string
# }

# # Declaração das variáveis
# variable "db_username" {
#   description = "User do banco de dados"
#   type        = string
# }

resource "aws_security_group" "sg_db" {
  name        = "sg_db"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_db_instance" "db" {
  allocated_storage   = 20
  engine              = "mysql"
  instance_class      = "db.t2.micro"
  db_name             = "dbterraform"
  username            = var.DB_USER 
  password            = var.DB_PASSWORD 
  skip_final_snapshot = true
  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  multi_az = true

  vpc_security_group_ids = [
    aws_security_group.sg_db.id 
  ]
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [var.private_sub_1_id, var.private_sub_2_id]

  tags = {
    Name = "My DB Subnet Group"
  }
}
