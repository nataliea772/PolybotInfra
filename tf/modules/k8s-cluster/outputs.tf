output "control_plane_instance_id" {
  description = "ID of the control plane EC2 instance"
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Public IP address of the control plane EC2"
  value       = aws_instance.control_plane.public_ip
}

output "worker_public_ip" {
  value = aws_instance.worker_node.public_ip
}
