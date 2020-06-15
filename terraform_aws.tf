//CREATING THE MAIN PROVIDER




provider "aws" {
    region         = "ap-south-1"
    profile        = "default"
}

//Creating Key
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}






//Generating Key-Value Pair
resource "aws_key_pair" "generated_key" {

    depends_on = [
        tls_private_key.tls_key,
    ]
  key_name   = "saini-key-1"
  public_key = "${tls_private_key.tls_key.public_key_openssh}"

}






//Saving Private Key PEM File
resource "local_file" "key-file" {

    depends_on = [
        tls_private_key.tls_key,
    ]

  content  = "${tls_private_key.tls_key.private_key_pem}"
  filename = "saini-key-1.pem"
}







//CREATING THE SECURITY GROUP

resource "aws_security_group" "saini-sg" {
    name               = "mysec"
    ingress{
        from_port      = 22
        to_port        = 22
        protocol       = "tcp"
        cidr_blocks    = [ "0.0.0.0/0" ]
    }
    
    ingress{
        from_port      = 80
        to_port        = 80
        protocol       = "tcp"
        cidr_blocks    = [ "0.0.0.0/0" ]
    }
    egress{
        from_port      = 0
        to_port        = 0
        protocol       = "-1"
        cidr_blocks    = [ "0.0.0.0/0" ]
    }
}







//CREATING THE INSTANCE

resource "aws_instance" "saininewos"{
    ami                 = "ami-0447a12f28fddb066"
    instance_type       = "t2.micro"
    key_name            = "${aws_key_pair.generated_key.key_name}"
    availability_zone   = "ap-south-1a"
    security_groups     = ["${aws_security_group.saini-sg.name}","default"]

    
    connection{
        type            = "ssh"
        user            = "ec2-user"
        private_key     = "${tls_private_key.tls_key.private_key_pem}"
        host            = aws_instance.saininewos.public_ip
    }
    
    provisioner "remote-exec"{
        inline = [
            "sudo yum install docker git -y",
            "sudo systemctl start docker",
            "sudo systemctl enable docker",
            "sudo mkdir /webpage",
            "sudo docker run -dit --name sainiweb -v /webpage/:/var/www/html/ -p 80:80  saini420boy/webphpserver:a1",
        ]
    }

    tags = {
        Name = "saininewos"  
    }
  
}






//CREATING THE EBS VOLUME

resource "aws_ebs_volume" "ebs_vol_1" {
    availability_zone    = aws_instance.saininewos.availability_zone
    size                = 5
    tags = {
        Name             = "ebs_vol_1"
    }
}




//ATTACHING THE EBS VOLUME

resource "aws_volume_attachment" "ebs_vol_attach" {
    device_name            = "/dev/sdf"
    volume_id              = aws_ebs_volume.ebs_vol_1.id
    instance_id            = aws_instance.saininewos.id
    force_detach           = true
}
    
resource "null_resource" "nullremote1"{
    depends_on = [
        aws_volume_attachment.ebs_vol_attach,
    ]
    
    connection{
        private_key        = "${tls_private_key.tls_key.private_key_pem}"
        
        type               = "ssh"
        user               = "ec2-user"
        host               = aws_instance.saininewos.public_ip
    }
    
    provisioner "remote-exec"{
        inline = [
            "sudo mkfs.ext4 /dev/xvdf",
            "sudo mount /dev/xvdf /webpage",
            "sudo rm -rf /webpage/*",
            "sudo git clone https://github.com/saini420boy/devopsal3.git  /webpage/"
        ]
    }
}



//CREATING THE BUCKET

resource "aws_s3_bucket" "saini-bucket-1" {
    bucket                = "saini-bucket-1"
    acl                   = "private"
    region                = "ap-south-1"
    tags = {
        Name              = "s3_bucket"
    }
}
locals {
    s3_origin_id          = "s3_origin"
}



//UPLOADING THE FILE TO THE BUCKET

resource "aws_s3_bucket_object" "object" {
    
    depends_on = [
        aws_s3_bucket.saini-bucket-1,
    ]
    bucket                = "saini-bucket-1"
    key                   = "pubg.png"
    source                = "pubg.png"
    acl                   = "public-read"
}



//CREATING THE CLOUDFRONT DISTRIBUTION

resource "aws_cloudfront_distribution" "cloudfront_dist" {
    origin{
        domain_name       = aws_s3_bucket.saini-bucket-1.bucket_regional_domain_name
        origin_id         = local.s3_origin_id
    }
    
    enabled               = true
    is_ipv6_enabled       = true

    default_cache_behavior {
        allowed_methods   = ["DELETE","PATCH","OPTIONS","POST","PUT","GET", "HEAD"]
        cached_methods    = ["GET", "HEAD"]
        target_origin_id  = local.s3_origin_id

        forwarded_values {
            query_string  = false

            cookies {
                forward   = "none"
            }
        }

        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
        compress               = true
        viewer_protocol_policy = "allow-all"
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}






