data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../networking/terraform.tfstate"
  }
}