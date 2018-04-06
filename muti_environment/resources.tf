#########################################################################################################
#### RESOURCES                                                                                       ####
#########################################################################################################

resource "aws_vpc" "vpc" {
	cidr_block = "${var.aws_vpc_cidr}"
	tags {
		Name = "${var.environment_tag}-vpc"
		Environment = "${var.environment_tag}"
	}
}

resource "aws_internet_gateway" "igw" {
	vpc_id = "${aws_vpc.vpc.id}"
	tags {
                Name = "${var.environment_tag}-igw"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_subnet" "subnet" {
	count = "${var.subnet_count}"
	cidr_block = "${cidrsubnet(var.network_address_space, 8, count.index +1)}"
	vpc_id = "${aws_vpc.vpc.id}"
	availability_zone = "${data.aws_availability_zone.available.names[count.index]}"
        tags {
                Name = "${var.environment_tag}-subnet-${count.index +1}"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_route_table" "rtb" {
	vpc_id = "${aws_vpc.vpc.id}"
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.igw.id}"
	}
        tags {
                Name = "${var.environment_tag}-rtb"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_route_table_association" "rta-subnet" {
	count = "${var.subnet_count}"
	subnet_id = "${element(aws_subnet.subnet.*.id,count.idex)}"
	route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_security_group" "elb-sg" {
	name = "nginx_elb_sg"
	vpc_id = "${aws_vpc.vpc.id}"

	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = [0.0.0.0/0"]
	}
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
        tags {
                Name = "${var.environment_tag}-elb-sg"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_security_group" "nginx-sg" {
        name = "nginx_sg"
        vpc_id = "${aws_vpc.vpc.id}"

        ingress {
                from_port = 22
                to_port = 22
                protocol = "tcp"
                cidr_blocks = ["0.0.0.0/0"]
        }
	ingress {      
                from_port = 80
                to_port = 80
                protocol = "tcp"
                cidr_blocks = ["${var.network_address_space}"]
        }
        egress {
                from_port = 0
                to_port = 0
                protocol = "-1"
                cidr_blocks = ["0.0.0.0/0"]
        }
        tags {
                Name = "${var.environment_tag}-nginx-sg"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_elb" "web" {
	name = "${var.environment_tag}-nginx-elb"
	subnets = ["${aws_subnet.subnet.*.id"}]
	security_groups = ["${aws_security_group.elb-sg.id}"}
	instances = ["${aws_instance.nginx.*.id}"]
	
	listener {
		instance_port = 80
		instance_protocol = "http"
		lb_port = 80
		lb_protocol = "tcp"
	}
        tags {
                Name = "${var.environment_tag}-elb"
                Environment = "${var.environment_tag}"
        }
}

resource "aws_instance" "nginx" {
	count = "${var.instance_count}"
	ami = "ami-7c87d913" 
	instance_type = "t2.micro"
	subnet_id = "${element(aws_subnet.*.id,count.index % var.subnet_count)}"
	vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
	key_name = "${var.key_name}"

	connection {
		user = "ec2-user"
	}

	provisioner "remote-exec" {
      	   inline = [
      	      "sudo yum install -y nginx",
	      "sudo service nginx enable",
	      "sudo service nginx start"
      	   ]
    	}
}
