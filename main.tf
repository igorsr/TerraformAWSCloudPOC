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