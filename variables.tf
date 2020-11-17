variable "aws_region_list" {
  type = "map"
  default = {
    "1"  = "us-east-1"
    "2"  = "us-east-2"
    "3"  = "us-west-1"
    "4"  = "us-west-2"
    "5"  = "ca-central-1"
    "6"  = "eu-west-1"
    "7"  = "eu-west-2"
    "8"  = "eu-central-1"
    "9"  = "ap-southeast-1"
    "10" = "ap-southeast-2"
    "11" = "ap-northeast-1"
    "12" = "ap-northeast-2"
    "13" = "ap-south-1"
    "14" = "sa-east-1"
  }
}
variable "aws_profile" {
  description = "The Profile from `aws-configure`"
  default = "default"
}

variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default     = "10.1.0.0/16"
}
variable "cidr_subnet" {
  description = "CIDR block for the subnet"
  default     = "10.1.0.0/24"
}
variable "availability_zone" {
  description = "availability zone to create subnet"
  default     = "ap-south-1a"
}
variable "public_key_path" {
  description = "Public key path"
  default     = "~/.ssh/id_rsa.pub"
}
variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default     = "ami-0cf31d971a3ca20d6"
}
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "t2.micro"
}
variable "environment_tag" {
  description = "Environment tag"
  default     = "Production"
}

variable "alarms_email" {
  description = "Default Ops Email"
  default     = "me@rvsharma.com"
}

# Cloudwatch Metrics
variable "memory_warning" {
  description = "web memory warning threshold"
  default = "70"
}
variable "memory_critical" {
  description = "web memory critical threshold"
  default = "90"
}
variable "diskspace_warning" {
  description = "web disk space warning threshold"
  default = "70"
}
variable "diskspace_critical" {
  description = "web disk space critical threshold"
  default = "90"
}