data "aws_caller_identity" "current" {}

locals {
  my_route_tables_per_destination = distinct(flatten([
    for peer_vpc in var.peer_vpcs : [
      for i, route_table_id in peer_vpc.route_table_ids : [
        for j, destination_cidr_block in peer_vpc.destination_cidr_blocks : {
          peering_name = peer_vpc.peering_name
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
          peering_name = peer_vpc.peering_name
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
  auto_accept = each.value.auto_accept

  tags = {
    Name = each.value.peering_name
  }
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