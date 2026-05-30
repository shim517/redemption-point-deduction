aws_region = "ap-southeast-1"
env        = "production"

vpc_cidr = "10.0.0.0/16"

azs = [
  "ap-southeast-1a",
  "ap-southeast-1b",
  "ap-southeast-1c",
]

public_subnet_cidrs = [
  "10.0.0.0/24",
  "10.0.1.0/24",
  "10.0.2.0/24",
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24",
  "10.0.12.0/24",
]

data_subnet_cidrs = [
  "10.0.20.0/24",
  "10.0.21.0/24",
  "10.0.22.0/24",
]
