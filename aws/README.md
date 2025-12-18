# AWS Infrastructure Scripts

Scripts para gestionar infraestructura EC2 en AWS de forma automatizada.

## Scripts Disponibles

### 1. create-aws-infra.sh

Crea toda la infraestructura necesaria en AWS.

**Uso:**
```bash
./create-aws-infra.sh
```

**Configuración (editar el script):**
```bash
AWS_REGION="us-east-1"          # Región de AWS
KEY_NAME="peer-observer-key"    # Nombre del key pair
INSTANCE_TYPE_NODE="t3.large"   # Tipo para nodo Bitcoin (2 vCPU, 8 GB RAM)
INSTANCE_TYPE_WEB="t3.medium"   # Tipo para webserver (2 vCPU, 4 GB RAM)
BITCOIN_VOLUME_SIZE=1000        # GB para blockchain
WEB_VOLUME_SIZE=100             # GB para webserver
```

**Recursos que crea:**
- ✅ Security Group para nodes (Bitcoin)
  - Puerto 22 (SSH) desde tu IP
  - Puerto 8333 (Bitcoin P2P) abierto
  - Puerto 51820 (WireGuard) abierto
- ✅ Security Group para webserver
  - Puerto 22 (SSH) desde tu IP
  - Puerto 80 (HTTP) abierto
  - Puerto 443 (HTTPS) abierto
  - Puerto 51820 (WireGuard) abierto
- ✅ Instancia EC2 node01 (Bitcoin)
  - 50 GB volumen raíz (gp3, DeleteOnTermination: true)
  - 1000 GB volumen adicional (gp3, DeleteOnTermination: false)
- ✅ Instancia EC2 web01 (Dashboard)
  - 100 GB volumen raíz (gp3, DeleteOnTermination: true)
- ✅ 2 Elastic IPs persistentes
- ✅ SSH Key Pair (o usar uno existente)

**Archivos generados:**
- `aws-config.env` - Variables de configuración (⚠️ NO COMMITEAR)
- `aws-infrastructure.txt` - Documentación de la infraestructura

### 2. manage-aws-instances.sh

Gestiona el ciclo de vida de las instancias creadas.

**Requisito:**
Debe existir el archivo `aws-config.env` generado por `create-aws-infra.sh`

**Comandos:**

#### Status - Ver estado de las instancias
```bash
./manage-aws-instances.sh status
```

Muestra:
- Estado de cada instancia (running/stopped/terminated)
- IPs públicas
- Comandos SSH para conectar

#### Start - Iniciar instancias
```bash
./manage-aws-instances.sh start
```

- Inicia las instancias stopped
- Espera a que estén running
- Obtiene las nuevas IPs públicas
- Actualiza `aws-config.env` con las nuevas IPs

**Nota:** Las IPs públicas cambian cada vez que inicias una instancia stopped (a menos que uses Elastic IPs).

#### Stop - Detener instancias
```bash
./manage-aws-instances.sh stop
```

- Detiene las instancias running
- Espera a que estén stopped
- Las instancias stopped NO generan costo de compute (solo storage)

**Ideal para:** Ahorrar costos cuando no estás usando las instancias pero quieres mantenerlas.

#### Destroy - Destruir infraestructura
```bash
./manage-aws-instances.sh destroy
```

**⚠️ CUIDADO:** Esta operación es PERMANENTE e IRREVERSIBLE.

**Proceso:**
1. Solicita confirmación (debes escribir "yes")
2. Solicita segunda confirmación (debes escribir "DESTROY")
3. Termina las instancias EC2
4. **Libera las Elastic IPs automáticamente** (evita cargos)
5. **Detecta volúmenes EBS huérfanos** y pregunta si eliminarlos
6. Pregunta si deseas eliminar Security Groups y Key Pair
7. **Limpia Security Groups con sistema de reintentos**

**Recursos eliminados:**
- ✅ Instancias EC2 (terminadas permanentemente)
- ✅ Elastic IPs (liberadas automáticamente)
- ✅ Volúmenes EBS huérfanos (opcional, te pregunta)
- ✅ Security Groups (opcional, con reintentos)
- ✅ Key Pair en AWS (opcional)

**NO se elimina:**
- ❌ Archivo local `~/.ssh/{KEY_NAME}.pem` (debes eliminarlo manualmente)
- ❌ Archivos `aws-config.env` y `aws-infrastructure.txt` (debes eliminarlos manualmente)

## Flujo de Trabajo Típico

