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

variable "project_id" {
  type        = string
  description = "Project ID"
}

variable "region" {
  type        = string
  description = "Region for L7 ILB backends"
}

variable "network" {
  type        = string
  description = "Network"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork"
}

variable "gitlab_proxy_only_subnet_cidr" {
  description = "Cidr range to use for L7 ILB proxy-only range (when using GCLB)"
}

variable "gclb_logging" {
  type        = bool
  description = "Enable GCLB logging"
}

variable "gitlab_address" {
  type        = string
  description = "Gitlab IP address"
}

variable "domain" {
  type        = string
  description = "Gitlab domain"
}
