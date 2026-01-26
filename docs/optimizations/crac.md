# Coordinated Restore at Checkpoint (CRaC) Optimization

This document describes the CRaC implementation for AcmeCorp Platform Spring Boot services.

## Overview

Coordinated Restore at Checkpoint (CRaC) is a technology that allows Java applications to:
- Create a checkpoint of a running JVM process
- Restore from that checkpoint with significantly reduced startup time
- Maintain application state and warm JIT compilation

## Supported Services

CRaC is implemented **only** for Spring Boot services. Quarkus services are not supported.

| Service | Port | Main Class | Health Endpoint | CRaC Status |
|---------|------|------------|-----------------|-------------|
| **gateway-service** | 8080 | GatewayServiceApplication | `/actuator/health` | ✅ Enabled |
| **orders-service** | 8081 | OrdersServiceApplication | `/actuator/health` | ✅ Enabled |
| **billing-service** | 8082 | BillingServiceApplication | `/actuator/health` | ✅ Enabled |
| **notification-service** | 8083 | NotificationServiceApplication | `/actuator/health` | ✅ Enabled |
| **analytics-service** | 8084 | AnalyticsServiceApplication | `/actuator/health` | ✅ Enabled |

## Environment Variables

- `CRAC_MODE=checkpoint|restore|off` - Controls CRaC behavior (default: `off`)
- `CRAC_CHECKPOINT_DIR=/opt/crac` - Directory for checkpoint files
- `CRAC_WARMUP_URLS` - Comma-separated URLs to hit before checkpoint (optional)

## Implementation Details

### Docker Images
- **Base Runtime**: Azul Zulu CRaC-enabled JDK 21
- **Multi-stage Build**: Separate build and runtime stages
- **Checkpoint Support**: Dedicated checkpoint generation stage

### Startup Modes

#### 1. Normal Mode (`CRAC_MODE=off`)
Standard JVM startup without CRaC.

#### 2. Checkpoint Mode (`CRAC_MODE=checkpoint`)
1. Start application normally
2. Wait for health endpoint to be ready
3. Execute warmup requests (if configured)
4. Create checkpoint using `jcmd <pid> JDK.checkpoint`
5. Exit cleanly

#### 3. Restore Mode (`CRAC_MODE=restore`)
1. Restore from existing checkpoint
2. Continue running with pre-warmed state

## Usage Instructions

### Building CRaC Images

```bash
# Build a specific service
cd services/spring-boot/orders-service
docker build -t orders-service:crac .

# Build all Spring Boot services
./scripts/crac/build-all.sh
```

### Creating Checkpoints

```bash
# Create checkpoint for orders-service
./scripts/crac/checkpoint.sh orders-service

# Create checkpoints for all services
./scripts/crac/checkpoint-all.sh
```

### Restoring from Checkpoints

```bash
# Restore orders-service from checkpoint
./scripts/crac/restore.sh orders-service

# Restore all services from checkpoints
./scripts/crac/restore-all.sh
```

### Manual Docker Commands

#### Create Checkpoint
```bash
# Start in checkpoint mode
docker run -d --name orders-checkpoint \
  -e CRAC_MODE=checkpoint \
  -e CRAC_CHECKPOINT_DIR=/opt/crac \
  -v crac-orders:/opt/crac \
  orders-service:crac

# Wait for checkpoint completion (container will exit)
docker wait orders-checkpoint
```

#### Restore from Checkpoint
```bash
# Start in restore mode
docker run -d --name orders-service \
  -p 8081:8081 \
  -e CRAC_MODE=restore \
  -e CRAC_CHECKPOINT_DIR=/opt/crac \
  -v crac-orders:/opt/crac \
  orders-service:crac
```

## Performance Expectations

### Startup Time Comparison
- **Normal JVM**: 8-15 seconds to ready
- **CRaC Restore**: 0.5-2 seconds to ready
- **Improvement**: 80-90% reduction in startup time

### Memory Usage
- **Checkpoint Size**: 100-300 MB per service
- **Runtime Memory**: Similar to normal JVM
- **Additional Overhead**: Checkpoint storage requirements

## Known Limitations

### System Requirements
- **Linux Kernel**: 5.9+ with CRIU support
- **Container Runtime**: Docker with `--privileged` or specific capabilities
- **Filesystem**: Checkpoint directory must be writable

### Application Constraints
- **Network Connections**: Closed during checkpoint, must be re-established
- **File Handles**: May need to be reopened after restore
- **Threads**: Some thread states may not be preserved
- **Security**: Requires elevated privileges for checkpoint/restore

### Spring Boot Considerations
- **Database Connections**: Connection pools are recreated after restore
- **Scheduled Tasks**: May need to be restarted
- **Caches**: In-memory caches are preserved
- **External Services**: Client connections are re-established

## Troubleshooting

### Checkpoint Creation Fails
```bash
# Check container logs
docker logs orders-checkpoint

# Verify CRaC support
docker run --rm orders-service:crac java -XX:+UnlockExperimentalVMOptions -XX:+UseCRaC -version

# Check filesystem permissions
docker run --rm -v crac-orders:/opt/crac orders-service:crac ls -la /opt/crac
```

### Restore Fails
```bash
# Verify checkpoint files exist
docker run --rm -v crac-orders:/opt/crac alpine ls -la /opt/crac

# Check for missing capabilities
docker run --privileged --rm -v crac-orders:/opt/crac orders-service:crac

# Review restore logs
docker logs orders-service
```

### Common Issues
1. **Permission Denied**: Run with `--privileged` or add required capabilities
2. **Checkpoint Not Found**: Ensure checkpoint was created successfully
3. **Network Errors**: Check that external services are available after restore
4. **Database Errors**: Verify database connections are re-established

## Development Workflow

### Local Development
1. **Development**: Use normal JVM mode for fast iteration
2. **Testing**: Create checkpoints for integration testing
3. **Production**: Use restore mode for fast cold starts

### CI/CD Integration
- **Build Stage**: Create CRaC-enabled images
- **Test Stage**: Validate checkpoint creation (if supported)
- **Deploy Stage**: Use restore mode for production deployments

## Security Considerations

- **Checkpoint Contents**: May contain sensitive data (secrets, tokens)
- **Storage Security**: Encrypt checkpoint volumes in production
- **Access Control**: Limit access to checkpoint directories
- **Privilege Requirements**: Minimize required capabilities

## Monitoring and Observability

### Metrics to Track
- Checkpoint creation time
- Checkpoint file size
- Restore time to ready
- Application performance after restore

### Health Checks
All services maintain standard health endpoints after restore:
- Spring Boot: `/actuator/health`
- Response time should be sub-second after restore