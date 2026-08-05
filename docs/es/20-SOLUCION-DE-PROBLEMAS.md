# Solucion de problemas
## Que es
Procedimiento de diagnostico local.
## Para que sirve
Separa fallos de instalacion, autenticacion, PATH y producto.
## Requisitos
Acceso a estado, logs y un fixture no destructivo.
## Como abrirlo
Desde **Ayuda** o la guia principal.
## Configuracion paso a paso
Verifica usuario, HOME, ruta, version, auth, PTY, health y tarea real.
## Ejemplo practico
Si Codex existe pero no autentica, ejecuta `codex login` una vez y repite tarea.
## Como comprobar que funciona
Una sesion nueva conserva autenticacion y completa el fixture.
## Errores frecuentes
Usar `/mnt/c`, docker-desktop o simular autenticacion.
## Limites y riesgos
No pegues credenciales ni repares fallas baseline no relacionadas.
## Acciones relacionadas
Logs, Salud, Proveedores, Terminales y Respaldos.
