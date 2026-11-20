variable "cloud_id" { type = string }
variable "folder_id" { type = string }
variable "zone" { type = string }

variable "ssh_public_key" { type = string }
variable "ssh_user" {
  type    = string
  default = "Ollrins"
}

variable "vm_image_id" {
  type    = string
  default = "fd828j3n8sa03unu5arm"
}

variable "master_cores" {
  type    = number
  default = 2
}
variable "master_memory" {
  type    = number
  default = 4
}
variable "worker_cores" {
  type    = number
  default = 2
}
variable "worker_memory" {
  type    = number
  default = 4
}
variable "core_fraction" {
  type    = number
  default = 20
}
variable "disk_size" {
  type    = number
  default = 15
}
variable "disk_type" {
  type    = string
  default = "network-ssd"
}

variable "network_name" {
  type    = string
  default = "terragrunt-network"
}
variable "master_name_prefix" {
  type    = string
  default = "terragrunt-master"
}
variable "worker_name_prefix" {
  type    = string
  default = "terragrunt-worker"
}
variable "sg_name" {
  type    = string
  default = "terragrunt-sg"
}
variable "registry_name" {
  type    = string
  default = "terragrunt-registry"
}
variable "master_count" {
  type    = number
  default = 1
}
variable "worker_count" {
  type    = number
  default = 2
}
variable "timezone" {
  type    = string
  default = "Europe/Moscow"
}
