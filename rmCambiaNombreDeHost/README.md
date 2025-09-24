# 🖥️ rmCambiaNombreDeHost.sh

Script **minimalista e interactivo** para cambiar el **hostname** en **Debian 12** de forma segura, usando `hostnamectl`.  
Permite modificar el nombre del host, mostrar los cambios antes de aplicarlos y actualizar automáticamente los archivos del sistema.

---

## 📦 Características principales

- Detección del **hostname actual**.
- Definición de un **nuevo hostname**.
- Vista comparativa (verde/magenta) antes de aplicar cambios.
- La opción **"Aplicar configuración"** solo aparece si hubo cambios.
- Actualización automática de:
  - `hostnamectl`
  - `/etc/hostname`
  - `/etc/hosts` (línea `127.0.1.1`)

---

## ▶️ Ejecución rápida

Para descargar y ejecutar el script directamente:

```bash
rmCMD=rmCambiaNombreDeHost.sh && \
bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/raw/refs/heads/main/rmCambiaNombreDeHost/${rmCMD})"
````

---

## 📋 Requisitos

* Debian 12 (u otra distro con `systemd` y `hostnamectl`).
* Acceso a usuario con privilegios de `root` o `sudo`.
* Conexión a internet para la descarga inicial.

---

## ⚙️ Funcionamiento básico

1. El script muestra el **hostname actual**.
2. Permite ingresar un **nuevo nombre de host**.
3. Si hubo cambios, aparece la opción **Aplicar configuración**.
4. Una vez aplicado:

   * Se ejecuta `hostnamectl set-hostname`.
   * Se actualiza `/etc/hostname`.
   * Se actualiza `/etc/hosts` con el nuevo nombre.
5. Se informa el resultado con mensajes en colores.

---

## 📂 Archivos afectados

* `/etc/hostname` → Contiene el nuevo hostname.
* `/etc/hosts` → Línea `127.0.1.1` actualizada al nuevo nombre.

---

## 🧑‍💻 Autor

**Lic. Ricardo MONLA**
🔗 [GitHub](https://github.com/ricardomonla)

---

## ✅ Estado

Versión actual: **v250924-1123**
Estable y funcional para entornos de administración básica de servidores Debian 12.

---
