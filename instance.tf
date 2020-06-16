/*
Creator : Mohit Singh
Github: devmohit-live
LinkedIn: devmohitsingh
*/

provider "aws" {
  region  = "ap-south-1"
}

// key pair generation
resource "tls_private_key" "this" {
  algorithm = "RSA"
}
module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "autokey"
  public_key = tls_private_key.this.public_key_openssh
}

// security group creation
resource "aws_security_group" "web" {
  name        = "HTTP"
  description = "security group for webservers"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web"
  }
}


// instance creation
resource "aws_instance"  "webserver" {
  depends_on= [aws_security_group.web]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name	= "autokey"
  security_groups =  [ "launch-wizard-2" ] 
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.this.private_key_pem
    host     = aws_instance.webserver.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }
  
  tags = {
    Name = "myos"
  }
}


// EBS creation
resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.webserver.availability_zone
  size = 1
  tags = {
    Name = "myebs"
  }
  depends_on= [aws_security_group.web]
}

// EBS attachment
resource "aws_volume_attachment" "ebs_att" {
  depends_on=[aws_ebs_volume.myebs]
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.myebs.id}"
  instance_id = "${aws_instance.webserver.id}"
  force_detach = true
}


// Partiton and Formatting of the  attached EBS
resource "null_resource" "part"  {
    depends_on = [
    aws_volume_attachment.ebs_att,
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.this.private_key_pem
    host     = aws_instance.webserver.public_ip
  }
    provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/devmohit-live/Terraform_AWS_Webserver.git /var/www/html/"
        ]
    }
}

// getting the webserver's IP
output "myos_ip" {
  depends_on=[null_resource.part]
  value = aws_instance.webserver.public_ip
}

