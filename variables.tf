variable "vpc_name" {
  description = "vpc name"
  type        = any
  default     = {}
}

variable "vpc_id" {
  description = "vpc id"
  type        = any
  default     = {}
}

variable "route_table_ids" {
  description = "From VPC route table ids"
  type        = list(string)
}

variable "peer_vpcs" {
  description = "A list of peer virtual private clouds"
  type        = any
  default     = [
    {
      name                              = "vpc name"
      id                                = "vpc id"
      auto_accept                       = true
      allow_remote_vpc_dns_resolution   = true

      destination_cidr_blocks           = ["cidr blocks"]         

      reverse_destination_cidr_blocks = ["reverse destination cidr blocks"]
      reverse_route_table_ids = ["reverse route table ids"]
    }
  ]
}