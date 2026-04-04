#!/usr/bin/env bash
set -euo pipefail

# Destructive AWS-side cleanup for the AcmeCorp demo environment.
# Use this when Terraform state is gone but the AWS resources still exist and
# the environment must be rebuilt from scratch.
#
# The EKS Kubernetes secrets KMS key is intentionally long-lived and retained.
# This script does not delete or schedule deletion for that key.

PREFIX="${PREFIX:-acmecorp-platform-prod}"
CLUSTER_NAME="${CLUSTER_NAME:-acmecorp-platform}"
REGIONS=(eu-west-1 eu-central-1)
KNOWN_IAM_ROLES=(
  "acmecorp-platform-prod-rds-monitoring"
  "acmecorp-platform-prod-eks-cluster-role"
  "acmecorp-platform-prod-eks-node-role"
  "acmecorp-platform-prod-app-role"
  "acmecorp-platform-prod-observability-role"
  "acmecorp-platform-prod-eso-role"
)
KNOWN_SECRETS=(
  "acmecorp-platform-prod/aurora"
  "acmecorp-platform-prod/mq"
  "acmecorp-platform-prod/redis"
  "acmecorp-platform-prod/grafana"
)
KMS_ALIAS="alias/acmecorp-platform-prod-eks-secrets"
FORCE="${FORCE:-false}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-20}"
POLL_TIMEOUT_SECONDS="${POLL_TIMEOUT_SECONDS:-1800}"

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" >&2
}

warn() {
  printf '[%s] WARN: %s\n' "$(timestamp)" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2
  exit 1
}