### Setup Inicial
```bash
# 1. Crear infraestructura
./create-aws-infra.sh

# 2. Verificar que todo se creó correctamente
./manage-aws-instances.sh status

# 3. Conectar por SSH
ssh -i ~/.ssh/peer-observer-key.pem ubuntu@<NODE_IP>
ssh -i ~/.ssh/peer-observer-key.pem ubuntu@<WEB_IP>
```

### Uso Diario
```bash
# Iniciar instancias
./manage-aws-instances.sh start

# Trabajar con las instancias...

# Detener para ahorrar costos
./manage-aws-instances.sh stop
```

### Limpieza Final
```bash
# Destruir todo
./manage-aws-instances.sh destroy

# Eliminar archivos locales sensibles
rm aws-config.env aws-infrastructure.txt
rm ~/.ssh/peer-observer-key.pem  # Si no lo necesitas más
```

## Costos Estimados

| Recurso | Running | Stopped | Notas |
|---------|---------|---------|-------|
| t3.large (node01) | ~$0.08/h (~$58/mes) | $0 | Solo compute cuando está running |
| t3.medium (web01) | ~$0.04/h (~$29/mes) | $0 | Solo compute cuando está running |
| EBS 1000 GB (gp3) | ~$80/mes | ~$80/mes | Permanente |
| EBS 50 GB (gp3) | ~$4/mes | ~$4/mes | Permanente |
| EBS 100 GB (gp3) | ~$8/mes | ~$8/mes | Permanente |
| Elastic IP (asociada) | $0 | $0 | Gratis si está asociada |
| Elastic IP (libre) | ~$3.6/mes | ~$3.6/mes | ¡Eliminar con destroy! |

**Total aprox:**
- Running: ~$180/mes (con todo running 24/7)
- Stopped: ~$92/mes (solo storage)

**Estrategias de ahorro:**
1. Usar `stop` cuando no uses las instancias → Ahorro ~50%
2. Reducir tamaño del volumen Bitcoin si no necesitas toda la blockchain
3. Usar t3 instances con credits para burst performance
4. Considerar Reserved Instances si uso es 24/7 durante 1-3 años

## Solución de Problemas

### Error: "Could not delete security group"
**Causa:** Las network interfaces aún están siendo liberadas

**Solución:**
- El script intenta 3 veces con 5 segundos entre intentos
- Si sigue fallando, espera 5-10 minutos más y elimina manualmente:
  ```bash
  aws ec2 delete-security-group --region us-east-1 --group-id sg-xxxxx
  ```

### Error: "Elastic IP could not be released"
**Causa:** La EIP todavía está asociada a la instancia

**Solución:**
- Desasociar manualmente primero:
  ```bash
  aws ec2 disassociate-address --region us-east-1 --association-id eipassoc-xxxxx
  aws ec2 release-address --region us-east-1 --allocation-id eipalloc-xxxxx
  ```

### Las IPs públicas cambian después de stop/start
**Causa:** AWS reasigna IPs públicas dinámicas al reiniciar

**Soluciones:**
- Usar Elastic IPs (el script `create-aws-infra.sh` ya las configura)
- Verificar que las Elastic IPs estén correctamente asociadas

### No puedo conectar por SSH
**Verificar:**
1. La instancia está en estado "running"
2. Security Group permite SSH (puerto 22) desde tu IP
3. Tienes el archivo .pem correcto
4. Permisos del archivo .pem son 400 (`chmod 400 ~/.ssh/peer-observer-key.pem`)
5. Usas el usuario correcto (ubuntu para Ubuntu AMIs)

```bash
# Verificar estado
./manage-aws-instances.sh status

# Verificar permisos
ls -l ~/.ssh/peer-observer-key.pem  # Debe mostrar -r--------

# Corregir permisos si es necesario
chmod 400 ~/.ssh/peer-observer-key.pem
```

## Seguridad

**⚠️ NUNCA commitear estos archivos:**
- `aws-config.env` - Contiene IDs y configuración sensible
- `aws-infrastructure.txt` - Contiene IPs y detalles públicos
- `*.pem` - Claves privadas SSH
- `*.bak` - Backups que pueden contener info sensible

**Buenas prácticas:**
- Rotar las SSH keys periódicamente
- Usar MFA en tu cuenta AWS
- Limitar reglas de Security Groups a IPs específicas (no 0.0.0.0/0 para SSH)
- Habilitar CloudTrail para auditoría
- Revisar AWS Cost Explorer regularmente

## Recursos Adicionales

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [AWS Free Tier](https://aws.amazon.com/free/)

---

Para regresar a la documentación principal: [README.md](../README.md)
