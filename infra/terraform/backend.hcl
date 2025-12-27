bucket         = "acme-corp-s3-tf"
key            = "dev/terraform.tfstate"
region         = "eu-central-1"
use_lockfile   = true
# dynamodb_table = "acme-corp-terraform-locks" # deprecated; use_lockfile

# Optional (uncomment if needed):
# encrypt      = true
# kms_key_id   = "<KMS_KEY_ARN>"

# SSO profile for backend auth (requires AWS_SDK_LOAD_CONFIG=1)
profile        = "tf"
