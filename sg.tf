resource "aws_security_group" "bastion" {
  name   = var.name
  vpc_id = var.vpc_id
  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "bastion_ssh_ingress" {
  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_all_egress" {
  count = var.create_egress_rule ? 1 : 0

  type              = "egress"
  from_port         = "0"
  to_port           = "65535"
  protocol          = "all"
  cidr_blocks       = var.allowed_egress_cidrs
  ipv6_cidr_blocks  = var.allowed_ipv6_egress_cidrs
  security_group_id = aws_security_group.bastion.id
}
