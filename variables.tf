#deployment vars

variable "cluster_name" {
}

variable "environment" {
}

variable "costcenter" {
}

variable "group" {
  default = ""
}

variable "expiration" {
  default = "never"
}

# AMI ID for container instances
variable "ami_id" {
}

# container instance size
variable "instance_type" {
  default = "t2.small"
}

variable "asg_min_size" {
  default = "1"
}

variable "asg_desired_capacity" {
  default = "1"
}

variable "asg_max_size" {
  default = "1"
}

variable "key_name" {
}

variable "poc" {
}

variable "vpc_id" {
}

variable "vpc_cidr_block" {
}

variable "private_subnets" {
}

variable "container_instance_sec_group_ids" {
  default = []
}

variable "workspace_endpoint" {
  default = ""
}

variable "enable_appdynamics" {
  default = "false"
}

variable "appdynamics_agent_access_key_encrypted" {
  default = ""
}

variable "appdynamics_api_user_key_encrypted" {
  default = ""
}