run() {
  log "RUN: $*"
  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

aws_json() {
  local region="$1"
  shift
  aws --region "$region" "$@" --output json
}

wait_until() {
  local description="$1"
  local timeout_seconds="$2"
  shift 2

  local start
  start="$(date +%s)"

  while true; do
    if "$@"; then
      log "$description"
      return 0
    fi

    if (( $(date +%s) - start >= timeout_seconds )); then
      die "timed out waiting for: $description"
    fi

    sleep "$POLL_INTERVAL_SECONDS"
  done
}

matches_prefix() {
  local value="$1"
  [[ "$value" == "$PREFIX"* ]]
}

matches_cluster_scope() {
  local value="$1"
  [[ "$value" == *"$PREFIX"* || "$value" == "$CLUSTER_NAME" ]]
}

confirm() {
  if [[ "$FORCE" == "true" ]]; then
    log "FORCE=true set; skipping confirmation prompt."
    return 0
  fi

  printf 'Type DELETE to permanently remove scoped AcmeCorp AWS resources: '
  local answer
  read -r answer
  [[ "$answer" == "DELETE" ]] || die "confirmation failed"
}

print_identity() {
  local identity_json
  identity_json="$(aws sts get-caller-identity --output json)"

  local account arn user_id
  account="$(jq -r '.Account' <<<"$identity_json")"
  arn="$(jq -r '.Arn' <<<"$identity_json")"
  user_id="$(jq -r '.UserId' <<<"$identity_json")"

  log "AWS account: $account"
  log "AWS caller ARN: $arn"
  log "AWS user ID: $user_id"
  log "Target prefix: $PREFIX"
  log "Target cluster name: $CLUSTER_NAME"
  log "Target regions: ${REGIONS[*]}"
}

delete_eks_cluster() {
  local region="$1"
  local cluster="$2"

  log "Processing EKS cluster $cluster in $region"

  mapfile -t nodegroups < <(
    aws_json "$region" eks list-nodegroups --cluster-name "$cluster" \
      | jq -r '.nodegroups[]?'
  )

  for nodegroup in "${nodegroups[@]:-}"; do
    if [[ -z "$nodegroup" ]]; then
      continue
    fi
    run aws --region "$region" eks delete-nodegroup --cluster-name "$cluster" --nodegroup-name "$nodegroup" >/dev/null
    wait_until \
      "Deleted EKS nodegroup $nodegroup in cluster $cluster ($region)" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "test \"\$(aws --region '$region' eks list-nodegroups --cluster-name '$cluster' --output json 2>/dev/null | jq -r '.nodegroups[]?' | grep -Fx '$nodegroup' || true)\" = ''"
  done

  mapfile -t fargate_profiles < <(
    aws_json "$region" eks list-fargate-profiles --cluster-name "$cluster" \
      | jq -r '.fargateProfileNames[]?'
  )

  for profile in "${fargate_profiles[@]:-}"; do
    if [[ -z "$profile" ]]; then
      continue
    fi
    run aws --region "$region" eks delete-fargate-profile --cluster-name "$cluster" --fargate-profile-name "$profile" >/dev/null
    wait_until \
      "Deleted EKS fargate profile $profile in cluster $cluster ($region)" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "test \"\$(aws --region '$region' eks list-fargate-profiles --cluster-name '$cluster' --output json 2>/dev/null | jq -r '.fargateProfileNames[]?' | grep -Fx '$profile' || true)\" = ''"
  done

  run aws --region "$region" eks delete-cluster --name "$cluster" >/dev/null
  wait_until \
    "Deleted EKS cluster $cluster in $region" \
    "$POLL_TIMEOUT_SECONDS" \
    bash -lc "! aws --region '$region' eks describe-cluster --name '$cluster' >/dev/null 2>&1"
}

cleanup_eks() {
  log "Starting EKS cleanup"

  for region in "${REGIONS[@]}"; do
    mapfile -t clusters < <(
      aws_json "$region" eks list-clusters | jq -r '.clusters[]?'
    )

    local found=false
    for cluster in "${clusters[@]:-}"; do
      if [[ -n "$cluster" ]] && matches_cluster_scope "$cluster"; then
        found=true
        delete_eks_cluster "$region" "$cluster"
      fi
    done

    if [[ "$found" == "false" ]]; then
      log "No matching EKS clusters found in $region"
    fi
  done
}

delete_mq_broker() {
  local region="$1"
  local broker_id="$2"
  local broker_name="$3"

  log "Deleting MQ broker $broker_name ($broker_id) in $region"
  run aws --region "$region" mq delete-broker --broker-id "$broker_id" >/dev/null
  wait_until \
    "Deleted MQ broker $broker_name in $region" \
    "$POLL_TIMEOUT_SECONDS" \
    bash -lc "! aws --region '$region' mq describe-broker --broker-id '$broker_id' >/dev/null 2>&1"
}

cleanup_mq() {
  log "Starting Amazon MQ cleanup"

  for region in "${REGIONS[@]}"; do
    local brokers_json
    brokers_json="$(aws_json "$region" mq list-brokers)"

    local found=false
    while IFS=$'\t' read -r broker_id broker_name; do
      [[ -n "${broker_id:-}" && -n "${broker_name:-}" ]] || continue
      if matches_prefix "$broker_name"; then
        found=true
        delete_mq_broker "$region" "$broker_id" "$broker_name"
      fi
    done < <(jq -r '.BrokerSummaries[]? | [.BrokerId, .BrokerName] | @tsv' <<<"$brokers_json")

    if [[ "$found" == "false" ]]; then
      log "No matching MQ brokers found in $region"
    fi
  done
}

delete_rds_instances() {
  local region="$1"

  local instances_json
  instances_json="$(aws_json "$region" rds describe-db-instances)"

  local found=false
  while IFS=$'\t' read -r identifier engine; do
    [[ -n "${identifier:-}" ]] || continue
    if matches_prefix "$identifier"; then
      found=true
      log "Deleting RDS DB instance $identifier in $region"
      run aws --region "$region" rds delete-db-instance \
        --db-instance-identifier "$identifier" \
        --skip-final-snapshot \
        --delete-automated-backups >/dev/null
    fi
  done < <(jq -r '.DBInstances[]? | [.DBInstanceIdentifier, .Engine] | @tsv' <<<"$instances_json")

  if [[ "$found" == "false" ]]; then
    log "No matching RDS DB instances found in $region"
    return
  fi

  while IFS= read -r identifier; do
    [[ -n "${identifier:-}" ]] || continue
    wait_until \
      "Deleted RDS DB instance $identifier in $region" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "! aws --region '$region' rds describe-db-instances --db-instance-identifier '$identifier' >/dev/null 2>&1"
  done < <(jq -r '.DBInstances[]? | .DBInstanceIdentifier' <<<"$instances_json" | grep "$PREFIX" || true)
}

delete_rds_clusters() {
  local region="$1"

  local clusters_json
  clusters_json="$(aws_json "$region" rds describe-db-clusters)"

  local found=false
  while IFS= read -r identifier; do
    [[ -n "${identifier:-}" ]] || continue
    if matches_prefix "$identifier"; then
      found=true
      log "Deleting RDS/Aurora DB cluster $identifier in $region"
      run aws --region "$region" rds delete-db-cluster \
        --db-cluster-identifier "$identifier" \
        --skip-final-snapshot \
        --delete-automated-backups >/dev/null
    fi
  done < <(jq -r '.DBClusters[]? | .DBClusterIdentifier' <<<"$clusters_json")

  if [[ "$found" == "false" ]]; then
    log "No matching RDS/Aurora DB clusters found in $region"
    return
  fi

  while IFS= read -r identifier; do
    [[ -n "${identifier:-}" ]] || continue
    wait_until \
      "Deleted RDS/Aurora DB cluster $identifier in $region" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "! aws --region '$region' rds describe-db-clusters --db-cluster-identifier '$identifier' >/dev/null 2>&1"
  done < <(jq -r '.DBClusters[]? | .DBClusterIdentifier' <<<"$clusters_json" | grep "$PREFIX" || true)
}

cleanup_rds() {
  log "Starting RDS/Aurora cleanup"

  for region in "${REGIONS[@]}"; do
    delete_rds_instances "$region"
    delete_rds_clusters "$region"

    local subnet_groups_json
    subnet_groups_json="$(aws_json "$region" rds describe-db-subnet-groups)"
    local found_subnet_group=false
    while IFS= read -r subnet_group; do
      [[ -n "${subnet_group:-}" ]] || continue
      if matches_prefix "$subnet_group"; then
        found_subnet_group=true
        log "Deleting RDS DB subnet group $subnet_group in $region"
        if ! aws --region "$region" rds delete-db-subnet-group --db-subnet-group-name "$subnet_group" >/dev/null 2>&1; then
          warn "Could not delete RDS DB subnet group $subnet_group in $region; it may still be in use or already gone"
        fi
      fi
    done < <(jq -r '.DBSubnetGroups[]? | .DBSubnetGroupName' <<<"$subnet_groups_json")
    if [[ "$found_subnet_group" == "false" ]]; then
      log "No matching RDS DB subnet groups found in $region"
    fi

    local cluster_parameter_groups_json
    cluster_parameter_groups_json="$(aws_json "$region" rds describe-db-cluster-parameter-groups)"
    local found_cluster_parameter_group=false
    while IFS= read -r parameter_group; do
      [[ -n "${parameter_group:-}" ]] || continue
      if matches_prefix "$parameter_group"; then
        found_cluster_parameter_group=true
        log "Deleting RDS DB cluster parameter group $parameter_group in $region"
        if ! aws --region "$region" rds delete-db-cluster-parameter-group --db-cluster-parameter-group-name "$parameter_group" >/dev/null 2>&1; then
          warn "Could not delete RDS DB cluster parameter group $parameter_group in $region; it may still be in use or already gone"
        fi
      fi
    done < <(jq -r '.DBClusterParameterGroups[]? | .DBClusterParameterGroupName' <<<"$cluster_parameter_groups_json")
    if [[ "$found_cluster_parameter_group" == "false" ]]; then
      log "No matching RDS DB cluster parameter groups found in $region"
    fi

    local parameter_groups_json
    parameter_groups_json="$(aws_json "$region" rds describe-db-parameter-groups)"
    local found_parameter_group=false
    while IFS= read -r parameter_group; do
      [[ -n "${parameter_group:-}" ]] || continue
      if matches_prefix "$parameter_group"; then
        found_parameter_group=true
        log "Deleting RDS DB parameter group $parameter_group in $region"
        if ! aws --region "$region" rds delete-db-parameter-group --db-parameter-group-name "$parameter_group" >/dev/null 2>&1; then
          warn "Could not delete RDS DB parameter group $parameter_group in $region; it may still be in use or already gone"
        fi
      fi
    done < <(jq -r '.DBParameterGroups[]? | .DBParameterGroupName' <<<"$parameter_groups_json")
    if [[ "$found_parameter_group" == "false" ]]; then
      log "No matching RDS DB parameter groups found in $region"
    fi
  done
}

cleanup_kms_alias() {
  log "Inspecting retained KMS key alias state"

  for region in "${REGIONS[@]}"; do
    local aliases_json
    aliases_json="$(aws_json "$region" kms list-aliases)"

    local target_key_id
    target_key_id="$(jq -r --arg alias "$KMS_ALIAS" '.Aliases[]? | select(.AliasName == $alias) | .TargetKeyId // empty' <<<"$aliases_json")"

    if [[ -n "$target_key_id" ]]; then
      local key_state
      key_state="$(aws --region "$region" kms describe-key --key-id "$target_key_id" --output json 2>/dev/null | jq -r '.KeyMetadata.KeyState // empty' || true)"
      if [[ -z "$key_state" ]]; then
        warn "Retained KMS key $target_key_id in $region could not be described"
      else
        log "Retaining KMS alias $KMS_ALIAS and key $target_key_id in $region with state $key_state"
      fi
    else
      log "Retained KMS alias $KMS_ALIAS not found in $region"
    fi

    local matching_aliases
    matching_aliases="$(jq -r --arg prefix "alias/$PREFIX" '.Aliases[]? | select(.AliasName | contains($prefix)) | "\(.AliasName)\t\(.TargetKeyId // "no-target-key")"' <<<"$aliases_json" || true)"
    if [[ -n "$matching_aliases" ]]; then
      warn "Matching KMS aliases in $region were left intact and may need manual review:"
      while IFS= read -r line; do
        [[ -n "${line:-}" ]] && warn "  $line"
      done <<<"$matching_aliases"
    fi
  done
}

delete_iam_policy_if_present() {
  local policy_arn="$1"

  local policy_versions_json
  policy_versions_json="$(aws iam list-policy-versions --policy-arn "$policy_arn" --output json 2>/dev/null || true)"
  if [[ -z "$policy_versions_json" ]]; then
    return
  fi

  while IFS= read -r version_id; do
    [[ -n "${version_id:-}" ]] || continue
    run aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version_id"
  done < <(jq -r '.Versions[]? | select(.IsDefaultVersion == false) | .VersionId' <<<"$policy_versions_json")

  run aws iam delete-policy --policy-arn "$policy_arn"
}

cleanup_iam_roles() {
  log "Starting IAM role cleanup"

  for role_name in "${KNOWN_IAM_ROLES[@]}"; do
    if ! aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
      log "IAM role $role_name does not exist"
      continue
    fi

    log "Deleting IAM role $role_name"

    mapfile -t attached_policies < <(
      aws iam list-attached-role-policies --role-name "$role_name" --output json \
        | jq -r '.AttachedPolicies[]? | .PolicyArn'
    )
    for policy_arn in "${attached_policies[@]:-}"; do
      [[ -n "${policy_arn:-}" ]] || continue
      run aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
    done

    mapfile -t inline_policies < <(
      aws iam list-role-policies --role-name "$role_name" --output json \
        | jq -r '.PolicyNames[]?'
    )
    for policy_name in "${inline_policies[@]:-}"; do
      [[ -n "${policy_name:-}" ]] || continue
      run aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy_name"
    done

    mapfile -t instance_profiles < <(
      aws iam list-instance-profiles-for-role --role-name "$role_name" --output json \
        | jq -r '.InstanceProfiles[]? | .InstanceProfileName'
    )
    for profile_name in "${instance_profiles[@]:-}"; do
      [[ -n "${profile_name:-}" ]] || continue
      run aws iam remove-role-from-instance-profile --instance-profile-name "$profile_name" --role-name "$role_name"
      if matches_prefix "$profile_name"; then
        run aws iam delete-instance-profile --instance-profile-name "$profile_name"
      else
        warn "Instance profile $profile_name does not match prefix and was not deleted"
      fi
    done

    run aws iam delete-role --role-name "$role_name"
  done

  log "Deleting matching IAM instance profiles"
  mapfile -t remaining_instance_profiles < <(
    aws iam list-instance-profiles --output json | jq -r '.InstanceProfiles[]? | .InstanceProfileName'
  )
  for profile_name in "${remaining_instance_profiles[@]:-}"; do
    [[ -n "${profile_name:-}" ]] || continue
    if matches_prefix "$profile_name"; then
      log "Deleting IAM instance profile $profile_name"
      if ! aws iam delete-instance-profile --instance-profile-name "$profile_name" >/dev/null 2>&1; then
        warn "Could not delete IAM instance profile $profile_name; it may still reference a role or already be gone"
      fi
    fi
  done

  log "Deleting matching customer-managed IAM policies"
  mapfile -t local_policy_arns < <(
    aws iam list-policies --scope Local --output json | jq -r '.Policies[]? | select(.PolicyName | startswith("'"$PREFIX"'")) | .Arn'
  )
  for policy_arn in "${local_policy_arns[@]:-}"; do
    [[ -n "${policy_arn:-}" ]] || continue
    log "Deleting IAM policy $policy_arn"
    delete_iam_policy_if_present "$policy_arn"
  done
}

cleanup_secrets() {
  log "Starting Secrets Manager cleanup"

  for region in "${REGIONS[@]}"; do
    for secret_name in "${KNOWN_SECRETS[@]}"; do
      if ! aws --region "$region" secretsmanager describe-secret --secret-id "$secret_name" >/dev/null 2>&1; then
        log "Secret $secret_name does not exist in $region"
        continue
      fi

      log "Deleting secret $secret_name in $region"
      run aws --region "$region" secretsmanager delete-secret \
        --secret-id "$secret_name" \
        --force-delete-without-recovery >/dev/null
    done
  done
}

cleanup_ecr() {
  log "Starting ECR cleanup"

  for region in "${REGIONS[@]}"; do
    local repos_json
    repos_json="$(aws_json "$region" ecr describe-repositories)"

    local found=false
    while IFS= read -r repository_name; do
      [[ -n "${repository_name:-}" ]] || continue
      if matches_prefix "$repository_name"; then
        found=true
        log "Deleting ECR repository $repository_name in $region"
        run aws --region "$region" ecr delete-repository --repository-name "$repository_name" --force >/dev/null
      fi
    done < <(jq -r '.repositories[]? | .repositoryName' <<<"$repos_json")

    if [[ "$found" == "false" ]]; then
      log "No matching ECR repositories found in $region"
    fi
  done
}

delete_elbv2_in_vpc() {
  local region="$1"
  local vpc_id="$2"

  local lbs_json
  lbs_json="$(aws_json "$region" elbv2 describe-load-balancers)"

  local found=false
  while IFS=$'\t' read -r lb_arn lb_name; do
    [[ -n "${lb_arn:-}" ]] || continue
    found=true
    log "Deleting ELBv2 load balancer $lb_name in $region"
    run aws --region "$region" elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"
    wait_until \
      "Deleted ELBv2 load balancer $lb_name in $region" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "! aws --region '$region' elbv2 describe-load-balancers --load-balancer-arns '$lb_arn' >/dev/null 2>&1"
  done < <(jq -r --arg vpc "$vpc_id" '.LoadBalancers[]? | select(.VpcId == $vpc) | [.LoadBalancerArn, .LoadBalancerName] | @tsv' <<<"$lbs_json")

  if [[ "$found" == "false" ]]; then
    log "No ELBv2 load balancers found in VPC $vpc_id ($region)"
  fi
}

delete_vpc_endpoints() {
  local region="$1"
  local vpc_id="$2"

  local endpoints_json
  endpoints_json="$(aws_json "$region" ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc_id")"

  local found=false
  while IFS= read -r endpoint_id; do
    [[ -n "${endpoint_id:-}" ]] || continue
    found=true
    log "Deleting VPC endpoint $endpoint_id in $region"
    run aws --region "$region" ec2 delete-vpc-endpoints --vpc-endpoint-ids "$endpoint_id" >/dev/null
  done < <(jq -r '.VpcEndpoints[]? | .VpcEndpointId' <<<"$endpoints_json")

  if [[ "$found" == "false" ]]; then
    log "No VPC endpoints found in VPC $vpc_id ($region)"
  fi
}

delete_nat_gateways_and_eips() {
  local region="$1"
  local vpc_id="$2"

  local nat_json
  nat_json="$(aws_json "$region" ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id")"

  local found_nat=false
  while IFS=$'\t' read -r nat_id allocation_id; do
    [[ -n "${nat_id:-}" ]] || continue
    found_nat=true
    log "Deleting NAT gateway $nat_id in $region"
    run aws --region "$region" ec2 delete-nat-gateway --nat-gateway-id "$nat_id" >/dev/null
    wait_until \
      "Deleted NAT gateway $nat_id in $region" \
      "$POLL_TIMEOUT_SECONDS" \
      bash -lc "test \"\$(aws --region '$region' ec2 describe-nat-gateways --nat-gateway-ids '$nat_id' --output json 2>/dev/null | jq -r '.NatGateways[0].State // empty' || true)\" = 'deleted'"

    if [[ -n "${allocation_id:-}" && "$allocation_id" != "null" ]]; then
      log "Releasing Elastic IP allocation $allocation_id in $region"
      if ! aws --region "$region" ec2 release-address --allocation-id "$allocation_id" >/dev/null 2>&1; then
        warn "Could not release Elastic IP allocation $allocation_id in $region"
      fi
    fi
  done < <(jq -r '.NatGateways[]? | [.NatGatewayId, (.NatGatewayAddresses[0].AllocationId // empty)] | @tsv' <<<"$nat_json")

  if [[ "$found_nat" == "false" ]]; then
    log "No NAT gateways found in VPC $vpc_id ($region)"
  fi

  local addresses_json
  addresses_json="$(aws_json "$region" ec2 describe-addresses)"
  while IFS= read -r allocation_id; do
    [[ -n "${allocation_id:-}" ]] || continue
    log "Releasing unattached Elastic IP allocation $allocation_id in $region"
    if ! aws --region "$region" ec2 release-address --allocation-id "$allocation_id" >/dev/null 2>&1; then
      warn "Could not release Elastic IP allocation $allocation_id in $region"
    fi
  done < <(jq -r --arg prefix "$PREFIX-nat-eip-" '.Addresses[]? | select((.Tags // []) | any(.Key == "Name" and (.Value | startswith($prefix)))) | select((.AssociationId // "") == "") | .AllocationId' <<<"$addresses_json")
}

