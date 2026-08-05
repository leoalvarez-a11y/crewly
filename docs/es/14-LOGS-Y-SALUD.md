# Logs y salud
## Que es
Diagnostico del backend, agentes y servicios.
## Para que sirve
Ubica errores y confirma disponibilidad local.
## Requisitos
Servicio iniciado y acceso al CREWLY_HOME.
## Como abrirlo
Usa **Salud** o `scripts/crewly-local-logs.sh`.
## Configuracion paso a paso
Consulta health, estado, ultimas lineas y proceso responsable.
## Ejemplo practico
Detecta un CLI ausente del PATH del servicio.
## Como comprobar que funciona
`/health` responde y el PID coincide con el checkout.
## Errores frecuentes
Registrar tokens o copiar logs sin sanitizar.
## Limites y riesgos
Salud HTTP no prueba una tarea de IA.
## Acciones relacionadas
Terminales, Configuracion, Proveedores y Solucion de problemas.
