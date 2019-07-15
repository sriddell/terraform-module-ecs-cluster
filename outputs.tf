output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "cluster_id" {
  value = aws_ecs_cluster.cluster.id
}

output "cluster_asg_name" {
  value = aws_autoscaling_group.ecs.name
}

output "service_role_arn" {
  value = aws_iam_role.ecs_service.arn
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "container_instance_role" {
  value = aws_iam_role.ecs.name
}

