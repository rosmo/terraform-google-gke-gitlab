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

output "gitlab_address" {
  value       = module.gitlab.gitlab_address
  description = "IP address where you can connect to your GitLab instance"
}

output "gitlab_url" {
  value       = module.gitlab.gitlab_url
  description = "URL where you can access your GitLab instance"
}

output "cluster_name" {
  value       = var.gke_private ? module.gke_private["gke"].name : module.gke_public["gke"].name
  description = "Name of the GKE cluster that GitLab is deployed in."
}

output "cluster_location" {
  value       = var.gke_private ? module.gke_private["gke"].location : module.gke_public["gke"].location
  description = "Location of the GKE cluster that GitLab is deployed in."
}

output "cluster_ca_certificate" {
  sensitive   = true
  value       = module.gke_auth.cluster_ca_certificate
  description = "CA Certificate for the GKE cluster that GitLab is deployed in."
}

output "host" {
  value       = module.gke_auth.host
  description = "Host for the GKE cluster that GitLab is deployed in."
}

output "token" {
  sensitive   = true
  value       = module.gke_auth.token
  description = "Token for the GKE cluster that GitLab is deployed in."
}

output "root_password_instructions" {
  value = module.gitlab.root_password_instructions
}
