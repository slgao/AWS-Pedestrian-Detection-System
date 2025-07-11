# Output the launch template ID for use in Auto Scaling Group
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.react_frontend.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.react_frontend.latest_version
}

output "gitlab_repo_url" {
  description = "GitLab repository URL used for deployment"
  value       = var.gitlab_repo_url
}
