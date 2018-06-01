data "aws_ami" "coreos" {
  most_recent = true
  owners = ["595879546273"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "name"
    values = ["CoreOS-stable-*"]
  }
}

data "ignition_user" "tunnel" {
  name = "tunnel"
  no_create_home = true
  shell = "/bin/false"
}

data "ignition_file" "sshd_config" {
  path = "/etc/ssh/sshd_config"
  filesystem = "root"
  content {
    content = <<EOF
AllowUsers ${join(" ",var.allowed_users)}
AuthenticationMethods publickey
PermitRootLogin no
AuthorizedKeysCommandUser root
AuthorizedKeysCommand /etc/ssh/authorized_keys.sh %u %f
EOF
  }
}

data "ignition_file" "sshd_authorized_keys" {
  path = "/etc/ssh/authorized_keys.sh"
  filesystem = "root"
  mode = "493"
  uid = "0"
  gid = "0"
  content {
    content = <<EOF
#!/bin/bash
curl -sf "${aws_s3_bucket.ssh_public_keys.website_endpoint}/$${2/SHA256:/}"
EOF
  }
}

data "ignition_systemd_unit" "sshd_port" {
  name = "sshd.socket"
  dropin = [{
    name = "10-sshd-port.conf"
    content = <<EOF
[Socket]
ListenStream=
ListenStream=${var.ssh_port}
EOF
  }]
}

data "ignition_systemd_unit" "mask_docker" {
  name = "docker.service"
  mask = true
}

data "ignition_systemd_unit" "mask_containerd" {
  name = "containerd.service"
  mask = true
}

data "ignition_config" "bastion" {
  systemd = [
    "${data.ignition_systemd_unit.sshd_port.id}",
    "${data.ignition_systemd_unit.mask_containerd}",
    "${data.ignition_systemd_unit.mask_docker}",
  ]
  users = [
    "${data.ignition_user.tunnel.id}",
  ]
  files = [
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.sshd_authorized_keys.id}",
  ]
}

resource "aws_launch_configuration" "bastion" {
  image_id = "${data.aws_ami.coreos.image_id}"
  instance_type = "${var.instance_type}"
  user_data = "${data.ignition_config.bastion.rendered}"
  enable_monitoring = true
  security_groups = [
    "${aws_security_group.bastion.id}"
  ]
  root_block_device {
    volume_size = "8"
  }
  iam_instance_profile = "${var.iam_instance_profile}"
  associate_public_ip_address = "${var.associate_public_ip_address}"
  key_name = "${var.key_name}"
  lifecycle {
    create_before_destroy = true
  }
}
