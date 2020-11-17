provider "aws" {
  region  = data.template_file.aws_region.rendered
  profile = var.aws_profile
}

# Readme Notes
# There are currenly 14 regions in variable, you may select according to least latency.
data "template_file" "aws_region" {
  template = "$${region}"
  vars = {
    #Change the number 13 to number specific to your region from variables.tf file.
    region = var.aws_region_list["13"]
  }
}

#================ Print AWS region selected ================
output "aws_region" {
  value = data.template_file.aws_region.rendered
}

#================ VPC ================
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "vpn-vpc"
  }
}

#================ IGW ================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "vpn-vpc-igw"
  }
}

#================ Public Subnet ================
resource "aws_subnet" "pub_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "${data.template_file.aws_region.rendered}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "vpn-pub-subnet"
  }
}

#================ Route Table ================
resource "aws_route_table" "pub_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pub-rtb"
  }
}

#================ Route Table Association ================
resource "aws_route_table_association" "pub_rtb_assoc" {
  subnet_id      = aws_subnet.pub_subnet.id
  route_table_id = aws_route_table.pub_rtb.id
}

#================ Security Groups ================
resource "aws_security_group" "vpn_sg" {
  name        = "vpn-sg"
  description = "OpenVPN Security Group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Restrict to you own IP
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpn-sg"
  }
}

#================ Key Pair ================
resource "aws_key_pair" "vpn_key" {
  key_name   = "vpn-key"
  public_key = file("keys/public-key.pub")
}

#================ VPN Instance ================
resource "aws_instance" "instance" {
  # Readme Notes
  # This is a openvpn communnity driven ami, you need to first accept EULA from browser.
  ami                    = "ami-00b7bb451c0c20931"
  availability_zone      = "${data.template_file.aws_region.rendered}a"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.vpn_key.key_name
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]
  subnet_id              = aws_subnet.pub_subnet.id
  user_data              = file("user-data/user-data.sh")

  tags = {
    Name = "vpn-instance"
  }
}

#================ Elastic IP ================
resource "aws_eip" "eip" {
  instance = aws_instance.instance.id
  vpc      = "true"
}

resource "aws_eip_association" "eip_assoc_vpn" {
  instance_id   = aws_instance.instance.id
  allocation_id = aws_eip.eip.id
}

# -----------------------------------------------
# -----------------------------------------------
# -----------------------------------------------
# -----------------------------------------------
# EC2 Section

#resources
resource "aws_vpc" "app_vpc" {
  cidr_block = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Environment" = var.environment_tag
    "Name" = "app-vpc"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    "Environment" = var.environment_tag
    "Name" = "app-vpc-igw"
  }
}

resource "aws_subnet" "app_subnet_public" {
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = var.cidr_subnet
  map_public_ip_on_launch = "true"
  availability_zone = var.availability_zone
  tags = {
    "Environment" = var.environment_tag
    "Name" = "app-prv-subnet"
  }
}

resource "aws_route_table" "app_rtb_public" {
  vpc_id = aws_vpc.app_vpc.id

  route {
      cidr_block = "${aws_instance.instance.public_ip}/32"
      gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    "Environment" = var.environment_tag
    "Name" = "prv-rtb"
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.app_subnet_public.id
  route_table_id = aws_route_table.app_rtb_public.id
}

resource "aws_security_group" "app_sg" {
  name = "app-sg"
  vpc_id = aws_vpc.app_vpc.id

  # SSH access from the VPC
  # Need to open SSH for 22 initially to make ansible work, later this port will be blocked from os iptables.
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${aws_instance.instance.public_ip}/32"]
  }

  ingress {
      from_port   = 2224
      to_port     = 2224
      protocol    = "tcp"
      cidr_blocks = ["${aws_instance.instance.public_ip}/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Environment" = var.environment_tag
  }
}

resource "aws_key_pair" "app_vpn_key" {
  key_name   = "app-key"
  public_key = file("keys/public-key.pub")
}

# I am Role
# TO be able to use cloudwatch, we need to associate a role.

resource "aws_iam_role" "web_iam_role" {
  name = "web_iam_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "web_iam_role"
  }
}

resource "aws_iam_instance_profile" "web_iam_profile" {
  name = "web_iam_profile"
  role = aws_iam_role.web_iam_role.name
}


resource "aws_iam_role_policy" "web_iam_policy" {
  name = "web_iam_policy"
  role = aws_iam_role.web_iam_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeTags",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


data "aws_ami" "ubuntu" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

# At this time you should connect openvpn with {aws_eip_association.eip_assoc_vpn.public_ip} with openvpn/admin_34fqerq83t,
# Otherwise ssh will not work in webapp instance.

resource "aws_instance" "web_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.app_subnet_public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name = aws_key_pair.app_vpn_key.key_name
  user_data = file("user-data/web-user-data.sh")
  iam_instance_profile = aws_iam_instance_profile.web_iam_profile.name
  tags = {
		"Environment" = var.environment_tag
    "Name" = "app-instance"
	}

  provisioner "local-exec" {
      command = "sleep 180; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key keys/private-key  --extra-vars VPN_IP=${aws_instance.instance.public_ip} -i ${aws_instance.web_instance.public_ip}, Init.yml"
  }

}

#================ Elastic IP ================
resource "aws_eip" "app_eip" {
  instance = aws_instance.web_instance.id
  vpc      = "true"
}

resource "aws_eip_association" "eip_assoc_web" {
  instance_id   = aws_instance.web_instance.id
  allocation_id = aws_eip.app_eip.id
}


