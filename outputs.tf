output "instance" {
  value = aws_instance.bmlt.id
}

output "ip" {
  value = aws_eip.bmlt.public_ip
}
