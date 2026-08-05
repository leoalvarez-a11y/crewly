# Guia de uso de Crewly

Crewly coordina proyectos, equipos y agentes con runtimes reales. Esta guia parte de la instalacion local en Ubuntu WSL2 y no reemplaza la Wiki ni la memoria nativas.

## Inicio rapido

1. Inicia Crewly con `scripts/crewly-local-start.sh` desde `/home/zytto/crewly/source`.
2. Abre `http://localhost:8787`.
3. En **Configuracion > General** confirma `Espanol (Mexico)`.
4. En **Configuracion > Proveedores y costos** confirma instalacion y autenticacion.
5. Crea un proyecto, un equipo y miembros con runtime, modelo y rol explicitos.

## Modulos

Las guias `01` a `20` cubren inicio, proyectos, equipos, agentes, proveedores, chat, solicitudes, tareas, terminales, QA, memoria, Wiki, skills, costos, salud, respaldos, nube, Slack, WhatsApp, configuracion y diagnostico. La interfaz incluye **Ayuda** para abrir este indice.

## Seguridad

No pegues tokens en chat, terminales compartidas ni Git. Un binario instalado no demuestra autenticacion: ejecuta una tarea real. Conserva Wiki y memoria nativas; una Memory Layer externa es suplementaria.
