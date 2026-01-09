#!/usr/bin/env python3
import json
import os
import re
import subprocess
from xml.etree import ElementTree as ET

REPO = os.getcwd()

SERVICES = [
    {"path": "services/spring-boot/orders-service", "framework": "Spring Boot"},
    {"path": "services/spring-boot/billing-service", "framework": "Spring Boot"},
    {"path": "services/spring-boot/notification-service", "framework": "Spring Boot"},
    {"path": "services/spring-boot/analytics-service", "framework": "Spring Boot"},
    {"path": "services/spring-boot/gateway-service", "framework": "Spring Boot"},
    {"path": "services/quarkus/catalog-service", "framework": "Quarkus"},
]


def run(cmd):
    return subprocess.check_output(cmd, text=True).strip()


def text_of(elem):
    return elem.text.strip() if elem is not None and elem.text else ""


def find_child(parent, tag):
    for child in list(parent):
        if child.tag.endswith(tag):
            return child
    return None


def parse_pom(pom_path):
    if not os.path.exists(pom_path):
        return {}
    tree = ET.parse(pom_path)
    root = tree.getroot()
    props = {}
    props_elem = find_child(root, "properties")
    if props_elem is not None:
        for child in list(props_elem):
            key = re.sub(r"^\{.*\}", "", child.tag)
            props[key] = text_of(child)

    parent = find_child(root, "parent")
    parent_artifact = text_of(find_child(parent, "artifactId")) if parent is not None else ""
    parent_version = text_of(find_child(parent, "version")) if parent is not None else ""

    dm = find_child(root, "dependencyManagement")
    dm_version = ""
    if dm is not None:
        deps = find_child(dm, "dependencies")
        if deps is not None:
            for dep in list(deps):
                if not dep.tag.endswith("dependency"):
                    continue
                gid = text_of(find_child(dep, "groupId"))
                aid = text_of(find_child(dep, "artifactId"))
                if gid == "org.springframework.boot" and aid == "spring-boot-dependencies":
                    dm_version = text_of(find_child(dep, "version"))
                if gid == "io.quarkus" and aid == "quarkus-bom" and not dm_version:
                    dm_version = text_of(find_child(dep, "version"))

    compiler_release = ""
    compiler_source = ""
    compiler_target = ""
    build = find_child(root, "build")
    if build is not None:
        plugins = find_child(build, "plugins")
        if plugins is not None:
            for plugin in list(plugins):
                if not plugin.tag.endswith("plugin"):
                    continue
                aid = text_of(find_child(plugin, "artifactId"))
                if aid == "maven-compiler-plugin":
                    config = find_child(plugin, "configuration")
                    if config is not None:
                        compiler_release = text_of(find_child(config, "release"))
                        compiler_source = text_of(find_child(config, "source"))
                        compiler_target = text_of(find_child(config, "target"))

    return {
        "properties": props,
        "parent_artifact": parent_artifact,
        "parent_version": parent_version,
        "dm_version": dm_version,
        "compiler_release": compiler_release,
        "compiler_source": compiler_source,
        "compiler_target": compiler_target,
    }


def resolve_prop(value, props):
    if not value:
        return value
    match = re.fullmatch(r"\$\{([^}]+)\}", value)
    if match:
        key = match.group(1)
        return props.get(key, value)
    return value


def extract_java_target(pom):
    props = pom.get("properties", {})
    if props.get("maven.compiler.release"):
        return resolve_prop(props.get("maven.compiler.release"), props), "properties:maven.compiler.release"
    if pom.get("compiler_release"):
        return resolve_prop(pom.get("compiler_release"), props), "plugin:release"
    if props.get("java.version"):
        return resolve_prop(props.get("java.version"), props), "properties:java.version"
    if pom.get("compiler_source"):
        return resolve_prop(pom.get("compiler_source"), props), "plugin:source"
    if pom.get("compiler_target"):
        return resolve_prop(pom.get("compiler_target"), props), "plugin:target"
    return "unknown", "unknown"


def extract_framework_version(pom, framework):
    props = pom.get("properties", {})
    if framework == "Spring Boot":
        if props.get("spring.boot.version"):
            return resolve_prop(props.get("spring.boot.version"), props)
        if pom.get("parent_artifact") == "spring-boot-starter-parent" and pom.get("parent_version"):
            return resolve_prop(pom.get("parent_version"), props)
        if pom.get("dm_version"):
            return resolve_prop(pom.get("dm_version"), props)
    if framework == "Quarkus":
        if props.get("quarkus.platform.version"):
            return resolve_prop(props.get("quarkus.platform.version"), props)
        if pom.get("dm_version"):
            return resolve_prop(pom.get("dm_version"), props)
    return "unknown"


