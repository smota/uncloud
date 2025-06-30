# UnCloud

Exit the cloud and own your data. This project provides the automation to build your own private, self-hosted infrastructure using Docker Swarm.

## 🏗️ Architecture Overview

UnCloud is a comprehensive Docker Swarm-based infrastructure that provides:

- **Frontend Services** (External Access): Password Manager, Sync Service, Website
- **Backend Services** (Internal Only): Email, Database, Password Manager Backend, NAS
- **Infrastructure Services**: Traefik (Reverse Proxy), DNS, Load Balancer
- **Security**: HTTPS everywhere, internal-only backend services, random ports
- **Scalability**: Docker Swarm with load balancing and high availability

## 📁 Project Structure

```
uncloud/
├── docker-compose.yml              # Main orchestration file
├── config/
│   └── common.env                  # Central configuration variables
├── secrets/
│   ├── env.template               # Secrets template (copy to .env)
│   └── .env                      # Actual secrets (gitignored)
├── services/
│   ├── frontend/                  # External-facing services
│   │   ├── passwordmanager/
│   │   ├── syncservice/
│   │   └── website/
│   ├── backend/                   # Internal-only services
│   │   ├── email/
│   │   ├── database/
│   │   ├── pwdmanager/
│   │   └── nas/
│   └── infrastructure/            # Core infrastructure
│       ├── traefik/
│       ├── dns/
│       └── loadbalancer/
├── build/                         # Docker image build automation
│   ├── dockerfiles/               # Dockerfiles for each service
│   │   ├── passwordmanager/
│   │   ├── syncservice/
│   │   ├── website/
│   │   ├── pwdmanager-backend/
│   │   ├── email-backend/
│   │   └── nas/
│   ├── build-images.ps1          # Windows image build script
│   ├── build-images.sh           # Linux image build script
│   ├── update-compose-images.ps1 # Windows compose update script
│   ├── update-compose-images.sh  # Linux compose update script
│   ├── build-and-deploy.ps1      # Windows build & deploy script
│   └── build-and-deploy.sh       # Linux build & deploy script
└── automation/
    ├── windows/                   # Windows PowerShell scripts
    │   ├── init-swarm.ps1
    │   ├── deploy-all.ps1
    │   ├── deploy-frontend.ps1
    │   └── deploy-backend.ps1
    └── linux/                     # Linux bash scripts
        ├── init-swarm.sh
        ├── deploy-all.sh
        ├── deploy-frontend.sh
        └── deploy-backend.sh
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- Docker Swarm enabled
- Domain name with DNS access
- Dynamic DNS service (optional but recommended)

### 1. Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd uncloud
   ```

2. **Configure secrets:**
   ```bash
   # Copy the template and configure your secrets
   cp secrets/env.template secrets/.env
   # Edit secrets/.env with your actual values
   ```

3. **Configure common settings:**
   ```bash
   # Edit config/common.env with your domain and preferences
   ```

### 2. Build and Deploy Options

#### Option A: Complete Build and Deploy (Recommended)

**Windows:**
```powershell
# Build all images and deploy everything
.\build\build-and-deploy.ps1

# Or with custom registry and tag
.\build\build-and-deploy.ps1 -Registry "myregistry" -Tag "v1.0.0"

# Build only (skip deployment)
.\build\build-and-deploy.ps1 -SkipDeploy

# Deploy only (skip building)
.\build\build-and-deploy.ps1 -SkipBuild
```

**Linux:**
```bash
# Make scripts executable
chmod +x build/*.sh automation/linux/*.sh

# Build all images and deploy everything
./build/build-and-deploy.sh

# Or with custom registry and tag
./build/build-and-deploy.sh "myregistry" "v1.0.0"

# Build only (skip deployment)
./build/build-and-deploy.sh "uncloud" "latest" "false" "false" "false" "true"

# Deploy only (skip building)
./build/build-and-deploy.sh "uncloud" "latest" "false" "false" "true" "false"
```

