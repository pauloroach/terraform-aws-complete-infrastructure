#Create Cluster
resource "aws_ecs_cluster" "aws-ecs-cluster" {
  name = "${var.app_environment}"
  tags = {
    Name        = "${var.app_environment}"
  }
}