# Set Local Variable
locals {
    owner = title("Collie")
}

# Configure the AWS Provider
provider "aws" {
    profile = "dev"
    region = "ap-northeast-2"
}

##############
# VPC
##############
resource "aws_vpc" "this" {
    cidr_block = var.public_cidr
    tags = {
        Name = format("%s_%s",local.owner,title("vpc"))
    }
}

# Subnet-Public
resource "aws_subnet" "public" {
    count = length(var.public_subnet)
    vpc_id = aws_vpc.this.id
    cidr_block = var.public_subnet[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true
    tags = {
        Name = format("%s_%s_Subnet_%s",local.owner,"Public",count.index+1)
    }
}

# Subnet-Private
resource "aws_subnet" "private_eks" {
    count = length(var.private_eks_subnet)
    vpc_id = aws_vpc.this.id
    cidr_block = var.private_eks_subnet[count.index]
    availability_zone = var.azs[count.index]
    
    tags = {
        Name = format("%s_%s_Subnet_%s",local.owner,"Private",count.index+1)
    }
}

resource "aws_subnet" "private_db" {
    count = length(var.private_db_subnet)
    vpc_id = aws_vpc.this.id
    cidr_block = var.private_db_subnet[count.index]
    availability_zone = var.azs[count.index]
    
    tags = {
        Name = format("%s_%s_Subnet_%s",local.owner,"Private",count.index+1)
    }
}

# InternetGW
resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id 
    tags = { 
        Name = format("%s_IGW",local.owner)
    }  
}

# NATGW_Single
resource "aws_eip" "nat_gw" {
    domain = "vpc"

    tags = { 
        Name = format("%s_NAT_EIP",local.owner)
    }  
}

resource "aws_nat_gateway" "single" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = format("%s_%s",local.owner,"natgw")
  }

  depends_on = [aws_internet_gateway.this]
}

# RouteTable-Public
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

# RouteTable-Private
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.single.id
    }

    tags = {
        Name = format("%s_Private_RT",local.owner)
    }
}

resource "aws_route_table_association" "private_eks" {
    count = length(var.private_eks_subnet)
    subnet_id = aws_subnet.private_eks[count.index].id
    route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
    count = length(var.private_db_subnet)
    subnet_id = aws_subnet.private_db[count.index].id
    route_table_id = aws_route_table.private.id
}

##############
# EKS
##############
resource "aws_eks_cluster" "this" {
    name = format("%s_%s",local.owner,"EKS")
    role_arn = aws_iam_role.eks.arn

    vpc_config {
        security_group_ids = [aws_security_group.eks_control_plane.id,aws_security_group.eks_data_plane.id]
		subnet_ids = aws_subnet.private_eks[*].id
		endpoint_public_access = true
		endpoint_private_access = true
    }

    depends_on = [ 		
        aws_iam_role_policy_attachment.eks-cluster-EKSClusterPolicy,
		aws_iam_role_policy_attachment.eks-cluster-EKSServicePolicy,
        aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController, 
    ]

    tags = {
        name = format("%s_%s",local.owner,"EKS")
    }
}

resource "aws_iam_role" "eks" {
	name = format("%s_EKS_Cluster_IAM",local.owner)

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

resource "aws_security_group" "eks_control_plane" {
    name = format("%s_ControlPlane_SG",local.owner)
	vpc_id = aws_vpc.this.id
	description = "EKS ControlPlane Security Group"
	tags = {
		Name = format("%s_ControlPlane_SG",local.owner)
	}    
}

resource "aws_security_group_rule" "eks_control_plane_ingress" {
    description = "Allow control plane api server from dataplane pod"
    security_group_id = aws_security_group.eks_control_plane.id
    
    source_security_group_id = aws_security_group.eks_data_plane.id
    from_port = 443
    to_port = 443
    protocol = "tcp"
    type = "ingress"
}

resource "aws_security_group_rule" "eks_control_plane_egress" {
    description = "Allow control plane api server to dataplane pod"
    security_group_id = aws_security_group.eks_control_plane.id
    
    source_security_group_id = aws_security_group.eks_data_plane.id
    from_port = 1024
    to_port = 65535
    protocol =  "tcp"
    type = "egress"
}

resource "aws_security_group" "eks_data_plane" {
  name = format("%s_DataPlane_SG",local.owner)
  vpc_id      = aws_vpc.this.id
  description = "EKS DataPlane Security Group"

  tags = {
    Name = format("%s_DataPlane_SG",local.owner)
  }
}

resource "aws_security_group_rule" "eks_data_plane_ingress_dataplane" {
    description = "Allow data plane communicate with each other"
    security_group_id = aws_security_group.eks_data_plane.id
    
    source_security_group_id = aws_security_group.eks_data_plane.id
    from_port = 0
    to_port = 65535
    protocol = "-1"
    type = "ingress"
}

resource "aws_security_group_rule" "eks_data_plane_ingress_cluster" {
    description = "Allow data plane communicate with each other"
    security_group_id = aws_security_group.eks_data_plane.id
    
    source_security_group_id = aws_security_group.eks_control_plane.id
    from_port = 1025
    to_port = 65535
    protocol = "tcp"
    type = "ingress"
}

resource "aws_security_group_rule" "eks_data_plane_egress_cluster" {
    description = "Allow data plane egress all"
    security_group_id = aws_security_group.eks_data_plane.id
    
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    type = "egress"
}







resource "local_file" "kube_config" {
 content = templatefile("${path.module}/templates/kube_config.yaml.tpl",
    {
		CERTIFICATE = aws_eks_cluster.this.certificate_authority[0].data
		MASTER_ENDPOINT = aws_eks_cluster.this.endpoint
		CLUSTER_NAME = format("%s_%s",local.owner,"EKS")
		ROLE_ARN = aws_iam_role.eks.arn
	})
 # content = data.template_file.kube-config.rendered
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


resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "bastion"
  vpc_id      = aws_vpc.this.id

  tags = {
    "Name" = "bastion"
  }
}

resource "aws_security_group_rule" "bastion_ingress" {
  description              = "test"
  cidr_blocks              = ["0.0.0.0/0"]
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  to_port                  = 22
  type                     = "ingress"
}

resource "aws_security_group_rule" "bastion_egress" {
  description              = "test"
  cidr_blocks              = ["0.0.0.0/0"]
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.bastion.id
  to_port                  = 65535
  type                     = "egress"
}

data "aws_ami" "worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.this.version}-v*"]
  }

  most_recent = true
}