delete_route_tables() {
  local region="$1"
  local vpc_id="$2"

  local route_tables_json
  route_tables_json="$(aws_json "$region" ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id")"

  local found=false
  while IFS= read -r route_table_id; do
    [[ -n "${route_table_id:-}" ]] || continue
    found=true

    while IFS= read -r association_id; do
      [[ -n "${association_id:-}" ]] || continue
      log "Disassociating route table association $association_id in $region"
      if ! aws --region "$region" ec2 disassociate-route-table --association-id "$association_id" >/dev/null 2>&1; then
        warn "Could not disassociate route table association $association_id in $region"
      fi
    done < <(jq -r --arg rt "$route_table_id" '.RouteTables[]? | select(.RouteTableId == $rt) | .Associations[]? | select((.Main // false) == false) | .RouteTableAssociationId' <<<"$route_tables_json")

    log "Deleting route table $route_table_id in $region"
    if ! aws --region "$region" ec2 delete-route-table --route-table-id "$route_table_id" >/dev/null 2>&1; then
      warn "Could not delete route table $route_table_id in $region"
    fi
  done < <(jq -r --arg prefix "$PREFIX-" '.RouteTables[]? | select(((.Associations // []) | any(.Main == true)) | not) | select((.Tags // []) | any(.Key == "Name" and (.Value | startswith($prefix)))) | .RouteTableId' <<<"$route_tables_json")

  if [[ "$found" == "false" ]]; then
    log "No matching custom route tables found in VPC $vpc_id ($region)"
  fi
}

