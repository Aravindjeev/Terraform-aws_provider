variable "aws_access_key" {
  default     = "xxx"
  description = "Amazon AWS Access Key"
}

variable "aws_secret_key" {
  default     = "xxx"
  description = "Amazon AWS Secret Key"
}

variable "prefix" {
  default     = "Falcon"
  description = "Cluster Prefix - All resources created by Terraform have this prefix prepended to them"
}

variable "rancher_version" {
  default     = "latest"
  description = "Rancher Server Version"
}

variable "count_agent_all_nodes" {
  default     = "1"
  description = "Number of Agent All Designation Nodes"
}

variable "count_agent_etcd_nodes" {
  default     = "0"
  description = "Number of ETCD Nodes"
}

variable "count_agent_controlplane_nodes" {
  default     = "0"
  description = "Number of K8s Control Plane Nodes"
}

variable "count_agent_worker_nodes" {
  default     = "0"
  description = "Number of Worker Nodes"
}

variable "rancher_cluster" {
default = "terraform-cluster"
description = " Terraform Cluster name"
}

variable "admin_password" {
  default     = "admin"
  description = "Password to set for the admin account in Rancher"
}

variable "cluster_name" {
  default     = "quickstart"
  description = "Kubernetes Cluster Name"
}

variable "region" {
  default     = "us-east-2"
  description = "Amazon AWS Region for deployment"
}

variable "type" {
  default     = "t3.medium"
  description = "Amazon AWS Instance Type"
}

variable "docker_version_server" {
  default     = "18.09"
  description = "Docker Version to run on Rancher Server"
}

variable "docker_version_agent" {
  default     = "18.09"
  description = "Docker Version to run on Kubernetes Nodes"
}

variable "ssh_key_name" {
  default     = ""
  description = "Amazon AWS Key Pair Name"
}

variable "rancher_url" {
  type = "string"
  description = "Endpoint for the Rancher"

}

variable "rancher_api_token" {
  type = "string"
  description = "API Token to access the Rancher API"

}
variable "subnet" {
  type = "string"
  description = "Subnet id"
}

variable "vpc" {
  type = "string"
  description = "vpc id"
}
variable "zone" {
  type = "string"
  description = "Zone"
}

# Configure the Amazon AWS Provider
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}
provider "rancher2" {
  api_url    = "${var.rancher_url}/v3"
  token_key  = "${var.rancher_api_token}"
  insecure = true
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "rancher_sg_allowall" {
  name = "${var.prefix}-allowall"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Rancher
resource "rancher2_cluster" "manager" {
  name = "${var.rancher_cluster}"
  description = "Rancher Cluster: ${var.rancher_cluster}"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}
# Create a new rancher2 Node Template
resource "rancher2_node_template" "nodetemp" {
  name = "nodetemp"
  description = "Rancher_Node"
  amazonec2_config {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    ami =  data.aws_ami.ubuntu.id
    region = var.region
    security_group = [aws_security_group.rancher_sg_allowall.name]
    subnet_id = var.subnet
    vpc_id = var.vpc
    zone = var.zone
}
}
# Create a new rancher2 Node Pool
resource "rancher2_node_pool" "nodepool-master" {
  cluster_id =  "${rancher2_cluster.manager.id}"
  name = "nodepool-master"
  hostname_prefix =  "terraform-master-0"
  node_template_id = "${rancher2_node_template.nodetemp.id}"
  quantity = 1
  control_plane = true
  etcd = true
}
resource "rancher2_node_pool" "nodepool-worker" {
  cluster_id =  "${rancher2_cluster.manager.id}"
  name = "nodepool-worker"
  hostname_prefix =  "terraform-worker-0"
  node_template_id = "${rancher2_node_template.nodetemp.id}"
  quantity = 2
  control_plane = true
  worker = true
}

output "rancher-url" {
  value = ["${var.rancher_url}"]
}
