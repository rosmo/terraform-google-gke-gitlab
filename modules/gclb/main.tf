/**
 * Copyright 2021 Google LLC
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

// Healthchecks
resource "google_compute_health_check" "gitlab_health_check" {
  name = "gitlab-health-check"

  timeout_sec        = 15
  check_interval_sec = 30

  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path       = "/-/health"
    port_specification = "USE_SERVING_PORT"
  }

  log_config {
    enable = true
  }
}

resource "google_compute_health_check" "gitlab_registry_health_check" {
  name = "gitlab-registry-health-check"

  timeout_sec        = 15
  check_interval_sec = 30

  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path       = "/"
    port_specification = "USE_SERVING_PORT"
  }

  log_config {
    enable = true
  }
}

// Firewall rules for healthchecks and load balancers
resource "google_compute_firewall" "allow_gclb" {
  name    = "gitlab-allow-gclb"
  network = var.network

  allow {
    protocol = "tcp"
    // ports    = ["5001", "8080", "8081"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags   = ["gitlab"]
}

resource "google_compute_firewall" "allow_ilb" {
  name    = "gitlab-allow-ilb"
  network = var.network

  allow {
    protocol = "tcp"
  }

  source_ranges = [var.gitlab_proxy_only_subnet_cidr]
  target_tags   = ["gitlab"]
}

resource "google_compute_health_check" "gitlab_ssh_health_check" {
  name = "gitlab-ssh-health-check"

  timeout_sec        = 15
  check_interval_sec = 30

  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port_specification = "USE_SERVING_PORT"
  }

  log_config {
    enable = true
  }
}

// GCLB backends
resource "google_compute_backend_service" "gitlab_webservice_backend" {
  name = "gitlab-webservice-backend"

  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  log_config {
    enable = var.gclb_logging ? true : false
  }

  health_checks = [google_compute_health_check.gitlab_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

resource "google_compute_backend_service" "gitlab_workhorse_backend" {
  name = "gitlab-workhorse-backend"

  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  log_config {
    enable = var.gclb_logging ? true : false
  }

  health_checks = [google_compute_health_check.gitlab_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

resource "google_compute_backend_service" "gitlab_registry_backend" {
  name = "gitlab-registry-backend"

  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  log_config {
    enable = var.gclb_logging ? true : false
  }

  health_checks = [google_compute_health_check.gitlab_registry_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

resource "google_compute_backend_service" "gitlab_ssh_backend" {
  name = "gitlab-ssh-backend"

  load_balancing_scheme = "EXTERNAL"
  protocol              = "TCP"

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  health_checks = [google_compute_health_check.gitlab_ssh_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

resource "google_compute_region_backend_service" "gitlab_webservice_region_backend" {
  name = "gitlab-webservice-ilb-backend"

  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  region                = var.region

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  log_config {
    enable = var.gclb_logging ? true : false
  }

  health_checks = [google_compute_health_check.gitlab_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

resource "google_compute_region_backend_service" "gitlab_workhorse_region_backend" {
  name = "gitlab-workhorse-ilb-backend"

  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  region                = var.region

  timeout_sec                     = 600
  connection_draining_timeout_sec = 60

  log_config {
    enable = var.gclb_logging ? true : false
  }

  health_checks = [google_compute_health_check.gitlab_health_check.id]

  lifecycle {
    ignore_changes = [backend]
  }
}

// GCLB load balancer components
resource "google_compute_url_map" "urlmap" {
  name = "gitlab-urlmap"

  default_service = google_compute_backend_service.gitlab_webservice_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "gitlab-web"
  }

  host_rule {
    hosts        = [format("registry.gitlab.%s", var.domain)]
    path_matcher = "gitlab-registry"
  }

  path_matcher {
    name            = "gitlab-web"
    default_service = google_compute_backend_service.gitlab_workhorse_backend.id

    path_rule {
      paths   = ["/admin/sidekiq"]
      service = google_compute_backend_service.gitlab_webservice_backend.id
    }
  }

  path_matcher {
    name            = "gitlab-registry"
    default_service = google_compute_backend_service.gitlab_registry_backend.id
  }
}

resource "google_compute_region_url_map" "region_urlmap" {
  name   = "gitlab-ilb-urlmap"
  region = var.region

  default_service = google_compute_region_backend_service.gitlab_webservice_region_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "gitlab-web"
  }

  path_matcher {
    name            = "gitlab-web"
    default_service = google_compute_region_backend_service.gitlab_workhorse_region_backend.id

    path_rule {
      paths   = ["/admin/sidekiq"]
      service = google_compute_region_backend_service.gitlab_webservice_region_backend.id
    }
  }
}

resource "google_compute_managed_ssl_certificate" "certificate" {
  name = "gitlab-cert"

  managed {
    domains = [format("gitlab.%s.", var.domain), format("registry.gitlab.%s.", var.domain)]
  }
}

resource "google_compute_target_https_proxy" "target_proxy" {
  name             = "gitlab-proxy"
  url_map          = google_compute_url_map.urlmap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.certificate.id]
}

resource "google_compute_region_target_http_proxy" "region_target_proxy" {
  region  = var.region
  name    = "gitlab-ilb-proxy"
  url_map = google_compute_region_url_map.region_urlmap.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "gitlab-fr"
  target     = google_compute_target_https_proxy.target_proxy.id
  ip_address = var.gitlab_address
  port_range = "443"
}

resource "google_compute_address" "internal_address" {
  name         = "gitlab-ilb-ip"
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_compute_forwarding_rule" "internal_forwarding_rule" {
  provider = google-beta

  name   = "gitlab-ilb-fr"
  region = var.region

  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  network_tier          = "PREMIUM"

  ip_address = google_compute_address.internal_address.address
  target     = google_compute_region_target_http_proxy.region_target_proxy.id
  network    = var.network
  subnetwork = var.subnetwork
}

resource "google_compute_global_address" "ssh_address" {
  name         = "gitlab-ssh"
  address_type = "EXTERNAL"
}

resource "google_compute_target_tcp_proxy" "ssh_target_proxy" {
  name            = "gitlab-ssh-tcp-proxy"
  backend_service = google_compute_backend_service.gitlab_ssh_backend.id
}

resource "google_compute_global_forwarding_rule" "ssh_forwarding_rule" {
  name       = "gitlab-ssh-fr"
  target     = google_compute_target_tcp_proxy.ssh_target_proxy.id
  ip_address = google_compute_global_address.ssh_address.address
  port_range = "5222"
}
