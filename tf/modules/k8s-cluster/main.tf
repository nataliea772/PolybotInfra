##########################################
# Security Group for Control Plane + Worker
##########################################
resource "aws_security_group" "k8s_cluster_sg" {
  name        = "k8s-cluster-sg"
  description = "Allow SSH and Kubernetes ports"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K8s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Inter-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##########################################
# IAM Role and Profile for EC2 (SSM + SSM Param Write)
##########################################
resource "aws_iam_role" "k8s_role" {
  name = "${var.name}-k8s-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.k8s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "put_param" {
  name   = "${var.name}-PutJoinCommand"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ssm:PutParameter", "ssm:GetParameter", "ec2:DescribeInstances"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy_attachment" "attach_put_param" {
  name       = "AttachPutParam"
  policy_arn = aws_iam_policy.put_param.arn
  roles      = [aws_iam_role.k8s_role.name]
}

resource "aws_iam_instance_profile" "k8s_profile" {
  name = "${var.name}-k8s-profile"
  role = aws_iam_role.k8s_role.name
}

##########################################
# Control Plane EC2 Instance
##########################################
resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.k8s_cluster_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k8s_profile.name

  user_data = file("${path.module}/user_data_control_plane.sh")

  tags = {
    Name = "natalie-control-plane"
  }
}

##########################################
# Launch Template for Worker Nodes
##########################################
resource "aws_launch_template" "worker_template" {
  name_prefix   = "natalie-worker-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k8s_cluster_sg.id]
  }
  user_data = filebase64("${path.module}/user_data_worker.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "natalie-worker-node"
    }
  }
}

##########################################
# Auto Scaling Group for Worker Nodes
##########################################
resource "aws_autoscaling_group" "worker_asg" {
  name                      = "natalie-worker-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [var.subnet_id]
  launch_template {
    id      = aws_launch_template.worker_template.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "natalie-worker-node"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}
