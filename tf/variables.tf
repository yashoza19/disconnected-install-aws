variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "openshift-restricted"
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.medium"
}

variable "mirror_instance_type" {
  description = "Instance type for mirror host"
  type        = string
  default     = "t3.xlarge"
}

variable "rhel9_ami_id" {
  description = "RHEL 9 AMI ID"
  type        = string
  default     = "ami-01edee474bb1c74ae"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for EC2 instances"
  type        = string
  default     = "openshift-restricted-key"
} 