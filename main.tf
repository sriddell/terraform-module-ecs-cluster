resource "null_resource" "shared_vars" {
    triggers = {
        base_resource_name = "${var.environment}-${var.product_name}"
    }
}


resource "aws_ecs_cluster" "cluster" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}"
}

data "template_file" "ecs_lc_user_data" {
    template = "${file("${path.module}/templates/container-instance-start.sh")}"

    vars {
        cluster_name = "${aws_ecs_cluster.cluster.name}"
        environment = "${var.environment}"
        vpc_id = "${var.vpc_id}"
        workspace_endpoint = "${var.workspace_endpoint}"
        enable_appdynamics = "${var.enable_appdynamics}"
        appdynamics_agent_access_key_encrypted = "${var.appdynamics_agent_access_key_encrypted}"
        appdynamics_api_user_key_encrypted = "${var.appdynamics_api_user_key_encrypted}"
    }
}

resource "aws_iam_role" "ecs" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs.amazonaws.com", "ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_service" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-service-role"
    assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
                "Service": ["ecs.amazonaws.com", "application-autoscaling.amazonaws.com"]
            }
        }
    ]
}
EOF
}

resource "aws_iam_role" "ecs_task" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-task-role"
    assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            }
        }
    ]
}
EOF
}

resource "aws_iam_policy" "instance_policy" {
    name = "${replace(null_resource.shared_vars.triggers.base_resource_name,".","_")}-ecs-instance-policy"
    description = "Contains a copy of AmazonEC2ContainerServiceforEC2Role due to a Terraform bug"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "service_policy" {
    name = "${replace(null_resource.shared_vars.triggers.base_resource_name,".","_")}-ecs-service-policy"
    description = "Scaling policy used by ECS services and copies of AmazonEC2ContainerServiceRole and AmazonEC2ContainerServiceAutoscaleRole due to a Terraform bug"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "application-autoscaling:*",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:PutMetricAlarm",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs" {
    role = "${aws_iam_role.ecs.id}"
    policy_arn = "${aws_iam_policy.instance_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "ecs_service" {
    role = "${aws_iam_role.ecs_service.id}"
    policy_arn = "${aws_iam_policy.service_policy.arn}"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-instance-profile"
    role = "${aws_iam_role.ecs.name}"
    # get around https://github.com/hashicorp/terraform/issues/5862 until terraform updated to 0.6.15
    provisioner "local-exec" {
        command = "sleep 30"
    }
}

resource "aws_security_group" "container_instance" {
    vpc_id = "${var.vpc_id}"
    name = "${null_resource.shared_vars.triggers.base_resource_name}-container-instance-sg"
    description = "Security group for ssh and ephemeral docker ports to container instances"

    ingress {
        from_port = 32768
        to_port = 61000
        protocol = "tcp"
        cidr_blocks = ["${var.vpc_cidr_block}"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.vpc_cidr_block}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_configuration" "ecs" {
    depends_on = ["aws_iam_instance_profile.ecs_instance_profile"]
    name_prefix = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-lc"
    image_id = "${var.ami_id}"
    instance_type = "${var.instance_type}"
    iam_instance_profile = "${aws_iam_instance_profile.ecs_instance_profile.id}"
    associate_public_ip_address = false
    key_name = "${var.key_name}"
    security_groups = ["${concat(var.container_instance_sec_group_ids,list(aws_security_group.container_instance.id))}"]
    user_data = "${data.template_file.ecs_lc_user_data.rendered}"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "ecs" {
    name = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-asg"
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]
    min_size = "${var.asg_min_size}"
    max_size = "${var.asg_max_size}"
    desired_capacity = "${var.asg_desired_capacity}"
    launch_configuration = "${aws_launch_configuration.ecs.id}"

    lifecycle {
        create_before_destroy = true
    }

    tag {
        key = "Name"
        value = "${null_resource.shared_vars.triggers.base_resource_name}-ecs-instance"
        propagate_at_launch = true
    }
    tag {
        key = "Environment"
        value = "${var.environment}"
        propagate_at_launch = true
    }
    tag {
        key = "Service"
        value = "${null_resource.shared_vars.triggers.base_resource_name}"
        propagate_at_launch = true
    }
    tag {
        key = "Group"
        value = "${var.product_name}"
        propagate_at_launch = true
    }
    tag {
        key = "CostCenter"
        value = "${var.costcenter}"
        propagate_at_launch = true
    }
    tag {
        key = "Expiration"
        value = "${var.expiration}"
        propagate_at_launch = true
    }
    tag {
        key = "POC"
        value = "${var.poc}"
        propagate_at_launch = true
    }
}
