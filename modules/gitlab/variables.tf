/**
 * Copyright 2018-2021 Google LLC
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

variable "project_id" {
  description = "GCP Project to deploy resources"
}

variable "network" {
  type        = string
  description = "Network"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork"
}

variable "domain" {
  description = "Domain for hosting gitlab functionality (ie mydomain.com would access gitlab at `gitlab.mydomain.com` and the registry at `registry.mydomain.com`)"
  default     = ""
}

variable "gitlab_db_name" {
  description = "Instance name for the GitLab Postgres database."
  default     = "gitlab-db"
}

variable "gitlab_db_random_prefix" {
  description = "Sets random suffix at the end of the Cloud SQL instance name."
  default     = false
}

variable "gitlab_db_password" {
  description = "Password for the GitLab Postgres user"
  default     = ""
}

variable "gitlab_address_name" {
  description = "Name of the address to use for GitLab ingress"
  default     = ""
}

variable "gitlab_runner_install" {
  description = "Choose whether to install the gitlab runner in the cluster"
  default     = true
}

variable "region" {
  default     = "us-central1"
  description = "GCP region to deploy resources to"
}

variable "gitlab_nodes_subnet_cidr" {
  default     = "10.0.0.0/16"
  description = "Cidr range to use for gitlab GKE nodes subnet"
}

variable "gitlab_pods_subnet_cidr" {
  default     = "10.3.0.0/16"
  description = "Cidr range to use for gitlab GKE pods subnet"
}

variable "gitlab_services_subnet_cidr" {
  default     = "10.2.0.0/16"
  description = "Cidr range to use for gitlab GKE services subnet"
}

variable "gitlab_master_subnet_cidr" {
  default     = "10.4.0.0/28"
  description = "Cidr range to use for gitlab GKE master subnet (only when private nodes are enabled)"
}

variable "gitlab_proxy_only_subnet_cidr" {
  default     = "10.5.0.0/26"
  description = "Cidr range to use for L7 ILB proxy-only range (when using GCLB)"
}

variable "use_gclb" {
  type        = bool
  default     = false
  description = "Deploy Gitlab using GCLB, Managed Certificates and Autoneg"
}

variable "gclb_logging" {
  type        = bool
  default     = false
  description = "Enable GCLB logging"
}

variable "gcs_uniform_access" {
  type        = bool
  default     = true
  description = "Use Uniform Bucket Level Access"
}

variable "helm_chart_version" {
  type        = string
  default     = "5.1.0"
  description = "Helm chart version to install during deployment ([GitLab version mapping](https://docs.gitlab.com/charts/installation/version_mappings.html))"
}

variable "allow_force_destroy" {
  type        = bool
  default     = false
  description = "Allows full cleanup of resources by disabling any deletion safe guards"
}

variable "gitlab_values_template" {
  type        = string
  description = "Gitlab Helm chart configuration values"
}
