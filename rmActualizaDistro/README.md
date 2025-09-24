# 🔄 rmActualizaDistro.sh

Script **minimalista e interactivo** para realizar **mantenimiento y actualizaciones del sistema** en **Debian 12**.  
Permite actualizar repositorios, limpiar paquetes innecesarios y reiniciar el servidor si es necesario.

---

## 📦 Características principales

- **Actualizar sistema** (`apt update && apt full-upgrade`).
- **Limpieza de paquetes y caché** (`autoremove && autoclean`).
- **Reiniciar** el sistema de forma controlada.
- Chequeo automático de si es necesario reiniciar (`/var/run/reboot-required`).
- Interfaz con menú interactivo y mensajes en colores.

---

## ▶️ Ejecución rápida

Para descargar y ejecutar el script directamente:

```bash
rmCMD=rmActualizaDistro.sh && \
bash -c "$(curl -fsSL https://github.com/ricardomonla/RM-rmCMDs/rmActualizaDistro/raw/refs/heads/main/${rmCMD})"
````

---

## 📋 Requisitos

* Debian 12 (o similar con `apt`).
* Acceso a usuario con privilegios de `root` o `sudo`.
* Conexión a internet para descargar actualizaciones.

---

## ⚙️ Funcionamiento básico

1. El script muestra un menú con opciones:

   * **1)** Actualizar repositorios y aplicativos.
   * **2)** Limpieza de paquetes y caché.
   * **3)** Reiniciar el sistema.
   * **0)** Salir.

2. Después de ejecutar una actualización, se informa si el sistema requiere reinicio.

3. La opción **Reiniciar** aplica un `reboot` inmediato.

---

## 🧑‍💻 Autor

**Lic. Ricardo MONLA**
🔗 [GitHub](https://github.com/ricardomonla)

---

## ✅ Estado

Versión actual: **v250924-1030**
Estable y funcional para entornos de administración básica de servidores Debian 12.