delete_subnets() {
  local region="$1"
  local vpc_id="$2"

  local subnets_json
  subnets_json="$(aws_json "$region" ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id")"

  local found=false
  while IFS= read -r subnet_id; do
    [[ -n "${subnet_id:-}" ]] || continue
    found=true
    log "Deleting subnet $subnet_id in $region"
    if ! aws --region "$region" ec2 delete-subnet --subnet-id "$subnet_id" >/dev/null 2>&1; then
      warn "Could not delete subnet $subnet_id in $region"
    fi
  done < <(jq -r '.Subnets[]? | .SubnetId' <<<"$subnets_json")

  if [[ "$found" == "false" ]]; then
    log "No subnets found in VPC $vpc_id ($region)"
  fi
}

delete_internet_gateways() {
  local region="$1"
  local vpc_id="$2"

  local igw_json
  igw_json="$(aws_json "$region" ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id")"

  local found=false
  while IFS= read -r igw_id; do
    [[ -n "${igw_id:-}" ]] || continue
    found=true
    log "Detaching internet gateway $igw_id from VPC $vpc_id in $region"
    if ! aws --region "$region" ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" >/dev/null 2>&1; then
      warn "Could not detach internet gateway $igw_id from VPC $vpc_id in $region"
    fi
    log "Deleting internet gateway $igw_id in $region"
    if ! aws --region "$region" ec2 delete-internet-gateway --internet-gateway-id "$igw_id" >/dev/null 2>&1; then
      warn "Could not delete internet gateway $igw_id in $region"
    fi
  done < <(jq -r '.InternetGateways[]? | .InternetGatewayId' <<<"$igw_json")

  if [[ "$found" == "false" ]]; then
    log "No internet gateways attached to VPC $vpc_id in $region"
  fi
}

