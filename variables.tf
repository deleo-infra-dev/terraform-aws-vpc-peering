variable "vpc_id" {
  description = "vpc id"
  type        = any
  default     = {}
}

variable "peer_vpcs" {
  description = "A list of peer virtual private clouds"
  type        = list(map(string))
  default     = [
    {
      name                              = "name"
      id                                = "id"
      auto_accept                       = true
      allow_remote_vpc_dns_resolution   = true
    }
  ]
}