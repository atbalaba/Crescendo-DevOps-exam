resource "aws_instance" "ec2_instance" {
  ami = "ami-06c4be2792f419b7b" #Ubuntu Server 22.04 LTS
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.ec2_sec_group.name]
  tags = {
    Name = "test_instance"
  }
  user_data = <<-EOF
  #!/bin/bash

  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install -y nginx
  systemctl start nginx 
  systemctl enable nginx

  sudo apt-get install -y openjdk-8-jdk
  sudo apt-get install -y wget
  cd /tmp
  sudo wget https://downloads.apache.org/tomcat/tomcat-10/v10.1.20/bin/apache-tomcat-10.1.20-src.tar.gz
  sudo tar xzf apache-tomcat-10.1.20.tar.gz -C /opt
  sudo ln -s /opt/apache-tomcat-10.1.20 /opt/tomcat
  
  sudo groupadd tomcat
  sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
  sudo chown -R tomcat:tomcat /opt/tomcat
  sudo chmod -R 755 /opt/tomcat/bin

  cat <<EOT > /etc/systemd/system/tomcat.service
  [Unit]
    Description=Tomcat 10 servlet container
    After=network.target
  [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment="JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk"
    Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom"
    Environment="CATALINA_BASE=/opt/tomcat"
    Environment="CATALINA_HOME=/opt/tomcat"
    Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
    ExecStart=/opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh
  [Install]
    WantedBy=multi-user.target
  EOT
    
  sudo systemctl daemon-reload
  sudo systemctl enable tomcat
  sudo systemctl start tomcat
  EOF
}