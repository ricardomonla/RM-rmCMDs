# 🚀 rmConfiguraRedEnDebian.sh

Script **minimalista, interactivo y seguro** para configurar interfaces de red en **Debian 12** usando `systemd-networkd` y `systemd-resolved`.  
Pensado para administradores que necesitan cambiar entre **modo DHCP** y **modo estático** de manera rápida, con control visual y confirmaciones antes de aplicar cambios.

---

## 📦 Características principales

- 🔍 **Detección automática** de interfaces de red (`en*`, `eth*`).
- 🔄 Cambio inmediato entre **DHCP ↔ STATIC**.
- ✏️ Edición de parámetros en modo estático:
  - Dirección IP
  - Servidores DNS
  - Gateway por defecto
- 🎨 **Colores en consola** para distinguir:
  - Configuración actual (magenta)
  - Nueva configuración (verde)
- ✅ La opción **"Aplicar configuración"** solo aparece si hubo cambios.
- ⚡ Aplica cambios de manera segura:
  - Recarga `systemd-networkd`
  - Recarga `systemd-resolved`
- 🧹 Verificación y confirmación antes de sobrescribir archivos de red.

---

## ▶️ Ejecución rápida

Descarga y ejecuta el script directamente con:

```bash
rmCMD=rmConfiguraRedEnDebian.sh && \
bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmConfiguraRedEnDebian/${rmCMD})"
````

---

## 📋 Requisitos

* Debian 12 (o cualquier distro basada en `systemd-networkd`).
* Usuario con permisos de `root` o `sudo`.
* Conexión a internet para la primera descarga.

---

## ⚙️ Funcionamiento básico

1. El script detecta automáticamente las interfaces de red.
2. Muestra un **menú interactivo** con opciones:

   * Seleccionar interfaz.
   * Cambiar **DHCP ↔ STATIC**.
   * Editar parámetros (IP, DNS, Gateway).
   * Vista comparativa (actual vs nueva).
   * Aplicar configuración.
   * Salir sin cambios.
3. Los cambios se guardan en `/etc/systemd/network/10-<iface>.network`.
4. El script recarga los servicios de red:

   * `systemd-networkd`
   * `systemd-resolved`

---

## 🖥️ Ejemplo de uso

```bash
sudo ./rmConfiguraRedEnDebian.sh
```

1. Selecciona la interfaz de red (ej: `ens18`).
2. Cambia el modo de **DHCP** a **STATIC**.
3. Ingresa:

   * IP → `192.168.1.50/24`
   * Gateway → `192.168.1.1`
   * DNS → `8.8.8.8 1.1.1.1`
4. Verás una comparativa:

```
Config. actual   → [DHCP] 192.168.1.120
Nueva config.    → [STATIC] 192.168.1.50
```

5. Selecciona **Aplicar configuración** → el script recarga servicios y aplica los cambios.

---

## 📂 Archivos modificados

* `/etc/systemd/network/10-<iface>.network` → configuración principal de la interfaz.
* Tabla de rutas → actualización de gateway.

---

## 🎨 Estética y usabilidad

* ✅ Verde → configuración nueva.
* 🟣 Magenta → configuración actual.
* ⚠️ Amarillo → advertencias / confirmaciones.
* ❌ Rojo → errores o acciones canceladas.

---

## 🧑‍💻 Autor

**Lic. Ricardo MONLA**
🔗 [GitHub](https://github.com/ricardomonla)

---

## 📌 Versionado

* **v250924-2000** → versión actual, estable y funcional para entornos básicos de red en servidores Debian 12.

---

