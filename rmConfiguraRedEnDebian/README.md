# 🚀 rmConfiguraRedEnDebian.sh

Script **minimalista e interactivo** para configurar interfaces de red en **Debian 12** utilizando `systemd-networkd` y `systemd-resolved`.  
Permite cambiar entre **modo DHCP** y **modo estático**, modificar IP, DNS y Gateway, y aplicar los cambios de manera segura.

---

## 📦 Características principales

- Detección automática de interfaces de red (`en*` o `eth*`).
- Cambio de configuración de **DHCP ↔ STATIC** de manera simple.
- Edición de **Dirección IP** y **Servidores DNS** cuando la interfaz está en modo estático.
- Modificación del **Gateway por defecto**.
- Vista comparativa de la configuración actual vs. la nueva (colores verde/magenta).
- La opción **"Aplicar configuración"** solo aparece si hubo cambios.
- Aplica los cambios recargando `systemd-networkd` y `systemd-resolved`.

---

## ▶️ Ejecución rápida

Para descargar y ejecutar el script directamente:

```bash
rmCMD=rmConfiguraRedEnDebian.sh && \
bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmConfiguraRedEnDebian/${rmCMD})"
````

---

## 📋 Requisitos

* Debian 12 (u otra distribución basada en `systemd-networkd`).
* Acceso a usuario con privilegios de `root` o `sudo`.
* Conexión a internet para la descarga inicial.

---

## ⚙️ Funcionamiento básico

1. El script detecta las interfaces de red disponibles.
2. Muestra un **menú interactivo** para:

   * Seleccionar interfaz.
   * Cambiar modo DHCP/STATIC.
   * Editar parámetros en STATIC.
   * Ver comparativa de cambios.
   * Aplicar configuración.
3. Los cambios se guardan en `/etc/systemd/network/10-<iface>.network`.
4. Se reinician los servicios:

   * `systemd-networkd`
   * `systemd-resolved`

---

## 📂 Archivos afectados

* `/etc/systemd/network/10-<iface>.network` → Configuración de la interfaz.
* Tabla de rutas → Actualización de gateway.

---

## 🧑‍💻 Autor

**Lic. Ricardo MONLA**
🔗 [GitHub](https://github.com/ricardomonla)

---

## ✅ Estado

Versión actual: **v250924-1637**
Estable y funcional para entornos de administración básica de red en servidores Debian 12.

---
