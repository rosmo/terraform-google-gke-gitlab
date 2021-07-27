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

output "webservice_backend" {
  value = google_compute_backend_service.gitlab_webservice_backend.name
}

output "workhorse_backend" {
  value = google_compute_backend_service.gitlab_workhorse_backend.name
}

output "registry_backend" {
  value = google_compute_backend_service.gitlab_registry_backend.name
}

output "shell_backend" {
  value = google_compute_backend_service.gitlab_ssh_backend.name
}

output "webservice_backend_internal" {
  value = google_compute_region_backend_service.gitlab_webservice_region_backend.name
}

output "workhorse_backend_internal" {
  value = google_compute_region_backend_service.gitlab_workhorse_region_backend.name
}

output "internal_ip" {
  value = google_compute_address.internal_address.address
}

output "shell_ip" {
  value = google_compute_global_address.ssh_address.address
}
