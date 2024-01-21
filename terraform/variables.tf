variable "public_cidr" {
    type = string
    default = "192.168.0.0/16"
}

variable "azs" {
    type = list(string)
    default = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

variable "public_subnet" {
    type = list(string)
    default = ["192.168.0.0/24","192.168.1.0/24","192.168.2.0/24"]
}

variable "private_eks_subnet" {
    type = list(string)
    default = ["192.168.10.0/24","192.168.11.0/24","192.168.12.0/24"]
}

variable "private_db_subnet" {
    type = list(string)
    default = ["192.168.20.0/24","192.168.21.0/24","192.168.22.0/24"]
}
