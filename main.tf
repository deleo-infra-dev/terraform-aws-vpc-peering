data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  current_account_id = data.aws_caller_identity.current.account_id
  current_region = data.aws_region.name

  my_route_tables_per_destination = distinct(flatten([
    for peer_vpc in var.peer_vpcs : [
      for i, route_table_id in peer_vpc.route_table_ids : [
        for j, destination_cidr_block in peer_vpc.destination_cidr_blocks : {
          account_id = peer_vpc.same_account ? null : peer_vpc.account_id
          region = peer_vpc.same_account ? null : peer_vpc.region
          name = "${var.vpc_name}_to_${peer_vpc.name}_${i}_${j}"
          target_vpc = peer_vpc.name
          route_table_id = route_table_id
          destination_cidr_block = destination_cidr_block
        }
      ]
    ]
  ]))

  target_route_tables_per_destination = distinct(flatten([
    for peer_vpc in var.peer_vpcs : [
      for i, reverse_route_table_id in peer_vpc.reverse_route_table_ids : [
        for j, reverse_destination_cidr_block in peer_vpc.reverse_destination_cidr_blocks : {
          account_id = peer_vpc.same_account ? null : local.current_account_id
          region = peer_vpc.same_account ? null : local.current_region
          name = "${peer_vpc.name}_to_${var.vpc_name}_${i}_${j}"
          target_vpc = peer_vpc.name
          route_table_id = reverse_route_table_id
          destination_cidr_block = reverse_destination_cidr_block
        }
      ]
    ]
  ]))
}

resource "aws_vpc_peering_connection" "connections" {
  for_each    = { for peer_vpc in var.peer_vpcs : peer_vpc.name => peer_vpc }
  vpc_id      = "${var.vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id = "${each.value.id}"
  dynamic "different_account" {
    for_each = peer_vpc.same_account ? toset([]) : toset("1")
    content {
      peer_owner_id = local.current_account_id != each.value.account_id ? each.value.account_id : null
      peer_region = local.current_region != each.value.region ? each.value.region: null
    }
  }
  auto_accept = peer_vpc.same_account ? each.value.auto_accept : false

  tags = {
    Name = try(var.vpc_peering_name, "${var.vpc_name}_to_${each.value.name}")
  }
}

resource "aws_vpc_peering_connection_accepter" "connection_accepter" {
  for_each    = { for peer_vpc in var.peer_vpcs : peer_vpc.name => peer_vpc if peer_vpc.same_account == false }
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.connections["${each.value.name}"].id
  auto_accept               = peer_vpc.auto_accept

  tags = merge(
    var.tags,
    {
      Name = try(var.vpc_peering_name, "${var.vpc_name}_to_${each.value.name}")
      Side = "Accepter"
    }
  )
}

resource "aws_vpc_peering_connection_options" "connection_options" {
  for_each    = { for peer_vpc in var.peer_vpcs : peer_vpc.name => peer_vpc }
  vpc_peering_connection_id = aws_vpc_peering_connection.connections["${each.value.name}"].id

  accepter {
    allow_remote_vpc_dns_resolution = each.value.allow_remote_vpc_dns_resolution
  }
}

resource "aws_route" "me_to_target" {
  for_each    = { for item in local.my_route_tables_per_destination : item.name => item }

  route_table_id = "${each.value.route_table_id}"
  destination_cidr_block = "${each.value.destination_cidr_block}"
  vpc_peering_connection_id = aws_vpc_peering_connection.connections["${each.value.target_vpc}"].id
}

resource "aws_route" "target_to_me" {
  for_each    = { for item in local.target_route_tables_per_destination : item.name => item }

  route_table_id = "${each.value.route_table_id}"
  destination_cidr_block = "${each.value.destination_cidr_block}"
  vpc_peering_connection_id = aws_vpc_peering_connection.connections["${each.value.target_vpc}"].id
}