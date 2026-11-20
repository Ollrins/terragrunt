output "master_ips" {
  value = yandex_compute_instance.k8s-master[*].network_interface[0].nat_ip_address
}

output "worker_ips" {
  value = yandex_compute_instance.k8s-worker[*].network_interface[0].nat_ip_address
}

output "all_ips" {
  value = concat(
    yandex_compute_instance.k8s-master[*].network_interface[0].nat_ip_address,
    yandex_compute_instance.k8s-worker[*].network_interface[0].nat_ip_address
  )
}

output "registry_id" {
  value = yandex_container_registry.main.id
}

output "network_id" {
  value = yandex_vpc_network.main.id
}

output "subnet_id" {
  value = yandex_vpc_subnet.main.id
}

output "security_group_id" {
  value = yandex_vpc_security_group.main.id
}