output "VPN-Access-URL" {
  value = "You can Login https://${aws_eip_association.eip_assoc_vpn.public_ip}/admin with openvpn/admin_34fqerq83t"
}


output "App-Access-URL" {
  value = "https://${aws_eip_association.eip_assoc_web.public_ip}"
}


# -----------------------------------------------
# -----------------------------------------------
# -----------------------------------------------
# -----------------------------------------------
# Setting Cloudwatch

resource "aws_sns_topic" "alarm" {
  name = "alarms-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.alarms_email}"
  }
}


### Setting Metrics
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name                = "web-cpu-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  alarm_actions             = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
  }
}

resource "aws_cloudwatch_metric_alarm" "health" {
  alarm_name                = "web-health-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "StatusCheckFailed"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_description         = "This metric monitors ec2 health status"
  alarm_actions             = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
  }
}

# Memory alarm - warning
resource "aws_cloudwatch_metric_alarm" "MemoryWarning" {
	alarm_name = "web-MemoryWarning"
	comparison_operator = "GreaterThanOrEqualToThreshold"
	evaluation_periods = "1"
	metric_name = "MemoryUtilization"
	namespace = "System/Linux"
	period = "120"
	statistic = "Average"
	threshold = var.memory_warning

	alarm_description = "Web - warning for high memory usage"
	alarm_actions = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
  }
}

# Memory alarm - critical
resource "aws_cloudwatch_metric_alarm" "MemoryCritical" {
	alarm_name = "web-MemoryCritical"
	comparison_operator = "GreaterThanOrEqualToThreshold"
	evaluation_periods = "1"
	metric_name = "MemoryUtilization"
	namespace = "System/Linux"
	period = "120"
	statistic = "Average"
	threshold = var.memory_critical

	alarm_description = "Web - critical for high memory usage"
	alarm_actions = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
  }
}

# Disk space alarm - warning
resource "aws_cloudwatch_metric_alarm" "DiskSpaceWarning" {
	alarm_name = "web-DiskSpaceWarning"
	comparison_operator = "GreaterThanOrEqualToThreshold"
	evaluation_periods = "1"
	metric_name = "DiskSpaceUtilization"
	namespace = "System/Linux"
	period = "120"
	statistic = "Average"
	threshold = var.diskspace_warning

	alarm_description = "Web - warning for low available disk space"
	alarm_actions = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
    MountPath = "/"
    Filesystem           = "/dev/root"
  }
}

# Disk space - critical
resource "aws_cloudwatch_metric_alarm" "DiskSpaceCritical" {
	alarm_name = "web-DiskSpaceCritical"
	comparison_operator = "GreaterThanOrEqualToThreshold"
	evaluation_periods = "1"
	metric_name = "DiskSpaceUtilization"
	namespace = "System/Linux"
	period = "120"
	statistic = "Average"
	threshold = var.diskspace_critical

	alarm_description = "Web - critical for low available disk space"
	alarm_actions = [ "${aws_sns_topic.alarm.arn}" ]

  dimensions = {
    InstanceId = aws_instance.web_instance.id
    MountPath = "/"
    Filesystem           = "/dev/root"
  }
}

#Cloudwatch Dashboard

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "WEBAPP"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "System/Linux", "DiskSpaceUtilization", "MountPath", "/", "InstanceId", "${aws_instance.web_instance.id}", "Filesystem", "/dev/root" ]
                ],
                "region": "ap-south-1"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "System/Linux", "MemoryUtilization", "InstanceId", "${aws_instance.web_instance.id}" ]
                ],
                "region": "ap-south-1"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.web_instance.id}" ]
                ],
                "region": "ap-south-1"
            }
        },
        {
            "type": "alarm",
            "x": 0,
            "y": 0,
            "width": 24,
            "height": 3,
            "properties": {
                "title": "",
                "alarms": [
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-health-alarm",
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-MemoryWarning",
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-DiskSpaceWarning",
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-MemoryCritical",
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-cpu-alarm",
                    "arn:aws:cloudwatch:ap-south-1:901377300563:alarm:web-DiskSpaceCritical"
                ]
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 3,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "singleValue",
                "metrics": [
                    [ "System/Linux", "MemoryUtilization", "InstanceId", "${aws_instance.web_instance.id}" ]
                ],
                "region": "ap-south-1"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 3,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "singleValue",
                "metrics": [
                    [ "System/Linux", "DiskSpaceUtilization", "MountPath", "/", "InstanceId", "${aws_instance.web_instance.id}", "Filesystem", "/dev/root" ]
                ],
                "region": "ap-south-1"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 3,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "singleValue",
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.web_instance.id}" ]
                ],
                "region": "ap-south-1"
            }
        }
    ]
}
EOF
}

## AWS Backup Plan

resource "aws_backup_plan" "ec2_backup" {
  name = "web_app_backup_plan"

  rule {
    rule_name         = "web_app_backup_plan_rile"
    target_vault_name = "Default"
    schedule          = "cron(0 12 ? * * *)"
  }
}

## Selecting Resource For Backups
resource "aws_backup_selection" "ec2_selection" {
  # iam_role_arn = aws_iam_role.web_iam_role.arn
  iam_role_arn = "arn:aws:iam::901377300563:role/service-role/AWSBackupDefaultServiceRole"
  name         = "ec2_backup_selection"
  plan_id      = aws_backup_plan.ec2_backup.id

  resources = [
    aws_instance.web_instance.arn
  ]
}
