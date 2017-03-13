resource "aws_vpc" "default" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "example-1-vpc"
    }
}

resource "aws_internet_gateway" "default"{
	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_subnet" "us-west-2a-public" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.public_subnet_cidr}"
    availability_zone = "us-west-2a"

    tags {
        Name = "Public Subnet exmpl-1"
    }
}

resource "aws_subnet" "us-west-2a-private" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.private_subnet_cidr}"
    availability_zone = "us-west-2a"

    tags {
        Name = "Private Subnet exmpl-1"
    }
}

resource "aws_route_table" "us-west-2a-public"{
	vpc_id = "${aws_vpc.default.id}"
	
	route{
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}

	tags{
		Name = "route-table-1"
	}
}

resource "aws_route_table_association" "us-west-2a-private" {
    subnet_id = "${aws_subnet.us-west-2a-private.id}"
    route_table_id = "${aws_route_table.us-west-2a-public.id}"
}

resource "aws_security_group" "sg-App-server" {
    name = "vpc_sg-App-server"
    description = "Allow traffic to pass to the public subnet from the internet"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${aws_vpc.default.id}"

    tags {
        Name = "terraform-sg-App-server"
    }
}
 

resource "aws_instance" "App-server" {
  ami           = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.sg-App-server.id}"]
  subnet_id = "${aws_subnet.us-west-2a-private.id}"
  associate_public_ip_address = true
  private_ip = "${var.private-ip}"
  source_dest_check = false

  tags {
      Name = "terraform-App-server "
  }

  provisioner "local-exec" {
    command = "scp -i /home/kuldeep/Downloads/kuldeep-key-1.pem -o StrictHostKeyChecking=no /home/kuldeep/.ssh/id_rsa.pub centos@${aws_instance.App-server.public_ip}:/home/centos/.ssh/authorized_keys"
    
  }
  provisioner "local-exec"{
    command = "ansible-playbook -i \"${aws_instance.App-server.public_ip},\" rails/rails.yml --user=centos"
  }
}
