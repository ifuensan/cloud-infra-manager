# TODO - Cloud Infrastructure Manager

## Próximos Proveedores Cloud

### 🔲 Google Cloud Platform (GCP)
- [ ] Script de creación de infraestructura (Compute Engine)
- [ ] Script de gestión de instancias
- [ ] Documentación específica de GCP
- [ ] Gestión de discos persistentes
- [ ] Configuración de Firewall rules

**Directorio:** `gcp/`

### 🔲 Microsoft Azure
- [ ] Script de creación de infraestructura (Virtual Machines)
- [ ] Script de gestión de instancias
- [ ] Documentación específica de Azure
- [ ] Gestión de discos gestionados
- [ ] Configuración de Network Security Groups

**Directorio:** `azure/`

### 🔲 DigitalOcean
- [ ] Script de creación de infraestructura (Droplets)
- [ ] Script de gestión de droplets
- [ ] Documentación específica de DigitalOcean
- [ ] Gestión de volúmenes
- [ ] Configuración de Firewalls

**Directorio:** `digitalocean/`

### 🔲 Hetzner Cloud
- [ ] Script de creación de infraestructura
- [ ] Script de gestión de servers
- [ ] Documentación específica de Hetzner
- [ ] Gestión de volúmenes
- [ ] Configuración de Firewalls

**Directorio:** `hetzner/`

### 🔲 Oracle Cloud Infrastructure (OCI)
- [ ] Script de creación de infraestructura
- [ ] Script de gestión de instancias
- [ ] Documentación específica de OCI
- [ ] Aprovechar el tier gratuito permanente

**Directorio:** `oracle/`

### 🔲 Linode (Akamai)
- [ ] Script de creación de infraestructura
- [ ] Script de gestión de linodes
- [ ] Documentación específica de Linode

**Directorio:** `linode/`

## Mejoras para AWS

### Gestión
- [ ] Comando para redimensionar instancias (cambiar instance type)
- [ ] Comando para crear snapshots de volúmenes EBS
- [ ] Comando para restaurar desde snapshots
- [ ] Script de backup automatizado
- [ ] Gestión de múltiples regiones
- [ ] Soporte para Auto Scaling Groups

### Monitoreo y Costos
- [ ] Script para mostrar costos estimados mensuales
- [ ] Alertas de costos (CloudWatch)
- [ ] Dashboard de uso de recursos
- [ ] Exportar métricas de CloudWatch

### Seguridad
- [ ] Auditoría de Security Groups
- [ ] Rotación automática de keys
- [ ] Integración con AWS Secrets Manager
- [ ] Habilitar cifrado en volúmenes EBS
- [ ] MFA para operaciones críticas

### Redes
- [ ] Configuración de VPC personalizada
- [ ] Soporte para subnets privadas/públicas
- [ ] VPN setup (OpenVPN o WireGuard)
- [ ] NAT Gateway configuration

## Features Generales del Proyecto

### Arquitectura Multi-Cloud
- [ ] Script unificado para gestionar múltiples proveedores
- [ ] Configuración centralizada (YAML o JSON)
- [ ] Migración entre proveedores
- [ ] Comparación de costos entre proveedores

### Automatización
- [ ] Integración con Terraform
- [ ] Integración con Ansible para configuración
- [ ] CI/CD para deploys automáticos
- [ ] Webhooks para notificaciones (Slack, Discord)

### Documentación
- [ ] Guías de migración entre proveedores
- [ ] Video tutoriales
- [ ] Troubleshooting guide
- [ ] FAQ sección
- [ ] Comparativa de costos entre proveedores

### Testing
- [ ] Tests unitarios para scripts bash
- [ ] Tests de integración
- [ ] Validación de sintaxis automatizada
- [ ] Dry-run mode para todos los scripts

### CLI Mejorada
- [ ] Tool unificado en Python o Go
- [ ] Output en JSON para integración
- [ ] Modo interactivo (TUI)
- [ ] Autocompletado para shells
- [ ] Configuración global (`~/.cloud-infra-manager/config`)

## Casos de Uso Adicionales

### Infraestructuras Específicas
- [ ] Template para WordPress hosting
- [ ] Template para Kubernetes clusters
- [ ] Template para bases de datos (PostgreSQL, MySQL)
- [ ] Template para CI/CD runners
- [ ] Template para Bitcoin/Lightning nodes
- [ ] Template para desarrollo (staging environments)

### Gestión de Proyectos
- [ ] Soporte para múltiples proyectos
- [ ] Tags y etiquetado consistente
- [ ] Inventario de recursos por proyecto
- [ ] Costos separados por proyecto

## Optimizaciones

### Performance
- [ ] Operaciones paralelas (crear múltiples recursos simultáneamente)
- [ ] Caché de consultas API
- [ ] Uso de AWS SDKs en lugar de CLI (más rápido)

### Usabilidad
- [ ] Alias y shortcuts personalizables
- [ ] Templates de configuración reutilizables
- [ ] Wizard interactivo para configuración inicial
- [ ] Validación de configuración antes de ejecutar

## Prioridades

**Alta Prioridad (Q1 2026)**
1. Limpieza completa del código AWS existente
2. Testing y validación exhaustiva de scripts AWS
3. Documentación completa para AWS
4. Soporte básico para DigitalOcean o Hetzner

**Media Prioridad (Q2 2026)**
1. Script unificado multi-cloud
2. Soporte para GCP
3. Comparativa de costos
4. Monitoreo básico

**Baja Prioridad (Futuro)**
1. Resto de proveedores cloud
2. Terraform integration
3. CLI avanzada en Python/Go
4. Templates para casos de uso específicos

## Contribuciones

Si quieres contribuir con alguno de estos TODOs:
1. Abre un issue para discutir el feature
2. Haz fork del proyecto
3. Implementa el feature siguiendo las guías de estilo
4. Envía un Pull Request

---

**Última actualización:** 2025-12-18
