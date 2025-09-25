packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Start from Ubuntu base image
source "amazon-ebs" "ubuntu" {
  region               = "ap-south-1"
  instance_type        = "t3.micro"
  iam_instance_profile = "packer-s3-read-profile"

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
      "sudo apt-get update -y",
      "sudo apt-get install -y unzip curl openjdk-17-jdk-headless",

      # Install AWS CLI v2
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      # Create app directory
      "sudo mkdir -p /opt/petclinic",

      # Pull latest JAR from S3
      "aws s3 cp s3://springpetclinicjar1/petclinic-latest.jar /tmp/petclinic.jar",
      "sudo mv /tmp/petclinic.jar /opt/petclinic/petclinic.jar",

      # Systemd service
      "echo '[Unit]\nDescription=Spring PetClinic\n[Service]\nExecStart=/usr/bin/java -jar /opt/petclinic/petclinic.jar --spring.profiles.active=mysql\nRestart=always\nUser=ubuntu\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/petclinic.service",

      "sudo systemctl enable petclinic"
    ]
  }
}
