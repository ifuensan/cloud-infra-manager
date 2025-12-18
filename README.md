# Cloud Infrastructure Manager

Conjunto de scripts para gestionar infraestructura en múltiples proveedores cloud de forma sencilla y eficiente.

## Descripción

Este proyecto proporciona herramientas de línea de comandos para crear, gestionar y destruir infraestructura cloud. Actualmente soporta AWS, con planes de expandirse a otros proveedores en el futuro.

## Caso de Uso Actual

Estos scripts fueron creados inicialmente para gestionar la infraestructura de [peer-observer](https://github.com/0xB10C/peer-observer), un proyecto de observación y monitoreo de la red Bitcoin.

## Proveedores Soportados

### ✅ AWS (Amazon Web Services)

Scripts completos para gestionar instancias EC2 con configuración específica para peer-observer.

**Características:**
- Creación automatizada de infraestructura EC2
- Gestión de instancias (start/stop/status)
- Destrucción completa con limpieza de recursos
- Configuración de Security Groups
- Gestión de Elastic IPs
- Volúmenes EBS con protección contra eliminación
- Gestión de SSH key pairs

### 🔜 Próximos Proveedores

Ver [TODO.md](TODO.md) para la lista completa de proveedores planeados.

## Estructura del Proyecto

```
cloud-infra-manager/
├── README.md                    # Este archivo
├── TODO.md                      # Roadmap y tareas pendientes
├── aws/
│   ├── create-aws-infra.sh      # Script de creación de infraestructura
│   └── manage-aws-instances.sh  # Script de gestión de instancias
└── (futuros proveedores aquí)
```

## AWS - Guía de Uso

### Requisitos Previos

1. **AWS CLI instalado**
   ```bash
   # macOS
   brew install awscli

   # Linux (Ubuntu/Debian)
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **Credenciales AWS configuradas**
   ```bash
   aws configure
   ```

### Crear Infraestructura

El script `create-aws-infra.sh` crea toda la infraestructura necesaria:

```bash
cd aws
./create-aws-infra.sh
```

**Lo que crea:**
- 2 instancias EC2 (node01 para Bitcoin, web01 para dashboard)
- Security Groups con reglas configuradas
- Elastic IPs persistentes
- Volúmenes EBS (1000 GB para blockchain, con DeleteOnTermination: false)
- SSH Key Pair

**Salida:**
- `aws-config.env` - Variables de configuración (NO commitear)
- `aws-infrastructure.txt` - Documentación de la infraestructura

### Gestionar Instancias

Una vez creada la infraestructura, usa `manage-aws-instances.sh`:

```bash
cd aws
./manage-aws-instances.sh [comando]
```

**Comandos disponibles:**

| Comando | Descripción |
|---------|-------------|
| `start` | Inicia las instancias EC2 (stopped → running) |
| `stop` | Detiene las instancias EC2 (running → stopped) |
| `status` | Muestra el estado actual de las instancias |
| `destroy` | Destruye permanentemente toda la infraestructura |
| `help` | Muestra ayuda |

**Ejemplos:**

```bash
# Ver estado de las instancias
./manage-aws-instances.sh status

# Iniciar instancias
./manage-aws-instances.sh start

# Detener instancias (para ahorrar costos)
./manage-aws-instances.sh stop

# Destruir infraestructura completa (¡CUIDADO!)
./manage-aws-instances.sh destroy
```

### Destrucción Completa de Infraestructura

El comando `destroy` realiza una limpieza completa:

1. ✅ Termina las instancias EC2
2. ✅ Libera las Elastic IPs (evita cargos)
3. ✅ Detecta y permite eliminar volúmenes EBS huérfanos
4. ✅ Limpia Security Groups (con reintentos automáticos)
5. ✅ Opcionalmente elimina el Key Pair de AWS

**Importante:**
- Requiere doble confirmación
- Debes escribir "DESTROY" para confirmar
- El archivo local `.pem` NO se elimina automáticamente
- El volumen de 1000 GB de Bitcoin se puede conservar si lo deseas

## Seguridad

⚠️ **IMPORTANTE**: Nunca commitas archivos sensibles al repositorio.

Los siguientes archivos contienen información sensible y están en `.gitignore`:
- `aws-config.env` - Credenciales y configuración
- `aws-infrastructure.txt` - IPs y detalles de infraestructura
- `*.pem` - Claves privadas SSH
- `.env` - Variables de entorno

## Costos AWS

Ten en cuenta los costos de AWS al usar estos scripts:

| Recurso | Costo Estimado | Notas |
|---------|----------------|-------|
| t3.large (node01) | ~$0.08/hora | Solo cuando está running |
| t3.medium (web01) | ~$0.04/hora | Solo cuando está running |
| EBS 1000 GB (gp3) | ~$80/mes | Permanente mientras exista |
| EBS 100 GB (gp3) | ~$8/mes | Permanente mientras exista |
| Elastic IP (en uso) | Gratis | |
| Elastic IP (no asociada) | ~$3.6/mes | ¡Elimínala con destroy! |

**Tip para ahorrar:**
- Usa `stop` en lugar de `destroy` si planeas volver a usar las instancias
- Las instancias stopped NO generan costo de compute, solo de storage
- Ejecuta `destroy` completamente si ya no necesitas la infraestructura

## Contribuir

Este proyecto está en desarrollo activo. Contribuciones son bienvenidas:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nuevo-proveedor`)
3. Commit tus cambios (`git commit -m 'Add: soporte para GCP'`)
4. Push a la rama (`git push origin feature/nuevo-proveedor`)
5. Abre un Pull Request

## Roadmap

Ver [TODO.md](TODO.md) para detalles sobre:
- Próximos proveedores cloud (GCP, Azure, DigitalOcean, etc.)
- Mejoras planeadas
- Features en desarrollo

## Licencia

[Por definir]

## Contacto

[Tu información de contacto o del proyecto peer-observer]

---

**Nota**: Desarrollado inicialmente para gestionar la infraestructura de [peer-observer](https://github.com/0xB10C/peer-observer).
