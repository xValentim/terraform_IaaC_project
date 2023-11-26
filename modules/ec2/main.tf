# # Declaração das variáveis
# variable "db_username" {
#   description = "User do banco de dados"
#   type        = string
# }

resource "aws_key_pair" "project_key_pair" {
  key_name   = "id_rsa"
  public_key = file("id_rsa.pub")
}



data "template_file" "user_data_script" {
  template = <<-EOF
    #!/bin/bash
    sudo touch app.log 

    # Script de inicialização para instalação do Python e iniciar a aplicação
    sudo apt-get update -y
    sudo apt-get install -y python3-pip
    sudo yum update -y
    sudo yum install -y amazon-cloudwatch-agent
    sudo apt-get install -y python3-venv authbind awscli
    echo "fez o needrestart" >> app.log
    echo "fez o install de tudo" >> app.log



    # Clonando seu repositório Git onde está o arquivo app.py (ajuste conforme necessário)
    git clone https://github.com/xValentim/simple_python_crud /home/ubuntu/simple_python_crud
    echo "clonou" >> app.log
    
    # Instalando as dependências do projeto
    sudo chown -R ubuntu:ubuntu ~/simple_python_crud
    cd /home/ubuntu/simple_python_crud

    sudo pip3 install -r requirements.txt  # Se você tiver um arquivo de requisitos

    echo "install requirements" >> app.log

    # Definindo variáveis de ambiente
    export DB_HOST=${var.DB_HOST}
    export DB_USER=${var.DB_USER}
    export DB_PASSWORD=${var.DB_PASSWORD}
    export DB_NAME=${var.DB_NAME}
    export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    # Inicia o agente
    echo "deu export" >> app.log
    echo ${var.DB_HOST} >> app.log
    echo ${var.DB_USER} >> app.log
    echo ${var.DB_PASSWORD} >> app.log
    echo ${var.DB_NAME} >> app.log
    echo INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) >> app.log
    # Creating log stream...
    sudo systemctl start amazon-cloudwatch-agent
    
    aws logs create-log-stream --log-group-name "/my-fastapi-app/logs" --log-stream-name "$INSTANCE_ID" --region us-east-1
    
    sudo touch /etc/authbind/byport/80
    sudo chmod 500 /etc/authbind/byport/80
    sudo chown ubuntu /etc/authbind/byport/80

    # Iniciando a aplicação FastAPI (ajuste o comando conforme a sua estrutura de diretórios)
    authbind --deep uvicorn main:app --host 0.0.0.0 --port 80 &
    echo "rodou" >> app.log
  EOF
}


resource "aws_lb" "my_alb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = [var.public_sub_1_id, var.public_sub_2_id]
  
  enable_deletion_protection = false

  tags = {
    Name = "my-load-balancer"
  }
}



resource "aws_lb_target_group" "my_tg" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    path                = "/docs"
    protocol            = "HTTP"
    port                = "80"
  }

  tags = {
    Name = "my-target-group"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}

resource "aws_launch_template" "lt" {
  name_prefix            = "lt-"
  image_id               = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.ec2_sg_id]

  # user_data = data.template_file.user_data_script.rendered
  user_data = base64encode(data.template_file.user_data_script.rendered)
  key_name = aws_key_pair.project_key_pair.key_name

  iam_instance_profile {
    name = var.ec2_profile_name
  }

}


resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier  = [var.public_sub_1_id, var.public_sub_1_id]
  max_size             = 4
  min_size             = 2
  desired_capacity     = 2
  health_check_type    = "EC2"

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns    = [aws_lb_target_group.my_tg.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "AlarmHighCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "10"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "cpu usage metric (low)"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "AlarmLowCPU"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "10"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "cpu usage metric (low)"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_log_group" "my_log_group" {
  name = "/my-fastapi-app/logs"
}

