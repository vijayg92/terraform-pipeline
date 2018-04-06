#########################################################################################################
#### VARIABLES                                                                                       ####
#########################################################################################################
variable "aws_access_key" {}
variable "aws_secret_ket" {}
variable "private_key_path" {}
variable "key_name" {
	default = "DevOpsUser"
}
variable "vpc_network_cidr" {
	default = "10.1.0.0/16"
}
variable "bucket_name" {}
variable "instance_count" {
	default = 2
} 
