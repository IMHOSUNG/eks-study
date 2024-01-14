# kubectl install
# terraform init
# 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
    owner = "Collie"
}

variable "public_cidr" {
    type = string
    default = "192.168.0.0/16"
}

variable "azs" {
    type = list(string)
    default = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

variable "public_subnet" {
    type = list(string)
    default = ["192.168.0.0/24","192.168.1.0/24","192.168.2.0/24"]
}

# Configure the AWS Provider
provider "aws" {
    profile = "dev"
    region = "ap-northeast-2"
}

# Create a VPC
resource "aws_vpc" "this" {
    cidr_block = var.public_cidr
    tags = {
        Name = format("%s_%s",local.owner,"vpc")
    }
}

# make for_each later
resource "aws_subnet" "public" {
    count = length(var.public_subnet)
    vpc_id = aws_vpc.this.id
    cidr_block = var.public_subnet[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true
    tags = {
        Name = format("%s_%s_%s",local.owner,"PublicSubnet",count.index)
    }
}

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id 
    tags = { 
        Name = format("%s_%s",local.owner,"igw")
    }  
}


resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.this.id
    }

    tags = {
        Name = format("%s_%s",local.owner,"PublicRT")
    }
}

resource "aws_route_table_association" "public" {
    count = length(var.public_subnet)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "eks" {
	name = "kuberkuber-eks"
	description = "Cluster communication with worker nodes"
	vpc_id = aws_vpc.this.id

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "kuberkuber-eks"
	}
}

resource "aws_iam_role" "eks" {
	name = "kuberkuber-eks"

	assume_role_policy = <<POLICY
{
"Version": "2012-10-17",
"Statement": [
	{
	"Action": "sts:AssumeRole",
	"Principal": {
		"Service": "eks.amazonaws.com"
	},
	"Effect": "Allow",
	"Sid": ""
	}
]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-EKSClusterPolicy"{
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
	role = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-EKSServicePolicy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
	role = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
    name = format("%s_%s",local.owner,"EKS")
    role_arn = aws_iam_role.eks.arn

    vpc_config {
        security_group_ids = [aws_security_group.eks.id]
		subnet_ids = [aws_subnet.public[0].id,aws_subnet.public[1].id,aws_subnet.public[2].id]
		endpoint_public_access = true
		endpoint_private_access = true
    }

    depends_on = [ 		
        aws_iam_role_policy_attachment.eks-cluster-EKSClusterPolicy,
		aws_iam_role_policy_attachment.eks-cluster-EKSServicePolicy,
        aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController, 
    ]
}

data "template_file" "kube-config" {
	template = file("${path.module}/templates/kube_config.yaml.tpl")

	vars = {
		CERTIFICATE = aws_eks_cluster.eks.certificate_authority[0].data
		MASTER_ENDPOINT = aws_eks_cluster.eks.endpoint
		CLUSTER_NAME = format("%s_%s",local.owner,"EKS")
		ROLE_ARN = aws_iam_role.eks.arn
	}
}

resource "local_file" "kube_config" {
 content = data.template_file.kube-config.rendered
 filename = "${path.cwd}/.output/kube_config.yaml"
}

# kubectl config get-contexts

resource "aws_iam_role" "worker" {
	name = "kuberkuber-worker"

	assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEKSWorkerNodePolicy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
	role = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEKS_CNI_Policy" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
	role = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEC2ContainerRegistryReadOnly" {
	policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
	role = aws_iam_role.worker.name
}

resource "aws_iam_instance_profile" "worker" {
	name = "kuberkuber-worker"
	role = aws_iam_role.worker.name
}

resource "aws_security_group" "worker" {
  name        = "kuberkuber-worker"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "kuberkuber-worker"
    "kubernetes.io/cluster/Collie_EKS" = "owned"
  }
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker.id
  source_security_group_id = aws_security_group.worker.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.worker.id
  source_security_group_id = aws_security_group.eks.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_cluster_ingress_node_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks.id
  source_security_group_id = aws_security_group.worker.id
  to_port                  = 443
  type                     = "ingress"
}

data "aws_ami" "worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.eks.version}-v*"]
  }

  most_recent = true
}

locals {
  eks_worker_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority[0].data}' Collie_EKS
USERDATA
}

resource "aws_eks_node_group" "worker" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "collie-worker-node"
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = [aws_subnet.public[0].id,aws_subnet.public[1].id,aws_subnet.public[2].id] // Network Configuration

  // Worker Settings
  instance_types = ["t3.micro"]
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  remote_access {
    source_security_group_ids = [aws_security_group.worker.id]
    ec2_ssh_key               = "keypair-DevCollie"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-worker-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks-worker-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-worker-AmazonEKSWorkerNodePolicy,
  ]
}

# resource "aws_launch_configuration" "worker" {
#   associate_public_ip_address = true
#   iam_instance_profile        = aws_iam_instance_profile.worker.name
#   image_id                    = data.aws_ami.worker.id
#   instance_type               = "t3.micro"
#   name_prefix                 = "Collie_EKS"
#   security_groups             = [aws_security_group.worker.id]
#   user_data_base64            = base64encode(local.eks_worker_userdata)

#   lifecycle {
#     create_before_destroy = true
#   }
# }

data "template_file" "aws-auth" {
  template = file("${path.module}/templates/aws_auth.yaml.tpl")

  vars = {
    rolearn   = aws_iam_role.worker.arn
  }
}

resource "local_file" "aws-auth" {
  content  = data.template_file.aws-auth.rendered
  filename = "${path.cwd}/.output/aws_auth.yaml"
}

# resource "aws_autoscaling_group" "worker" {
#   desired_capacity     = 2
#   launch_configuration = aws_launch_configuration.worker.name
#   max_size             = 2
#   min_size             = 1
#   name                 = "Collie_EKS"
#   vpc_zone_identifier  = [aws_subnet.public[0].id,aws_subnet.public[1].id,aws_subnet.public[2].id]
#   tag {
#     key                 = "Name"
#     value               = "Collie_EKS"
#     propagate_at_launch = true
#   }

#   tag {
#     key                 = "kubernetes.io/cluster/Collie_EKS"
#     value               = "owned"
#     propagate_at_launch = true
#   }
# }
