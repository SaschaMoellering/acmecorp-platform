#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

branch="$(git rev-parse --abbrev-ref HEAD)"

expected_spring_java=""
case "$branch" in
  java11) expected_spring_java="11" ;;
  java17) expected_spring_java="17" ;;
  java21|main) expected_spring_java="21" ;;
  java25) expected_spring_java="25" ;;
  *)
    echo "ERROR: Unsupported branch '$branch'."
    echo "Supported branches: java11, java17, java21, main, java25."
    echo "Update scripts/check-java-versions.sh if this is intentional."
    exit 1
    ;;
esac

expected_quarkus_java="21"

errors=()
add_error() {
  errors+=("$1")
}

get_xml_tag() {
  local file="$1"
  local tag="$2"
  sed -n "s:.*<$tag>\\(.*\\)</$tag>.*:\\1:p" "$file" | head -n1
}

normalize_value() {
  local value="$1"
  echo "$value" | tr -d '[:space:]'
}

check_value() {
  local label="$1"
  local file="$2"
  local value="$3"
  local expected="$4"

  if [[ -z "$value" ]]; then
    return 0
  fi
  if [[ "$value" == "\${java.version}" ]]; then
    return 0
  fi
  if [[ "$value" != "$expected" ]]; then
    add_error "$file: $label is '$value' (expected '$expected')"
  fi
}

check_spring_pom() {
  local pom="$1"
  local java_version
  java_version="$(normalize_value "$(get_xml_tag "$pom" "java.version")")"

  if [[ -z "$java_version" ]]; then
    add_error "$pom: missing <java.version> (expected $expected_spring_java)"
  else
    check_value "<java.version>" "$pom" "$java_version" "$expected_spring_java"
  fi

  local release source target
  release="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.release")")"
  source="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.source")")"
  target="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.target")")"

  check_value "<maven.compiler.release>" "$pom" "$release" "$expected_spring_java"
  check_value "<maven.compiler.source>" "$pom" "$source" "$expected_spring_java"
  check_value "<maven.compiler.target>" "$pom" "$target" "$expected_spring_java"

  local plugin_release plugin_source plugin_target
  plugin_release="$(normalize_value "$(rg -m1 -n "<release>" "$pom" 2>/dev/null | sed -n 's:.*<release>\\(.*\\)</release>.*:\\1:p' || true)")"
  plugin_source="$(normalize_value "$(rg -m1 -n "<source>" "$pom" 2>/dev/null | sed -n 's:.*<source>\\(.*\\)</source>.*:\\1:p' || true)")"
  plugin_target="$(normalize_value "$(rg -m1 -n "<target>" "$pom" 2>/dev/null | sed -n 's:.*<target>\\(.*\\)</target>.*:\\1:p' || true)")"

  check_value "maven-compiler-plugin <release>" "$pom" "$plugin_release" "$expected_spring_java"
  check_value "maven-compiler-plugin <source>" "$pom" "$plugin_source" "$expected_spring_java"
  check_value "maven-compiler-plugin <target>" "$pom" "$plugin_target" "$expected_spring_java"

  local enforcer_version
  enforcer_version="$(normalize_value "$(rg -m1 -n "<requireJavaVersion>" -C 3 "$pom" 2>/dev/null | sed -n 's:.*<version>\\(.*\\)</version>.*:\\1:p' || true)")"
  if [[ -n "$enforcer_version" ]]; then
    check_value "maven-enforcer-plugin RequireJavaVersion" "$pom" "$enforcer_version" "$expected_spring_java"
  fi
}

check_quarkus_pom() {
  local pom="$1"
  local java_version
  java_version="$(normalize_value "$(get_xml_tag "$pom" "java.version")")"
  if [[ -n "$java_version" && "$java_version" != "$expected_quarkus_java" ]]; then
    add_error "$pom: <java.version> is '$java_version' (expected $expected_quarkus_java)"
  fi

  local release source target
  release="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.release")")"
  source="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.source")")"
  target="$(normalize_value "$(get_xml_tag "$pom" "maven.compiler.target")")"

  check_value "<maven.compiler.release>" "$pom" "$release" "$expected_quarkus_java"
  check_value "<maven.compiler.source>" "$pom" "$source" "$expected_quarkus_java"
  check_value "<maven.compiler.target>" "$pom" "$target" "$expected_quarkus_java"
}

check_quarkus_dockerfile() {
  local file="$1"
  local from_lines
  from_lines="$(rg -n "^FROM " "$file" || true)"
  if [[ -z "$from_lines" ]]; then
    add_error "$file: missing FROM lines"
    return
  fi

  while IFS= read -r line; do
    local image
    image="$(echo "$line" | awk '{print $2}')"
    if [[ "$image" != *"temurin"* ]] || [[ "$image" != *"21"* ]]; then
      add_error "$file: base image '$image' is not a Temurin Java 21 image"
    fi
    if [[ "$image" == *"11"* || "$image" == *"17"* || "$image" == *"25"* ]]; then
      if [[ "$image" != *"21"* ]]; then
        add_error "$file: base image '$image' is not Java 21"
      fi
    fi
  done <<< "$from_lines"
}

spring_poms=()
while IFS= read -r pom; do
  spring_poms+=("$pom")
done < <(find services/spring-boot -maxdepth 2 -name pom.xml -type f | sort)

quarkus_poms=()
while IFS= read -r pom; do
  quarkus_poms+=("$pom")
done < <(find services/quarkus -maxdepth 2 -name pom.xml -type f 2>/dev/null | sort)

for pom in "${spring_poms[@]}"; do
  check_spring_pom "$pom"
done

for pom in "${quarkus_poms[@]}"; do
  check_quarkus_pom "$pom"
done

quarkus_dockerfiles=()
while IFS= read -r file; do
  quarkus_dockerfiles+=("$file")
done < <(find services/quarkus -name Dockerfile -type f 2>/dev/null | sort)

for file in "${quarkus_dockerfiles[@]}"; do
  check_quarkus_dockerfile "$file"
done

echo "Java Version Correctness"
printf '%-10s | %-22s | %-22s\n' "branch" "expected spring java" "expected quarkus java"
printf '%-10s | %-22s | %-22s\n' "$branch" "$expected_spring_java" "$expected_quarkus_java"
echo

if [[ "${#errors[@]}" -gt 0 ]]; then
  echo "Violations:"
  for err in "${errors[@]}"; do
    echo " - $err"
  done
  exit 1
fi

echo "All Java version checks passed."
