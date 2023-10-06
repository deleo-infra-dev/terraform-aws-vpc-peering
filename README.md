# terraform aws vpc peering
Terraform module that creates vpc peering and route tables. 

## Note
**Currently, only VPC peering of the same account is possible.**

## Example
```hcl
data "terraform_remote_state" "target_vpc" {
  backend = "s3"

  config = {
    bucket = "bucket name"
    region = "region name"
    key    = "state file key"
  }
}

################################################################################
# VPC Peering
################################################################################

module "vpc_peering" {
  source  = "rayshoo/vpc-peering/aws"
  version = "1.0.0"

  vpc_name              = "vpc_name"
  vpc_id                = "vpc id"

  peer_vpcs             = [
    {
      name = "target vpc name"
      id = data.terraform_remote_state.target_vpc.outputs.vpc_id
      auto_accept                       = true
      allow_remote_vpc_dns_resolution   = true

      route_table_ids                   = module.vpc.private_route_table_ids
      destination_cidr_blocks           = data.terraform_remote_state.target_vpc.outputs.destination_cidr_blocks
      reverse_route_table_ids           = data.terraform_remote_state.target_vpc.outputs.route_table_ids
      reverse_destination_cidr_blocks   = ["my_destination_cidr_blocks"]
    }
  ]
}
```