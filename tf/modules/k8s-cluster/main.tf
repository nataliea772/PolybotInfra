# adding security groups
resource "aws_security_group" "k8s_control_plane_sg" {
  name        = "k8s-control-plane-sg"
  description = "Allow SSH and Kubernetes API access"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #[var.vpc_cidr] # change to my ip
  }

  ingress {
    description = "Allow K8s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # change to VPC CIDR
  }

  # ingress {
  #   description = "Allow intra-cluster communication"
  #   from_port   = 0
  #   to_port     = 65535
  #   protocol    = "tcp"
  #   cidr_blocks = [var.vpc_cidr]
  # }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role
resource "aws_iam_role" "k8s_control_plane_role" {
  name = "${var.name}-k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version          = "2012-10-17"
    Statement        = [{
      Action         = "sts:AssumeRole"
      Principal      = {
        Service      = "ec2.amazonaws.com"
      }
      Effect         = "Allow"
      Sid            = ""
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
          "ssm:PutParameter"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_put_parameter_policy" {
  name       = "AttachPutParameterPolicy"
  roles      = [aws_iam_role.k8s_control_plane_role.name]
  policy_arn = aws_iam_policy.put_parameter_policy.arn
}

# Policies for the IAM Role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.k8s_control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.name}-k8s-instance-profile"
  role = aws_iam_role.k8s_control_plane_role.name
}

resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.k8s_control_plane_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "natalie-control-plane"
  }
}

resource "aws_instance" "worker_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.k8s_control_plane_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "natalie-worker-node"
  }
}
