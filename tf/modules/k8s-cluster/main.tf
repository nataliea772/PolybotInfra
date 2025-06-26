##########################################
# Security Group for Control Plane + Worker
##########################################
resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg"
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
    description = "Allow worker nodes to reach control-plane (e.g. kubelet)"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
resource "aws_iam_role" "ssm_role" {
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

resource "aws_iam_policy" "put_parameter_policy" {
  name        = "AllowPutParameter"
  description = "Allow EC2 to put kubeadm join command into SSM Parameter Store"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:PutParameter",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "put_parameter_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.put_parameter_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "k8s-control-plane-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = file("${path.module}/user_data_control_plane.sh")

  tags = {
    Name = "control-plane"
  }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "k8s-worker"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.subnet_id
    security_groups = [
        aws_security_group.control_plane_sg.id,
        aws_security_group.worker_sg.id
    ]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "k8s-worker"
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                      = "k8s-worker-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-worker"
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "worker_sg" {
  name        = "worker-sg"
  description = "Allow traffic for K8s worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow control-plane to access kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane_sg.id]
  }

  ingress {
    description = "Allow NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}