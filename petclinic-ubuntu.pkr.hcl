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

source "amazon-ebs" "ubuntu" {
  region               = "ap-south-1"
  instance_type        = "t3.micro"
  iam_instance_profile = var.iam_instance_profile

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

      # Inject DB config as env vars
      "echo 'SPRING_DATASOURCE_URL=jdbc:mysql://springpet-db.cbgoqoeyey8l.ap-south-1.rds.amazonaws.com:3306/petclinic' | sudo tee -a /etc/environment",
      "echo 'SPRING_DATASOURCE_USERNAME=admin' | sudo tee -a /etc/environment",
      "echo 'SPRING_DATASOURCE_PASSWORD=admin123' | sudo tee -a /etc/environment",
      "echo 'SPRING_JPA_HIBERNATE_DDL_AUTO=update' | sudo tee -a /etc/environment",
      "echo 'SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MySQL8Dialect' | sudo tee -a /etc/environment",

      # Create systemd service using heredoc
      "sudo bash -c 'cat > /etc/systemd/system/petclinic.service <<EOF\n[Unit]\nDescription=Spring PetClinic\nAfter=network.target\n\n[Service]\nEnvironmentFile=-/etc/environment\nExecStart=/usr/bin/java -jar /opt/petclinic/petclinic.jar --spring.profiles.active=mysql --server.address=0.0.0.0\nRestart=always\nUser=ubuntu\n\n[Install]\nWantedBy=multi-user.target\nEOF'",

      # Enable and start service
      "sudo systemctl daemon-reload",
      "sudo systemctl enable petclinic",
      "sudo systemctl start petclinic"
    ]
  }
}