#### Option B: Manual Step-by-Step Process

**1. Build Images:**
```bash
# Windows
.\build\build-images.ps1 -Registry "uncloud" -Tag "latest"

# Linux
./build/build-images.sh "uncloud" "latest"
```

**2. Update Compose Files:**
```bash
# Windows
.\build\update-compose-images.ps1 -Registry "uncloud" -Tag "latest"

# Linux
./build/update-compose-images.sh "uncloud" "latest"
```

**3. Initialize and Deploy:**
```bash
# Windows
.\automation\windows\init-swarm.ps1
.\automation\windows\deploy-all.ps1

# Linux
./automation/linux/init-swarm.sh
./automation/linux/deploy-all.sh
```

#### Option C: Distributed Deployment (Production)

**Backend Host:**
```bash
# Build backend images only
./build/build-images.sh "uncloud" "latest" "false" "false" "false" "false" "linux/amd64" "backend"

# Initialize and deploy backend services
./automation/linux/init-swarm.sh
./automation/linux/deploy-backend.sh
```

**Frontend Host:**
```bash
# Build frontend images only
./build/build-images.sh "uncloud" "latest" "false" "false" "false" "false" "linux/amd64" "frontend"

# Initialize and deploy frontend services
./automation/linux/init-swarm.sh
./automation/linux/deploy-frontend.sh
```

## 🔧 Configuration

### Central Configuration (`config/common.env`)

Key configuration variables:
- `PROJECT_NAME`: Your project name
- `DOMAIN_NAME`: Your domain name
- `PASSWORDMANAGER_PORT`, `SYNCSERVICE_PORT`, etc.: Random ports for security
- `SSL_EMAIL`: Email for Let's Encrypt certificates
- `DATABASE_TYPE`, `DATABASE_VERSION`: Database configuration

### Secrets (`secrets/.env`)

**IMPORTANT:** Never commit this file to version control!

Key secrets to configure:
- Database passwords and credentials
- Email service passwords
- API keys for dynamic DNS
- SSL certificate paths
- Service-specific encryption keys

## 🐳 Docker Image Build System

### Build Automation Features

- **Multi-platform Support**: Build for different architectures (linux/amd64, linux/arm64)
- **Registry Integration**: Push to Docker Hub, GitHub Container Registry, or private registries
- **Caching Control**: Option to skip cache for fresh builds
- **Parallel Building**: Efficient parallel image building
- **Compose Integration**: Automatic update of docker-compose files with built images

### Build Scripts

#### `build-images.ps1` / `build-images.sh`
Builds all Docker images for the UnCloud infrastructure.

**Parameters:**
- `Registry`: Docker registry name (default: "uncloud")
- `Tag`: Image tag (default: "latest")
- `Push`: Push images to registry (default: false)
- `NoCache`: Skip Docker cache (default: false)
- `Platform`: Target platform (default: "linux/amd64")

**Examples:**
```bash
# Basic build
./build/build-images.sh

# Build with custom registry and push
./build/build-images.sh "myregistry" "v1.0.0" "true"

# Build for ARM64 without cache
./build/build-images.sh "uncloud" "latest" "false" "true" "linux/arm64"
```

#### `update-compose-images.ps1` / `update-compose-images.sh`
Updates docker-compose files to use built images instead of dummy images.

**Parameters:**
- `Registry`: Docker registry name (default: "uncloud")
- `Tag`: Image tag (default: "latest")

#### `build-and-deploy.ps1` / `build-and-deploy.sh`
Complete automation script that builds images and deploys the infrastructure.

**Parameters:**
- `Registry`: Docker registry name (default: "uncloud")
- `Tag`: Image tag (default: "latest")
- `Push`: Push images to registry (default: false)
- `NoCache`: Skip Docker cache (default: false)
- `SkipBuild`: Skip image building (default: false)
- `SkipDeploy`: Skip deployment (default: false)
- `Platform`: Target platform (default: "linux/amd64")
- `DeploymentType`: Deployment type - all, frontend, backend (default: "all")

