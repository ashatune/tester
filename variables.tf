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

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_apis" {
  description = "Service APIs to activate in project_id"
  type        = list(string)
  default     = [
    "managedidentities.googleapis.com",
    "compute.googleapis.com",
    "vmmigration.googleapis.com",
    "dns.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "bigquery.googleapis.com",
    "datafusion.googleapis.com"
  ]
}

variable "region" {
  description = "GCP region location for resources to be deployed"
  type        = string
  default     = "us-central"
}

variable "zone" {
  description = "GCP zone location for resources to be deployed"
  type        = string
  default     = "us-central1-a"
}

variable "domain_name" {
  description = "Fully qualified name of AD domain to create"
  type        = string
}

variable "network_name_compute" {
  description = "Name of the VPC that compute resources are attached to"
  type        = string
}

variable "network_name_data" {
  description = "Name of the VPC that data resources are attached to"
  type        = string
}


variable "subnet_name_compute" {
  description = "Name of subnet that compute resources are attached to"
  type        = string
}

variable "subnet_name_data" {
  description = "Name of subnet that data resources are attached to"
  type        = string
}

variable "hana_sa_name" {
  description = "Name of service account that HANA will use to connect to BQ"
  type        = string
  default     = "saphana-service-accnt"
}

variable "machine_type" {
  description = "Machine type to create, e.g. n1-standard-1"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_type" {
  description = "Type of persistent disk to deploy as boot disk"
  type        = string
  default     = "pd-ssd"
}

variable "disk_size_gb" {
  description = "Size of the boot disk to deploy with the instance"
  type        = string
}

variable "source_image_family" {
  description = "Name of image family to use for SQL Server instance template"
  type        = string
  default     = "sql-std-2019-win-2019"
}

variable "source_image_project" {
  description = "Project ID containing image family to use for SQL Server instance template"
  type        = string
  default     = "windows-sql-cloud"
}

variable "sql_hostname" {
  description = "Name of SQL Server VM to deploy"
  type        = string
  default     = "cymsql2019"
}

variable "fusion_instance_name" {
  description = "Name of Data Fusion instance to deploy"
  type        = string
  default     = "cepf-l300-fuze"
}

variable "fusion_instance_type" {
  description = "Instance type to create, e.g. BASIC"
  type        = string
  default     = "ENTERPRISE"
}

variable "fusion_instance_version" {
  description = "Instance version to use when creating"
  type        = string
  default     = "6.3.1"
}

variable "enable_stackdriver" {
  description = "Flag to control whether Stackdriver is enabled for Fusion instance"
  type        = bool
  default     = true
}
