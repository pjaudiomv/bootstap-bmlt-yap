resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.bmlt.id
  allocation_id = aws_eip.bmlt.id
}

resource "aws_eip" "bmlt" {
  vpc = true
}

resource "aws_instance" "bmlt" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = module.vpc.public_subnets[0]
  instance_type               = "t3.nano"
  vpc_security_group_ids      = [aws_security_group.bmlt.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bmlt.name
  user_data                   = data.template_cloudinit_config.bmlt.rendered

  tags = {
    Name = "bmlt"
  }
}

resource "aws_iam_role" "bmlt" {
  name               = "bmlt-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bmlt.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bmlt" {
  name = "bmlt-${terraform.workspace}"
  role = aws_iam_role.bmlt.name
}

resource "aws_security_group" "bmlt" {
  vpc_id = module.vpc.vpc_id
  name   = "bmlt-${terraform.workspace}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "template_cloudinit_config" "bmlt" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
#cloud-config

package_update: true
package_upgrade: true
packages:
  - software-properties-common
  - mysql-server
  - mysql-client
  - php
  - apache2
  - libapache2-mod-php
  - php-mysql
  - php7.2-xml
  - php-curl
  - php-gd
  - php-zip
  - php-mbstring
  - python3-pip
  - unzip
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<BOF
#!/bin/bash

snap install core
snap refresh core
snap install --classic certbot


ufw enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp

# do the cert things
#certbot \
#  run \
#  --apache \
#  -d bmlt.nerna.org \
#  -m 'pjaudiomv@gmail.com' \
#  --agree-tos \
#  --non-interactive \
#  --server https://acme-v02.api.letsencrypt.org/directory


# Do the yap and BMLT Things
wget https://github.com/bmlt-enabled/bmlt-root-server/releases/download/2.14.2/bmlt-root-server.zip
wget https://github.com/bmlt-enabled/yap/releases/download/3.9.9/yap-3.9.9.zip
unzip bmlt-root-server.zip
unzip yap-3.9.9.zip
rm -f bmlt-root-server.zip
rm -f yap-3.9.9.zip
mv main_server /var/www/html/main_server
mv  yap-3.9.9 /var/www/html/yap
#rm -f /var/www/html/index.html
chown -R www-data: /var/www/html

# start service and makes sure they stay that way on re-boot
service apache2 start
service mysql start
sudo systemctl is-enabled apache2.service
sudo systemctl is-enabled mysql.service

# configure rewrite
sed -i '/^\s*DocumentRoot \/var\/www\/html.*/a <Directory "\/var\/www\/html">\nAllowOverride All\n<\/Directory>' /etc/apache2/sites-available/000-default.conf
a2enmod rewrite expires
service apache2 restart
BOF
  }
}