### Dockerfile Structure

Each service has its own Dockerfile optimized for its specific needs:

- **Frontend Services**: Multi-stage builds with Node.js for building and Nginx for serving
- **Backend Services**: Python-based with proper security and non-root users
- **Infrastructure Services**: Use official images with custom configurations

### Image Naming Convention

Images follow the pattern: `{registry}/{service-name}:{tag}`

Examples:
- `uncloud/passwordmanager:latest`
- `uncloud/syncservice:v1.0.0`
- `uncloud/pwdmanager-backend:latest`

## 🌐 Service Access

After deployment, access your services at:

- **Main Website**: `https://yourdomain.com`
- **Password Manager**: `https://pwd.yourdomain.com`
- **Sync Service**: `https://sync.yourdomain.com`
- **Traefik Dashboard**: `https://traefik.yourdomain.com`

## 🔒 Security Features

- **HTTPS Everywhere**: Automatic SSL certificates via Let's Encrypt
- **Internal Backend**: Backend services are not accessible from external networks
- **Random Ports**: Non-standard ports to prevent automated attacks
- **Network Isolation**: Separate networks for frontend, backend, and infrastructure
- **Secrets Management**: Centralized secrets with proper access controls
- **Non-root Containers**: All services run as non-root users
- **Image Security**: Multi-stage builds with minimal attack surface

## 📊 Monitoring and Management

### Service Status
```bash
# Check all services
docker stack services uncloud

# View service logs
docker service logs <service-name>

# Monitor resource usage
docker stats
```

### Traefik Dashboard
Access the Traefik dashboard at `https://traefik.yourdomain.com` to:
- Monitor HTTP traffic
- View SSL certificate status
- Check service health
- Manage routing rules

## 🔄 Updates and Maintenance

### Update Services
```bash
# Windows - Build new images and redeploy
.\build\build-and-deploy.ps1 -Tag "v1.1.0" -NoCache

# Linux - Build new images and redeploy
./build/build-and-deploy.sh "uncloud" "v1.1.0" "false" "true"
```

### Backup and Restore
```bash
# Backup volumes
docker run --rm -v uncloud_database_data:/data -v $(pwd):/backup alpine tar czf /backup/database_backup.tar.gz -C /data .

# Restore volumes
docker run --rm -v uncloud_database_data:/data -v $(pwd):/backup alpine tar xzf /backup/database_backup.tar.gz -C /data
```

## 🛠️ Troubleshooting

### Common Issues

1. **Services not starting:**
   - Check Docker Swarm is active: `docker info --format "{{.Swarm.LocalNodeState}}"`
   - Verify secrets file exists: `ls -la secrets/.env`
   - Check service logs: `docker service logs <service-name>`

2. **Image build failures:**
   - Check Docker is running: `docker version`
   - Verify Dockerfile syntax: `docker build --dry-run`
   - Check disk space: `df -h`

3. **SSL certificate issues:**
   - Ensure domain DNS points to your server
   - Check Traefik logs: `docker service logs uncloud_traefik`
   - Verify SSL email is configured in `config/common.env`

4. **Network connectivity:**
   - Verify networks exist: `docker network ls`
   - Check service connectivity: `docker exec <container> ping <service>`

### Logs and Debugging
```bash
# View all service logs
docker stack services uncloud --format "{{.Name}}" | xargs -I {} docker service logs {}

# Check specific service health
docker service ps <service-name>

# Inspect service configuration
docker service inspect <service-name>

# Check image details
docker images | grep uncloud
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This infrastructure is designed for personal use and learning. For production environments, ensure proper security hardening, monitoring, and backup procedures are in place.

## 🆘 Support

- Check the troubleshooting section above
- Review service-specific documentation
- Open an issue for bugs or feature requests
- Join our community discussions

---

**UnCloud** - Own your data, control your infrastructure.
