variable "exoscale_api_key" {
  type = string
}

variable "exoscale_secret_key" {
  type = string
}

variable "zone" {
  type    = string
  default = "at-vie-1"
}

variable "template_name" {
  type    = string
  default = "Linux Fedora CoreOS 42 64-bit"
}

variable "ssh_key" {
  type = map(string)
  default = {
    name       = "exo-prod"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdVnyRKUVfniGe8SuGXs38AaqXI3j2mUx3tf7GQFt7qgufYKCbyd99NpzYKkKP3moxWXCbqO3FfPzSlO9iIIQRx9d58xlriByK4RWAi9/cR7cx5DWz7shkV5JfcrkYvnfFdU3Qic/8fhdXO4yy3pCrBq7ndXqpA+HAFlJkUWAGTlU7L+utTKmqbJG3FC0UfffyhJi25pxWa97z22f/5KS0RAZOV7hJxe70cGSjg10mxzaDq1sSiYkmMXbb8UOc6R/BvO/D4cTVATzP0zck8lq00Jiciau9aXkvTKV2zRUBI5inQwruL2EaY7e/BtiIoSr3HdFdwYeHd09eXznzbQqAQLVTvC41ujJVm7ehQXvSezPhmL81/RYAgIK8KjJh0O64ibC9uhRph9JMaZJeat6AFUZydDGACPof7VQqxeszhqCVBWluujyMQr6NucG/3LsNCSMKVeRtpV/bhw2I5s92jow//ClJTXkZy11Hxp0Di3Kq+EWCyrIu1KysvqYEVdbZNPWjXHNgF+N0bj0RRMhs9Flk/jVzH4P/wCnoX/qim1qEv8jMKZler+TKXSxt1rcNhCZUCSkl5CoZD2SqONy3ItZI2uxdAbBxUjdhO2VB0wc/kW0vz5hJHEVse1yifnOcXIXjD6aLYB9jpjke/3TwtPQmOaI0lxxZhWCTWoCZFQ== bertrand.cachet@exoscale.ch"
  }
}
