# Class Data Sharing (CDS) Optimization

This document describes the CDS implementation for AcmeCorp Platform services.

## Overview

Class Data Sharing (CDS) reduces JVM startup time and memory usage by pre-processing and sharing class metadata across JVM instances.

## Implementation

### Spring Boot Services
- **Services**: gateway, orders, billing, notification, analytics
- **CDS Archive Generation**: During Docker build using `-XX:ArchiveClassesAtExit`
- **Startup**: Uses `-Xshare:on -XX:SharedArchiveFile=/opt/app/app.jsa`

### Quarkus Service
- **Service**: catalog
- **CDS Archive Generation**: During Docker build with Quarkus-specific configuration
- **Startup**: Uses standard AppCDS flags

## Docker Build Process

1. **Build Stage**: Compile application
2. **Extract Stage**: Extract Spring Boot layers (Spring Boot only)
3. **CDS Generation Stage**: 
   - Start application with `-XX:ArchiveClassesAtExit`
   - Use timeout to prevent hanging
   - Generate `/tmp/app.jsa` archive
4. **Runtime Stage**: 
   - Copy CDS archive to `/opt/app/app.jsa`
   - Create conditional startup script

## Environment Variables

- `ENABLE_CDS=true|false` - Toggle CDS usage at runtime
- Default: `ENABLE_CDS=true`

## Usage

### Build with CDS
```bash
docker build -t service-name:cds .
```

### Run with CDS enabled (default)
```bash
docker run -e ENABLE_CDS=true service-name:cds
```

### Run without CDS
```bash
docker run -e ENABLE_CDS=false service-name:cds
```

## Startup Script Logic

The startup script (`/opt/app/start.sh`) checks:
1. Is `ENABLE_CDS=true`?
2. Does `/opt/app/app.jsa` exist?

If both conditions are met, starts with CDS flags, otherwise falls back to standard JVM startup.

## Rebuilding CDS Archives

CDS archives are tied to the exact class files and JVM version. Rebuild when:
- Dependencies change
- Application code changes
- JVM version changes

Simply rebuild the Docker image to regenerate the CDS archive.

## Limitations

- CDS archives are JVM version specific
- Archive generation adds ~30 seconds to build time
- Archive generation may fail for some applications (gracefully handled)
- Memory benefits are most apparent with multiple instances

## Performance Expectations

- **Startup Time**: 10-30% reduction
- **Memory Usage**: 5-15% reduction per instance
- **Build Time**: +30 seconds for archive generation

## Troubleshooting

### CDS Archive Not Generated
- Check build logs for timeout or errors during generation stage
- Verify application can start successfully
- Some applications may not be compatible with CDS

### Runtime Issues
- Set `ENABLE_CDS=false` to disable CDS
- Check logs for CDS-related error messages
- Verify archive file exists: `ls -la /opt/app/app.jsa`