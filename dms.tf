# Create a new replication subnet group
resource "aws_dms_replication_subnet_group" "dms-replication-sg" {
  replication_subnet_group_description = "Dms replication subnet group"
  replication_subnet_group_id          = "dms-replication-sg"

  subnet_ids = [
    "subnet-09d82749e7443ac1e",
    "subnet-0d185aaab731cda56",
  ]

  tags = {
    Name = "dms-replication-sg"
  }
}

// Create security group for DMS replication instance
resource "aws_security_group" "dms-replication-instance-sg" {
  name        = "dms-replication-instance-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-08ec1c1310fec87af"

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "dms-replication-instance-sg"
  }
}


# Create a new replication instance
resource "aws_dms_replication_instance" "dms-poc" {
  allocated_storage            = 20
  apply_immediately            = true
  auto_minor_version_upgrade   = true
  availability_zone            = "us-east-1a"
  engine_version               = "3.4.7"
  kms_key_arn                  = "arn:aws:kms:us-east-1:533387313095:key/8398186d-4016-4c1f-a631-75045d6f6683"
  multi_az                     = false
  preferred_maintenance_window = "sun:10:30-sun:14:30"
  publicly_accessible          = true
  replication_instance_class   = "dms.t3.micro"
  replication_instance_id      = "dms-poc-replication-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms-replication-sg.id

  tags = {
    Name = "dms-poc-replication-instance"
  }

  vpc_security_group_ids = [
    aws_security_group.dms-replication-instance-sg.id,
  ]

}

# Create a source endpoint
resource "aws_dms_endpoint" "mssql-source" {
  endpoint_id                 = "mssql-source"
  endpoint_type               = "source"
  engine_name                 = "sqlserver"
  extra_connection_attributes = "SetUpMsCdcForTables=true;ignoreMsReplicationEnablement=true;"

  server_name   = "54.204.96.11"
  username      = "SA"
  password      = "Root@1234"
  port          = 1433
  database_name = "source"
  ssl_mode      = "none"
  tags = {
    Name = "mssql-source"
  }


}

# Create a target endpoint
resource "aws_dms_endpoint" "mssql-target" {
  endpoint_id                 = "mssql-target"
  endpoint_type               = "target"
  engine_name                 = "sqlserver"
  extra_connection_attributes = "UseBCPFullLoad=true"

  server_name   = "35.171.129.117"
  username      = "SA"
  password      = "Root@1234"
  port          = 1433
  database_name = "target"
  ssl_mode      = "none"
  tags = {
    Name = "mssql-target"
  }
}

# Create a new replication task
resource "aws_dms_replication_task" "dms-poc-task" {
  replication_task_id      = "dms-poc-task"
  replication_instance_arn = aws_dms_replication_instance.dms-poc.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.mssql-source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.mssql-target.endpoint_arn

  migration_type            = "full-load-and-cdc"
  replication_task_settings = file("./taskSettings.json")
  table_mappings            = file("./tableMapping.json")
  tags = {
    Name = "dms-poc-task"
  }

}


# Create a s3 target endpoint
resource "aws_dms_s3_endpoint" "s3-target" {
  endpoint_id   = "s3-target"
  endpoint_type = "target"
  ssl_mode      = "none"
  tags = {
    Name = "s3-target"
  }
  bucket_name   = "dms-target-s3"
  service_access_role_arn = "arn:aws:iam::533387313095:role/ajay-dms-s3-role"

  data_format                                 = "parquet"
  data_page_size                              = 1100000
  date_partition_delimiter                    = "SLASH"
  date_partition_enabled                      = true
  date_partition_sequence                     = "YYYYMMDD"
  timestamp_column_name                       = "timestamp"
  add_column_name                             = true
}

# Create a new replication task
resource "aws_dms_replication_task" "dms-poc-s3-task" {
  replication_task_id      = "dms-poc-s3-task"
  replication_instance_arn = aws_dms_replication_instance.dms-poc.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.mssql-source.endpoint_arn
  target_endpoint_arn = aws_dms_s3_endpoint.s3-target.endpoint_arn
  migration_type            = "full-load-and-cdc"
  replication_task_settings = file("./taskSettings.json")
  table_mappings            = file("./tableMapping.json")
  tags = {
    Name = "dms-poc-s3-task"
  }

  depends_on = [aws_dms_s3_endpoint.s3-target]
}
