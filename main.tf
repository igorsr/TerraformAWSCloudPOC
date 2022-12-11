# Require TF version to be same as or greater than 0.12.13
terraform {
  required_version = ">=1.3.6"
  backend "s3" {
    bucket         = "igorrusso-terraform-test"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-locks"
    encrypt        = true
  }
}

# Download any stable version in AWS provider of 2.36.0 or higher in 2.36 train
provider "aws" {
  region  = "us-east-1"
  version = "~> 2.36.0"
}


module "bootstrap" {
  source                      = "./modules/bootstrap"
  name_of_s3_bucket           = "igorrusso-terraform-test"
  dynamo_db_table_name        = "aws-locks"
}





# Criação da VPC
resource "aws_vpc" "igorrusso_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "igorrusso_vpc"
  }
}

# Criação da Subnet Pública
resource "aws_subnet" "igorrusso_public_subnet" {
  vpc_id     = aws_vpc.igorrusso_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "igorrusso_public_subnet"
  }
}

# Criação do Internet Gateway
resource "aws_internet_gateway" "igorrusso_igw" {
  vpc_id = aws_vpc.igorrusso_vpc.id

  tags = {
    Name = "igorrusso_igw"
  }
}

# Criação da Tabela de Roteamento
resource "aws_route_table" "igorrusso_rt" {
  vpc_id = aws_vpc.igorrusso_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igorrusso_igw.id
  }

  tags = {
    Name = "igorrusso_rt"
  }
}

# Criação da Rota Default para Acesso à Internet
resource "aws_route" "igorrusso_routetointernet" {
  route_table_id            = aws_route_table.igorrusso_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igorrusso_igw.id
}


# Associação da Subnet Pública com a Tabela de Roteamento
resource "aws_route_table_association" "igorrusso_pub_association" {
  subnet_id      = aws_subnet.igorrusso_public_subnet.id
  route_table_id = aws_route_table.igorrusso_rt.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

   owners = ["099720109477"] # Canonical
  
}


resource "aws_instance" "tcb_blog_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = "dev" # Insira o nome da chave criada antes.
  subnet_id = aws_subnet.igorrusso_public_subnet.id
  vpc_security_group_ids = [aws_security_group.permitir_ssh_http.id]
  associate_public_ip_address = true

  tags = {
    Name = "ec2_do_igao"  
  }
}



resource "aws_security_group" "permitir_ssh_http" {
  name        = "permitir_ssh"
  description = "Permite SSH e HTTP na instancia EC2"
  vpc_id      = aws_vpc.igorrusso_vpc.id

  ingress {
    description = "SSH to EC2"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP to EC2"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "permitir_ssh_e_http"
  }
}