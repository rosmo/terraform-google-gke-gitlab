/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "gke_auth" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version = "~> 10.0"

  project_id   = module.project_services.project_id
  cluster_name = var.gke_private ? module.gke_private["gke"].name : module.gke_public["gke"].name
  location     = var.gke_private ? module.gke_private["gke"].location : module.gke_public["gke"].location
}

provider "helm" {
  kubernetes {
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
    host                   = module.gke_auth.host
    token                  = module.gke_auth.token
  }
}

provider "kubernetes" {
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
}

// Services
module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 11.0"

  project_id                  = var.project_id
  disable_services_on_destroy = false

  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "redis.googleapis.com"
  ]
}

// Networking
resource "google_compute_network" "gitlab" {
  name                    = "gitlab"
  project                 = module.project_services.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "gitlab"
  ip_cidr_range = var.gitlab_nodes_subnet_cidr
  region        = var.region
  network       = google_compute_network.gitlab.self_link

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gitlab-cluster-pod-cidr"
    ip_cidr_range = var.gitlab_pods_subnet_cidr
  }

  secondary_ip_range {
    range_name    = "gitlab-cluster-service-cidr"
    ip_cidr_range = var.gitlab_services_subnet_cidr
  }
}

resource "google_compute_subnetwork" "proxy_only_subnetwork" {
  count    = var.use_gclb ? 1 : 0
  provider = google-beta

  name          = "gitlab-proxy-only"
  ip_cidr_range = var.gitlab_proxy_only_subnet_cidr
  region        = var.region
  network       = google_compute_network.gitlab.self_link

  purpose = "INTERNAL_HTTPS_LOAD_BALANCER"
  role    = "ACTIVE"
}

// GKE Service Account
resource "google_service_account" "gitlab_gke" {
  account_id   = "gitlab-gke"
  display_name = "Gitlab GKE Service Account"
}

resource "google_project_iam_member" "gitlab_gke_permissions" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/monitoring.viewer"])

  project = var.project_id
  role    = each.value
  member  = format("serviceAccount:%s", google_service_account.gitlab_gke.email)
}

// GKE Cluster (private)
module "gke_private" {
  for_each = var.gke_private ? toset(["gke"]) : toset([])

  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 16.0"

  # Create an implicit dependency on service activation
  project_id = module.project_services.project_id

  name            = "gitlab"
  region          = var.region
  regional        = true
  release_channel = var.gke_release_channel

  remove_default_node_pool = true
  initial_node_count       = 1

  network           = google_compute_network.gitlab.name
  subnetwork        = google_compute_subnetwork.subnetwork.name
  ip_range_pods     = "gitlab-cluster-pod-cidr"
  ip_range_services = "gitlab-cluster-service-cidr"

  enable_shielded_nodes  = true
  enable_private_nodes   = true
  master_ipv4_cidr_block = var.gitlab_master_subnet_cidr

  node_pools = [
    {
      name            = "gitlab"
      service_account = google_service_account.gitlab_gke.email

      autoscaling    = var.gke_autoscale_max > 0 ? true : false
      min_node_count = var.gke_autoscale_min
      max_node_count = var.gke_autoscale_max

      preemptible  = var.gke_preemptible_nodes
      machine_type = var.gke_machine_type

      enable_secure_boot          = true
      enable_integrity_monitoring = true

      node_count = var.gke_autoscale_min
    },
  ]

  identity_namespace = var.use_gclb || var.gke_workload_identity ? "enabled" : null
  node_metadata      = var.use_gclb || var.gke_workload_identity ? "GKE_METADATA_SERVER" : "SECURE"

  node_pools_tags = {
    all = ["gitlab"]
  }

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

// GKE Cluster (public)
module "gke_public" {
  for_each = !var.gke_private ? toset(["gke"]) : toset([])

  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 16.0"

  # Create an implicit dependency on service activation
  project_id = module.project_services.project_id

  name            = "gitlab"
  region          = var.region
  regional        = true
  release_channel = var.gke_release_channel

  remove_default_node_pool = true
  initial_node_count       = 1

  network           = google_compute_network.gitlab.name
  subnetwork        = google_compute_subnetwork.subnetwork.name
  ip_range_pods     = "gitlab-cluster-pod-cidr"
  ip_range_services = "gitlab-cluster-service-cidr"

  enable_shielded_nodes = true

  node_pools = [
    {
      name            = "gitlab"
      service_account = google_service_account.gitlab_gke.email

      autoscaling    = var.gke_autoscale_max > 0 ? true : false
      min_node_count = var.gke_autoscale_min
      max_node_count = var.gke_autoscale_max

      preemptible  = var.gke_preemptible_nodes
      machine_type = var.gke_machine_type

      enable_secure_boot          = true
      enable_integrity_monitoring = true

      node_count = var.gke_autoscale_min
    },
  ]

  identity_namespace = var.use_gclb || var.gke_workload_identity ? "enabled" : null
  node_metadata      = var.use_gclb || var.gke_workload_identity ? "GKE_METADATA_SERVER" : "SECURE"

  node_pools_tags = {
    all = ["gitlab"]
  }

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# GKE Autoneg setup
module "autoneg" {
  count = var.use_gclb ? 1 : 0

  source = "./modules/autoneg"

  project_id = var.project_id
}

# Cloud Router & NAT for private nodes
resource "google_compute_router" "router" {
  count = var.gke_private ? 1 : 0

  name    = "gitlab-router"
  region  = var.region
  network = google_compute_network.gitlab.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  count = var.gke_private ? 1 : 0

  name                               = "gitlab-nat"
  router                             = google_compute_router.router[0].name
  region                             = google_compute_router.router[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

// Gitlab
module "gitlab" {
  source = "./modules/gitlab"

  project_id = module.project_services.project_id

  region            = var.region
  domain            = var.domain
  certmanager_email = var.certmanager_email

  network    = google_compute_network.gitlab.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  gitlab_db_name          = var.gitlab_db_name
  gitlab_db_random_prefix = var.gitlab_db_random_prefix
  gitlab_db_password      = var.gitlab_db_password

  gitlab_address_name           = var.gitlab_address_name
  gitlab_runner_install         = var.gitlab_runner_install
  gitlab_values_template        = "${path.module}/values.yaml.tpl"
  gitlab_proxy_only_subnet_cidr = var.gitlab_proxy_only_subnet_cidr

  use_gclb     = var.use_gclb
  gclb_logging = var.gclb_logging

  gcs_uniform_access = var.gcs_uniform_access

  helm_chart_version  = var.helm_chart_version
  allow_force_destroy = var.allow_force_destroy
}
