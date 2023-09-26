data "aws_caller_identity" "current" {}

resource "aws_vpc_peering_connection" "connections" {
  for_each    = { for peer_vpc in var.peer_vpcs : peer_vpc.name => peer_vpc }
  vpc_id      = "${var.vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id = "${each.value.id}"
  auto_accept = each.value.auto_accept
}

resource "aws_vpc_peering_connection_options" "connection_options" {
  for_each    = { for peer_vpc in var.peer_vpcs : peer_vpc.name => peer_vpc }
  vpc_peering_connection_id = aws_vpc_peering_connection.connections["${each.value.name}"].id

  accepter {
    allow_remote_vpc_dns_resolution = each.value.allow_remote_vpc_dns_resolution
  }
}