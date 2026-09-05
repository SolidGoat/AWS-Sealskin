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

### Create Sealskin Keys

1. Navigate to the .secrets folder (this folder is not tracked by Git)
   ```bash
   $ cd .secrets
   ```
2. Generate the RSA private key using 2048 bits (using `openssl`)
   ```bash
   $ openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048
   ```
3. Generate the public key from the private key (using `openssl`)

   ```bash
   openssl rsa -in private_key.pem -pubout -out public_key.pem
   ```

   Terraform will securely (will not be stored in TF state) copy these keys from `.secrets` to AWS Secrets Manager
