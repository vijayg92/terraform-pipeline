###################################################################################################################
##  Variables
###################################################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}
variable "private_key_path" {}
variable "key_name" {
  default = "DevOps"
}
variable "cidr_address_space" {
  default = "172.15.0.0/16"
}
variable "subnet1_address_space" {
  default = "172.15.1.0/24"
}
variable "subnet2_address_space" {
  default = "172.15.2.0/24"
}
variable "haproxy_elatic_ip" {
  default = "172.15.2.12"
}
###################################################################################################################
##  Providers
###################################################################################################################

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

###################################################################################################################
##  Data
###################################################################################################################

data "aws_availability_zones" "available" {}

###################################################################################################################
##  Resources
###################################################################################################################

## Networking ##
resource "aws_vpc" "vpc" {
    cidr_block = "${var.cidr_address_space}"
    enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "subnet1" {
    cidr_block = "${var.subnet1_address_space}"
    vpc_id =  "${aws_vpc.vpc.id}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
    cidr_block = "${var.subnet2_address_space}"
    vpc_id =  "${aws_vpc.vpc.id}"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

## Routing ##
resource "aws_route_table" "rt" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }
}

resource "aws_route_table_association" "rt-subnet1" {
    subnet_id = "${aws_subnet.subnet1.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table_association" "rt-subnet2" {
    subnet_id = "${aws_subnet.subnet2.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

## Security Group ##
resource "aws_security_group" "haproxy-sg" {

    name = "haproxy-sg"
    vpc_id = "${aws_vpc.vpc.id}"

    ingress{
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["202.142.121.177/32"]
    }

    ingress{
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_eip" "haproxy-eip" {
  vpc = true
}

## Instance ##
resource "aws_instance" "haproxy" {

    ami = "ami-7c87d913"
    instance_type = "t2.medium"
    subnet_id = "${aws_subnet.subnet1.id}"
    vpc_security_group_ids = ["${aws_security_group.haproxy-sg.id}"]
    key_name = "${var.key_name}"

    connection {
      user = "ec2-user"
      private_key = "${file(var.private_key_path)}"
    }

    provisioner "remote-exec" {
      inline = [
      "sudo yum install -y haproxy",
      "sudo mkdir /run/haproxy",
      "sudo chown -R haproxy. /run/haproxy"
      ]
    }

    provisioner "file" {
      source      = "conf"
      destination = "/etc/haproxy"
    }

    provisioner "remote-exec" {
      inline = [
      "sudo chown -R haproxy. /etc/haproxy",
      "sudo service haproxy enable",
      "sudo service haproxy start"
      ]
    }
}

resource "aws_eip_association" "haproxy_eip" {
  instance_id   = "${aws_instance.haproxy.id}"
  allocation_id = "${aws_eip.haproxy-eip.id}"
}

###################################################################################################################
##  Output
###################################################################################################################

output "aws_instance_public_dns" {
    value = "${aws_instance.haproxy.public_dns}"
}
