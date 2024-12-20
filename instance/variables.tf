variable "name" {
  type        = string
  default     = "factorio"
  description = "Prefix to use for resource names."
}

variable "region" {
  type        = string
  default     = "us-west-1"
  description = "AWS region to create resources in."
}

variable "tags" {
  type = map(string)
  default = {
    "Project" : "factorio"
  }
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "AWS instance type to use for the Factorio server."
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket to use for save game backups."
}

variable "instance_profile" {
  type        = string
  default     = "factorio-instance-profile"
  description = "Instance profile to assign to AWS instance. This should be configured to allow access to the S3 backup bucket."
}

variable "factorio_version" {
  type        = string
  default     = "stable"
  description = "Version of Factorio to install on the server."
}

variable "factorio_save_game" {
  type        = string
  default     = ""
  description = "Name of the Factorio save game to load. Leave empty to load latest save game."
}

variable "server_password" {
  type        = string
  default     = "<TBD>"
  description = "Password for the server"
}
