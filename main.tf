/**
 * Copyright 2022 Google LLC
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

/*************************************************
  Activate APIs.
*************************************************/

module "project_services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "~> 13.0"
  project_id                  = var.project_id

  activate_apis = var.project_apis

#   activate_api_identities = [{
#     api = "healthcare.googleapis.com"
#     roles = [
#       "roles/healthcare.serviceAgent",
#       "roles/bigquery.jobUser",
#     ]
#   }]
}

/*************************************************
  Set gcloud project config
*************************************************/

module "gcloud_project" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.0"

  platform = "linux"

  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "config set project ${var.project_id}"
}

/*************************************************
  Enable PGA on data subnet

  This is a hacky workaround for the lab because
  the subnet is an existing resource that we don't
  really want to import into state.
*************************************************/

module "gcloud_pga" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.0"

  platform = "linux"

  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "compute networks subnets update ${data.google_compute_subnetwork.data_subnet.name} --region=${var.region} --enable-private-ip-google-access"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "compute networks subnets update ${data.google_compute_subnetwork.data_subnet.name} --region=${var.region} --no-enable-private-ip-google-access"
}

/*************************************************
  Create Managed AD Domain.
*************************************************/

resource "google_active_directory_domain" "ad_domain" {
  project             = var.project_id

  domain_name         = var.domain_name
  locations           = [var.region]
  reserved_ip_range   = "192.168.99.0/24"
  authorized_networks = [
    data.google_compute_network.compute_network.id,
    data.google_compute_network.data_network.id
  ]

  depends_on = [
    module.project_services
  ]
}

/*************************************************
  Set firewall policy.
*************************************************/

resource "google_compute_firewall" "compute_egress" {
  name      = "allow-all-egress-compute"
  network   = data.google_compute_network.compute_network.name
  project   = var.project_id
  direction = "EGRESS"
  priority  = 64998

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "compute_ingress" {
  name      = "allow-all-ingress-compute"
  network   = data.google_compute_network.compute_network.name
  project   = var.project_id
  direction = "INGRESS"
  priority  = 64998

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "data_egress" {
  name      = "allow-all-egress-data"
  network   = data.google_compute_network.data_network.name
  project   = var.project_id
  direction = "EGRESS"
  priority  = 64998

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "data_ingress" {
  name      = "allow-all-ingress-data"
  network   = data.google_compute_network.data_network.name
  project   = var.project_id
  direction = "INGRESS"
  priority  = 64998

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

/*************************************************
  Create VPC peerings.
*************************************************/

module "main_peering" {
  source                     = "terraform-google-modules/network/google//modules/network-peering"
  version                    = "~> 5.0"

  prefix                     = "np"
  local_network              = data.google_compute_network.compute_network.self_link
  peer_network               = data.google_compute_network.data_network.self_link
  export_local_custom_routes = true
  export_peer_custom_routes  = true
}

resource "google_compute_network_peering" "fusion_peer" {
  name                 = "fusion-peer"
  network              = data.google_compute_network.data_network.self_link
  peer_network         = "projects/${google_data_fusion_instance.data_fusion_instance.tenant_project_id}/global/networks/${google_data_fusion_instance.data_fusion_instance.region}-${google_data_fusion_instance.data_fusion_instance.name}"
  export_custom_routes = true
  import_custom_routes = true
}

/*************************************************
  Deploy SQL Server instance.
*************************************************/

module "instance_template" {
  source               = "terraform-google-modules/vm/google//modules/instance_template"
  version              = "~> 7.3"
  machine_type         = var.machine_type
  region               = var.region
  project_id           = var.project_id
  subnetwork           = data.google_compute_subnetwork.compute_subnet.self_link
  service_account      = {
    email  = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    scopes = ["compute-rw"]
  }

  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project

  disk_type            = var.disk_type
  disk_size_gb         = var.disk_size_gb

  access_config = [{
    nat_ip       = null
    network_tier = "PREMIUM"
  }]
}

module "compute_instance" {
  source              = "terraform-google-modules/vm/google//modules/compute_instance"
  version             = "~> 7.3"
  region              = var.region
  zone                = var.zone
  num_instances       = "1"
  hostname            = var.sql_hostname
  add_hostname_suffix = false
  instance_template   = module.instance_template.self_link
  deletion_protection = false
}

/*************************************************
  Create service account and permissions.
*************************************************/

resource "google_service_account" "hana_service_account" {
  project      = var.project_id
  account_id   = var.hana_sa_name
  display_name = var.hana_sa_name
}

resource "google_project_iam_member" "sa_owner_role" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.hana_service_account.email}"
}

/*************************************************
  Generate service account key.

  This is a hacky workaround for the lab because
  Terraform is picky about how to decode a
  base64 object, which is how the p12 bundle is
  presented in the output.
*************************************************/

module "gcloud_key" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.0"

  platform = "linux"

  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "iam service-accounts keys create ./keys/sa.p12 --iam-account=${google_service_account.hana_service_account.email} --key-file-type=p12"
}

/*************************************************
  Deploy Data Fusion.
*************************************************/

resource "google_data_fusion_instance" "data_fusion_instance" {
  project                       = var.project_id

  name                          = var.fusion_instance_name
  description                   = "Created and managed by Terraform"
  region                        = var.region
  type                          = var.fusion_instance_type
  version                       = var.fusion_instance_version
  enable_stackdriver_logging    = var.enable_stackdriver
  enable_stackdriver_monitoring = var.enable_stackdriver
  private_instance              = true

  network_config {
    network       = data.google_compute_network.data_network.name
    ip_allocation = "192.168.199.0/22"
  }

  depends_on = [
    module.project_services
  ]
}
