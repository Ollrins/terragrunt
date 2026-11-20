# ==========================================
# Сетевая инфраструктура
# ==========================================

resource "yandex_vpc_network" "main" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "main" {
  name           = "${var.network_name}-subnet-${var.zone}"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# ==========================================
# Security Group (правила firewall)
# ==========================================

resource "yandex_vpc_security_group" "main" {
  name        = var.sg_name
  description = "Security group for Terragrunt-managed Kubernetes cluster"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "ANY"
    description    = "Allow all traffic between VMs in subnet"
    v4_cidr_blocks = ["192.168.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 22
    to_port        = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 6443
    to_port        = 6443
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow NodePort range"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow kubelet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 10250
    to_port        = 10250
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow etcd"
    v4_cidr_blocks = ["192.168.0.0/16"]
    from_port      = 2379
    to_port        = 2380
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 80
    to_port        = 80
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 443
    to_port        = 443
  }
  ingress {
    protocol       = "TCP"
    description    = "Allow Terragrunt report (nginx)"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 8080
    to_port        = 8080
  }
  egress {
    protocol       = "ANY"
    description    = "Allow all egress"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# ==========================================
# Master-нода Kubernetes
# ==========================================

resource "yandex_compute_instance" "k8s-master" {
  count       = var.master_count
  name        = "k8s-master-0${count.index + 1}"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores         = var.master_cores
    memory        = var.master_memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_image_id
      size     = var.disk_size
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.main.id]
  }

  scheduling_policy {
    preemptible = false
  }

  metadata = {
    ssh-keys  = "${var.ssh_user}:${file(var.ssh_public_key)}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      hostname       = "k8s-master-0${count.index + 1}"
      ssh_user       = var.ssh_user
      ssh_public_key = file(var.ssh_public_key)
      timezone       = var.timezone
    })
  }
}

# ==========================================
# Worker-ноды Kubernetes
# ==========================================

resource "yandex_compute_instance" "k8s-worker" {
  count       = var.worker_count
  name        = "k8s-worker-0${count.index + 1}"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores         = var.worker_cores
    memory        = var.worker_memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_image_id
      size     = var.disk_size
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.main.id]
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys  = "${var.ssh_user}:${file(var.ssh_public_key)}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      hostname       = "k8s-worker-0${count.index + 1}"
      ssh_user       = var.ssh_user
      ssh_public_key = file(var.ssh_public_key)
      timezone       = var.timezone
    })
  }
}

# ==========================================
# Container Registry
# ==========================================

resource "yandex_container_registry" "main" {
  name      = var.registry_name
  folder_id = var.folder_id
}