delete_security_groups() {
  local region="$1"
  local vpc_id="$2"

  local security_groups_json
  security_groups_json="$(aws_json "$region" ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id")"

  local found=false
  while IFS= read -r group_id; do
    [[ -n "${group_id:-}" ]] || continue
    found=true
    log "Deleting security group $group_id in $region"
    if ! aws --region "$region" ec2 delete-security-group --group-id "$group_id" >/dev/null 2>&1; then
      warn "Could not delete security group $group_id in $region"
    fi
  done < <(jq -r '.SecurityGroups[]? | select(.GroupName != "default") | .GroupId' <<<"$security_groups_json")

  if [[ "$found" == "false" ]]; then
    log "No non-default security groups found in VPC $vpc_id ($region)"
  fi
}

cleanup_vpcs() {
  log "Starting VPC cleanup"

  for region in "${REGIONS[@]}"; do
    local vpcs_json
    vpcs_json="$(aws_json "$region" ec2 describe-vpcs)"

    local found=false
    while IFS= read -r vpc_id; do
      [[ -n "${vpc_id:-}" ]] || continue
      found=true
      log "Processing VPC $vpc_id in $region"

      delete_elbv2_in_vpc "$region" "$vpc_id"
      delete_vpc_endpoints "$region" "$vpc_id"
      delete_nat_gateways_and_eips "$region" "$vpc_id"
      delete_route_tables "$region" "$vpc_id"
      delete_subnets "$region" "$vpc_id"
      delete_internet_gateways "$region" "$vpc_id"
      delete_security_groups "$region" "$vpc_id"

      log "Deleting VPC $vpc_id in $region"
      if ! aws --region "$region" ec2 delete-vpc --vpc-id "$vpc_id" >/dev/null 2>&1; then
        warn "Could not delete VPC $vpc_id in $region; listing remaining dependencies"
        aws --region "$region" ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --output json \
          | jq -r '.NetworkInterfaces[]? | "ENI\t\(.NetworkInterfaceId)\t\(.Status)\t\(.Description // "no-description")"' >&2 || true
      fi
    done < <(jq -r --arg name "${PREFIX}-vpc" '.Vpcs[]? | select((.Tags // []) | any(.Key == "Name" and .Value == $name)) | .VpcId' <<<"$vpcs_json")

    if [[ "$found" == "false" ]]; then
      log "No matching VPCs found in $region"
    fi
  done
}

main() {
  require_cmd aws
  require_cmd jq

  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials are not valid; run aws sts get-caller-identity manually to diagnose"

  print_identity
  confirm

  cleanup_eks
  cleanup_mq
  cleanup_rds
  cleanup_kms_alias
  cleanup_iam_roles
  cleanup_secrets
  cleanup_ecr
  cleanup_vpcs

  log "Cleanup completed."
}

main "$@"