resource "aws_eks_node_group" "worker" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "collie-worker-node"
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = [aws_subnet.public[0].id,aws_subnet.public[1].id,aws_subnet.public[2].id] // Network Configuration

  // Worker Settings
  instance_types = ["t3.small"]
  disk_size      = 20
  capacity_type = "SPOT" #OR SPOT

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 2
  }

  remote_access {
    source_security_group_ids = [aws_security_group.eks_data_plane.id]
    ec2_ssh_key               = "keypair-DevCollie"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-worker-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks-worker-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-worker-AmazonEKSWorkerNodePolicy,
  ]
}

resource "local_file" "aws-auth" {
  content = templatefile("${path.module}/templates/aws_auth.yaml.tpl", 
    { 
        rolearn = aws_iam_role.worker.arn
    }
)
  # content  = data.template_file.aws-auth.rendered
  filename = "${path.cwd}/.output/aws_auth.yaml"
}



data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]
#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name = "keypair-DevCollie"
  ami = data.aws_ami.this.id
#   instance_market_options {
#     market_type = "spot"
#     spot_options {
#       max_price = 0.0031
#     }
#   }

  subnet_id = aws_subnet.public[0].id
  instance_type = "t3.nano"
  tags = {
    Name = "test-spot"
  }
}

resource "aws_eip" "ec2" {
  domain = "vpc"
  instance = aws_instance.bastion.id
}

resource "aws_db_subnet_group" "rds" {
  name       = format("%s_db_subnet_group",lower(local.owner))
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = format("%s_DB_Subnet_Group",local.owner)
  }
}

resource "aws_security_group" "rds" {
  name   = format("%s_DB_SG",local.owner)
  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("%s_DB_SG",local.owner)
  }
}

resource "aws_security_group_rule" "rds_ingress" {
  description = "postgresql rds ingress rule"
  
  security_group_id = aws_security_group.rds.id
  from_port = 0
  to_port = 65535
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
  type = "ingress"
}

resource "aws_security_group_rule" "rds_egress" {
  description = "postgresql rds egress rule"
  
  security_group_id = aws_security_group.rds.id
  from_port = 0
  to_port = 65535
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
  type = "egress"
}

# db 파라미터 및 db 서브넷 그룹 이름명은 알파벳 소문자로 작성해야 함
# only lowercase alphanumeric characters, periods, and hyphens allowed in parameter group "name"
resource "aws_db_parameter_group" "rds" {
  name   = format("%s-db-paramgroup",lower(local.owner))
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

# Sensitive 한 값을 실행 시 입력 받을 수 있게 처리하는 방법
# variable "db_password" {
#   description = "RDS root user password"
#   sensitive   = true
# }

# db 이름은 소문자 및 하이픈만 가능
resource "aws_db_instance" "rds" {
  identifier             = "collie-rds"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "16.1"
  username               = "collie"
  password               = "colliesample"
  db_name                = "mywork"
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.rds.name
  skip_final_snapshot    = true

  lifecycle {
    ignore_changes = [ 
        password
     ]
  }
}

# TO-DO Cloudfront resource 
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution

# TO-DO S3 resource
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket

# TO-DO SSM Setting
#https://docs.aws.amazon.com/ko_kr/prescriptive-guidance/latest/patterns/connect-to-an-amazon-ec2-instance-by-using-session-manager.html
