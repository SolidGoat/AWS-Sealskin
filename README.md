# AWS-Sealskin

## How to Deploy

### Bootstrap environment

1. Create your `global.tfvars` file

   ```
   workload_name = "sealskin"
   region = "us-east-1"
   ```

2. Create the initial S3 Bucket to store the Terraform State file

   ```bash
   $ cd bootstrap
   $ terraform init
   $ terraform apply -var-file="../global.tfvars"
   ```

   1. After `terraform apply`, two files will be created with the backend config information:

      `bootstrap/bootstrap.backend.config`

      `${var.workload_name}/terraform.tfstate`

3. Migrate the state to the Terraform State S3 Bucket
   ```bash
   $ terraform init -backend-config="bootstrap.backend.config" -migrate-state
   ```
