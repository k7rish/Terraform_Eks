

provider "aws" {

  region = "us-east-1"

}



data "aws_availability_zones" "azs" {

  state = "available"

}



locals {

  cluster_name = "eks-cluster"

}



module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"

  version = ">= 0.1"



  name = "eks-vpc"

  cidr = "10.0.0.0/16"



  azs                  = slice(data.aws_availability_zones.azs.names, 0, 2)

  public_subnets       = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = false

  enable_dns_hostnames = true



  tags = {

    "kubernetes.io/cluster/${local.cluster_name}" = "shared"

  }



  public_subnet_tags = {

    "kubernetes.io/cluster/${local.cluster_name}" = "shared"

    "kubernetes.io/role/elb"                      = "1"

  }



}



module "eks" {

  source  = "terraform-aws-modules/eks/aws"

  version = ">= 0.1"



  cluster_name    = local.cluster_name

  cluster_version = "1.22"

  subnets         = module.vpc.public_subnets

  vpc_id          = module.vpc.vpc_id


  write_kubeconfig   = true

  config_output_path = "./"

}



data "aws_eks_cluster" "cluster" {

    name = module.eks.cluster_id

  }



data "aws_eks_cluster_auth" "cluster" {

    name = module.eks.cluster_id

  }


module "eks_managed_node_group" {

  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name            = "terraform-eks-mng"
  cluster_name    = "eks-cluster"
  cluster_version = "1.22"

  vpc_id     =  module.vpc.vpc_id
  subnet_ids  = [module.vpc.public_subnets[0]]

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_security_group_id = module.eks.cluster_primary_security_group_id

  min_size     = 1
  max_size     = 1
  desired_size = 1

  instance_types = ["t3.medium"]
  //capacity_type  = "SPOT"


  }


provider "kubernetes" {

    version = ">= 0.1"

    host                   = data.aws_eks_cluster.cluster.endpoint

    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)

   token                  = data.aws_eks_cluster_auth.cluster.token

    load_config_file       = false

}

