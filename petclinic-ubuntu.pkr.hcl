packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "bucket_name" {
  type = string
}

variable "object_key" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

# Start from Ubuntu base image
source "amazon-ebs" "ubuntu" {
  region               = "ap-south-1"
  instance_type        = "t3.micro"
  iam_instance_profile = var.iam_instance_profile   # ✅ use variable here

  source_ami_filter {
    filters = {
      name                 = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      virtualization-type  = "hvm"
      root-device-type     = "ebs"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  ssh_username = "ubuntu"
  ami_name     = "springpetclinic-ubuntu-{{timestamp}}"
}

# Provision the instance
build {
  name    = "springpetclinic"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
  inline = [
    "sudo add-apt-repository universe -y",
    "sudo add-apt-repository multiverse -y",
    "sudo apt-get update -y",
    "sudo apt-get install -y unzip curl openjdk-17-jdk-headless",

    # Install AWS CLI
    "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
    "unzip awscliv2.zip",
    "sudo ./aws/install",

    # Setup app
    "sudo mkdir -p /opt/petclinic",
    "aws s3 cp s3://springpetclinicjar1/petclinic-latest.jar /tmp/petclinic.jar",
    "sudo mv /tmp/petclinic.jar /opt/petclinic/petclinic.jar",
    "sudo chown ubuntu:ubuntu /opt/petclinic/petclinic.jar",

    # Systemd service
    "echo '[Unit]\nDescription=Spring PetClinic\n[Service]\nExecStart=/usr/bin/java -jar /opt/petclinic/petclinic.jar --spring.profiles.active=h2\nRestart=always\nUser=ubuntu\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/petclinic.service",
    "sudo systemctl enable petclinic"
  ]
}

}
