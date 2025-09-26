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

    # Inject DB config as environment variables (best practice)
    \"echo 'SPRING_DATASOURCE_URL=jdbc:mysql://springpet-db.cbgoqoeyey8l.ap-south-1.rds.amazonaws.com:3306/petclinic' | sudo tee -a /etc/environment\",
    \"echo 'SPRING_DATASOURCE_USERNAME=admin' | sudo tee -a /etc/environment\",
    \"echo 'SPRING_DATASOURCE_PASSWORD=admin123' | sudo tee -a /etc/environment\",
    \"echo 'SPRING_JPA_HIBERNATE_DDL_AUTO=update' | sudo tee -a /etc/environment\",
    \"echo 'SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.MySQL8Dialect' | sudo tee -a /etc/environment\",

    # Systemd service (uses env vars + binds to all interfaces)
    \"echo '[Unit]\nDescription=Spring PetClinic\nAfter=network.target\n\n[Service]\nEnvironmentFile=-/etc/environment\nExecStart=/usr/bin/java -jar /opt/petclinic/petclinic.jar --spring.profiles.active=mysql --server.address=0.0.0.0\nRestart=always\nUser=ubuntu\n\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/petclinic.service\",

    "sudo systemctl daemon-reload",
    "sudo systemctl enable petclinic",
    "sudo systemctl start petclinic"
  ]
}


 