def parse_dockerfile(path):
    if not os.path.exists(path):
        return {"build": "unknown", "runtime": "unknown", "raw": "unknown"}
    build = None
    runtime = None
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("FROM "):
                continue
            parts = line.split()
            if len(parts) >= 2:
                image = parts[1]
                if " AS " in line or " as " in line:
                    if build is None:
                        build = image
                    else:
                        runtime = image
                else:
                    if runtime is None:
                        runtime = image
    if build and runtime:
        raw = f"build={build}; runtime={runtime}"
    elif build and not runtime:
        raw = f"build={build}"
    elif runtime:
        raw = f"runtime={runtime}"
    else:
        raw = "unknown"
    return {"build": build, "runtime": runtime, "raw": raw}


def extract_java_from_image(image):
    if not image:
        return None
    match = re.search(r"(?:temurin|openjdk|java)[^\d]*(\d+)", image)
    if match:
        return match.group(1)
    return None


def derive_java_from_docker(docker):
    build = extract_java_from_image(docker.get("build"))
    runtime = extract_java_from_image(docker.get("runtime"))
    parts = []
    if build:
        parts.append(f"build={build}")
    if runtime:
        parts.append(f"runtime={runtime}")
    return "; ".join(parts) if parts else "unknown"


def makefile_excludes_quarkus(makefile_path):
    if not os.path.exists(makefile_path):
        return False
    with open(makefile_path, "r", encoding="utf-8") as f:
        content = f.read()
    return "services/quarkus" not in content


def branch_list():
    local = run(["git", "for-each-ref", "refs/heads", "--format=%(refname:short)"]).splitlines()
    java_branches = [b for b in local if re.match(r"^java\d{2,}$", b)]
    extras = [b for b in local if b in ("main", "master")]
    releases = [b for b in local if re.match(r"^release[-/].+", b)]
    ordered = []
    for b in java_branches + extras + releases:
        if b not in ordered:
            ordered.append(b)
    return ordered


def main():
    orig = run(["git", "branch", "--show-current"])
    branches = branch_list()

    results = {"branches": branches, "data": {}}

    for branch in branches:
        subprocess.check_call(["git", "checkout", branch])
        quarkus_excluded = makefile_excludes_quarkus(os.path.join(REPO, "Makefile"))
        branch_rows = []
        for svc in SERVICES:
            path = svc["path"]
            pom_path = os.path.join(REPO, path, "pom.xml")
            docker_path = os.path.join(REPO, path, "Dockerfile")
            pom = parse_pom(pom_path)
            java_target, java_source = extract_java_target(pom)
            fw_version = extract_framework_version(pom, svc["framework"])
            docker = parse_dockerfile(docker_path)
            notes = []
            if not os.path.exists(pom_path):
                notes.append("pom missing")
            if not os.path.exists(docker_path):
                notes.append("no Dockerfile")
            if svc["framework"] == "Quarkus" and quarkus_excluded:
                notes.append("excluded from Makefile targets")
            if svc["framework"] == "Quarkus" and fw_version.startswith("3") and branch == "java11":
                notes.append("Quarkus 3.x requires Java 17+; not compatible with Java 11 baseline")

            if java_target == "unknown" and svc["framework"] == "Quarkus":
                derived = derive_java_from_docker(docker)
                if derived != "unknown":
                    java_target = derived
                    notes.append("java target derived from Dockerfile")
                else:
                    notes.append("java target unknown")
            elif java_target == "unknown":
                notes.append("java target unknown")

            branch_rows.append({
                "service": path,
                "framework": svc["framework"],
                "framework_version": fw_version,
                "java_target": java_target,
                "java_source": java_source,
                "docker": docker["raw"],
                "notes": "; ".join(notes) if notes else "",
            })
        results["data"][branch] = branch_rows

    subprocess.check_call(["git", "checkout", orig])

    os.makedirs("tmp", exist_ok=True)
    with open("tmp/branch-matrix.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    lines = []
    lines.append("# Branch Runtime Matrix\n")
    lines.append("## Summary\n")
    lines.append(f"Analyzed branches: {', '.join(branches)}\n")
    lines.append("\nNotes:\n")
    lines.append("- Java targets derived from POM properties/plugins in precedence order (release, plugin release, java.version, plugin source/target).\n")
    lines.append("- Docker images are read from Dockerfiles when present.\n")
    lines.append("- Quarkus exclusion is inferred from Makefile targets.\n")
    lines.append("\n")

    for branch in branches:
        lines.append(f"## {branch}\n")
        lines.append("| service path | framework | framework version | java target | docker base image | notes |\n")
        lines.append("| --- | --- | --- | --- | --- | --- |\n")
        for row in results["data"][branch]:
            lines.append("| " + " | ".join([
                row["service"],
                row["framework"],
                row["framework_version"] or "unknown",
                row["java_target"],
                row["docker"],
                row["notes"] or "",
            ]) + " |\n")
        lines.append("\n")

    with open("BRANCH_RUNTIME_MATRIX.md", "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    main()
