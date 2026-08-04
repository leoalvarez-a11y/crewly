# Plan de adopcion de Crewly: Windows y VPS

Estado del documento: aprobado como plan; ejecucion pendiente.

Fecha de corte: 2026-08-04.

Upstream: `https://github.com/stevehuang0115/crewly.git`.

Baseline inspeccionado: `a11a964fbef818f2fc3c98402f501f3e5843918b` (`main`).

Rama de planeacion: `plan/crewly-adoption-windows-vps`.

## 1. Objetivo y limite de alcance

Adoptar el proyecto upstream completo, sin eliminar componentes ni dependencias, y agregar de forma aditiva, reversible y probada solamente:

1. seleccion del modelo menos costoso suficientemente capaz;
2. proveedor, runtime y modelo seleccionables por agente;
3. Memory Layer como fuente adicional, sin sustituir memoria ni Wiki nativas;
4. operacion reproducible en Windows y VPS.

Queda expresamente fuera de alcance portar cualquier otra infraestructura de CDNTeams. BOS no se integrara, modificara ni desplegara hasta que una tarea fixture haya terminado con respuesta final visible tanto en Windows/WSL2 como en VPS.

## 2. Invariantes obligatorios

- No eliminar archivos, paquetes, dependencias, servicios, endpoints, rutas, tablas, migraciones, fallbacks ni capacidades de Crewly.
- No desactivar permanentemente cloud, relay, mobile relay, Slack, WhatsApp, schedulers, reconciliadores, memoria, Wiki ni backup/restore. Una capacidad puede quedar sin configurar, pero no suprimida.
- Antes de cambiar una pieza se deben rastrear sus productores, consumidores, persistencia, configuracion, pruebas y proposito. La ausencia de uso en una busqueda superficial no autoriza eliminarla.
- Toda adaptacion debe estar detras de configuracion explicita, tener valor predeterminado compatible con upstream, poder revertirse y contar con prueba co-localizada segun `CLAUDE.md`.
- La seleccion manual siempre prevalece sobre la automatica.
- No se registran secretos. Se registran identificadores no sensibles, decisiones, resultado, tokens y costo cuando existan.
- `REMOVED_COMPONENTS` debe ser `NONE`. Si la auditoria detecta una eliminacion o una regresion, el release queda bloqueado.
- Windows y VPS usan el mismo fork y commit, pero nunca comparten directamente SQLite, `CREWLY_HOME`, sesiones, archivos de runtime, logs o credenciales.

## 3. Evidencia inicial del baseline

La siguiente tabla distingue presencia en codigo de capacidad realmente aceptada. Ninguna fila marcada como “por probar” debe presentarse como soporte operativo.

| Area | Evidencia encontrada en baseline | Estado inicial |
| --- | --- | --- |
| Runtimes por miembro | `TeamMember.runtimeType` admite Claude Code, Gemini CLI, Codex CLI y Crewly Agent; existe factory/adapters de runtime. | Presente en codigo; falta fixture real por runtime y SO. |
| Modelo por miembro | `TeamMember.modelId` existe para `crewly-agent`; `ModelManager` soporta Anthropic, OpenAI, Google, DeepSeek y Ollama. | Parcial: no equivale aun a proveedor/modelo uniforme para todos los runtimes. |
| Presupuesto | Existe `TeamBudget` por equipo con tokens diarios y USD mensuales. | Parcial: falta presupuesto por agente y su enforcement probado. |
| Telemetria | Existe parser de tokens/costo/modelo para salidas de Claude, Gemini y Codex. | Presente en codigo; exactitud y valores ausentes deben probarse. |
| Memoria y Wiki nativas | Existen servicios, controladores, prompts y skills separados para memoria y Wiki. | Deben preservarse y cubrirse con regresion. |
| Backup/restore | Existe archivo portable de workspace, backup online de `chat.db`, exclusion de secretos/runtime, preview, checksums, snapshot pre-restore y rollback. | Presente en codigo; falta ejercicio real en ambos entornos. |
| Cloud/relay/movil | Existen Cloud Sync, descubrimiento de dispositivos, relay movil y skills de comunicacion remota. | Presente en codigo; no demuestra por si solo equipos distribuidos E2E. |
| Multi-maquina | Hay mensajes y servicios para dispositivos, relay y operacion remota; parte de la arquitectura depende del servicio cloud separado. | `UNVERIFIED` hasta prueba real Windows-VPS. |
| Despliegue | Hay Docker Compose, PM2, health endpoints y documentacion de logs/rotacion/backup. | Reutilizar; validar y corregir solo de forma aditiva. |
| Autenticacion | Middleware JWT falla cerrado en produccion si falta `CREWLY_JWT_SECRET`. | API protegible; falta probar cobertura del dashboard completo y TLS externo. |
| Windows | Upstream declara soporte y usa `node-pty`; las skills son Bash. | Por probar primero en Windows nativo. |

Hallazgo local no invasivo al 2026-08-04:

- Windows tiene Node.js `v20.11.1`, npm `10.2.4`, Git `2.54.0.windows.1`, Codex CLI `0.145.0`, Claude Code `2.1.178` y Docker `29.6.2`.
- `gemini` y `pm2` no estan instalados en PATH.
- WSL2 esta disponible, pero solo aparece la distribucion `docker-desktop`; no hay aun una distribucion Linux de usuario validada para Crewly.
- Esta inspeccion no instala dependencias, no inicia Crewly y no constituye una prueba de compatibilidad.

## 4. Estrategia de ramas y preservacion de upstream

1. Crear un fork propio y configurar:
   - `upstream`: repositorio oficial;
   - `origin`: fork propio.
2. Etiquetar el baseline adoptado como `crewly-upstream-a11a964f` o equivalente inmutable.
3. Crear una rama de integracion desde el baseline. No desarrollar sobre `main`.
4. Mantener cada adaptacion en commits pequenos y revertibles, sin reescritura de historia ni force-push.
5. Antes y despues de cada hito producir:
   - SHA de `HEAD`;
   - `git diff --name-status <baseline>...HEAD`;
   - manifiesto de archivos upstream;
   - auditoria de dependencias;
   - lista de servicios/rutas/features conservados;
   - suite de regresion.
6. El gate de preservacion falla ante cualquier estado `D` en el diff, dependencia removida, endpoint desregistrado o capacidad desactivada sin reemplazo compatible y aprobacion expresa.

## 5. Fase 0: orientacion y mapa de consumidores

Antes de implementar:

1. Leer completos `AGENTS.md`, `CLAUDE.md`, las especificaciones relevantes y la documentacion de despliegue.
2. Levantar un mapa verificable de:
   - modelos `Team`, `TeamMember`, configuracion de runtime/modelo y migraciones;
   - creacion, reanudacion y terminacion de sesiones PTY;
   - scripts de runtime para Claude, Codex, Gemini y Crewly Agent;
   - memoria nativa, Wiki, prompts, skills y almacenamiento;
   - cloud sync, relay, mobile relay, chat remoto y skills remotas;
   - schedulers, reconciliadores y health watchdogs;
   - backup, restore, rollback y exclusiones de secretos/sesiones;
   - autenticacion de API, WebSocket y assets del dashboard;
   - almacenamiento local, SQLite y `CREWLY_HOME`.
3. Para cada capacidad remota clasificar la evidencia como:
   - `IMPLEMENTED_AND_E2E_PROVEN`;
   - `IMPLEMENTED_NOT_E2E_PROVEN`;
   - `DESIGN_ONLY`;
   - `NOT_PRESENT`.
4. No habilitar modo distribuido hasta demostrar delegacion, progreso, respuesta final, reconexion e identidad entre dos maquinas reales.

Entregable: `docs/adoption/00-baseline-capability-audit.md` con referencias de archivo/linea, comandos, salidas sanitizadas y conclusion por capacidad.

## 6. Fase 1: baseline reproducible en Windows

### 6.1 Windows nativo, siempre primero

1. Trabajar en un proyecto fixture nuevo y no productivo.
2. Fijar las versiones de Node.js, npm y CLIs usadas.
3. Instalar el checkout del fork sin eliminar dependencias opcionales ni ignorar fallos de addons nativos.
4. Validar expresamente:
   - compilacion e instalacion de `node-pty`, `better-sqlite3` y `sqlite-vec`;
   - shell elegido y ejecucion de skills Bash;
   - separadores y rutas con espacios;
   - variables de entorno y redaccion de secretos;
   - senales, Ctrl+C, terminacion y arboles de procesos hijos;
   - reinicio y limpieza de sesiones;
   - Claude, Codex y Gemini con `--version` y una tarea fixture no destructiva;
   - apertura del dashboard desde navegador Windows;
   - WebSocket/PTY en vivo y respuesta final persistida.
5. Guardar evidencia en `artifacts/adoption/windows-native/<run-id>/`, excluida de Git cuando contenga logs locales.

### 6.2 Criterio objetivo para usar WSL2

Windows nativo solo se descarta si existe una incompatibilidad estructural reproducible, por ejemplo:

- una skill Bash esencial no puede ejecutarse correctamente;
- `node-pty` no compila o pierde control de procesos tras intentos documentados;
- las semanticas de senales/sesiones impiden completar el fixture;
- un runtime soportado no puede operar sin una capa Linux.

Antes de decidir se debe registrar error exacto, caso minimo, alternativas intentadas y riesgo. Si se activa WSL2:

- instalar una distribucion Linux de usuario soportada;
- mantener repositorio y `CREWLY_HOME` dentro del filesystem Linux, no en `/mnt/c`, salvo prueba que justifique lo contrario;
- publicar el dashboard en una direccion alcanzable desde el navegador de Windows sin exponerlo a la red publica;
- documentar comandos de inicio, parada, logs y acceso desde Windows;
- declarar `WINDOWS_OFFICIAL_RUNTIME: WSL2` solo despues del fixture completo.

Gate W1: dashboard visible en Windows y equipo Codex completa una tarea con respuesta final visible y persistida.

## 7. Fase 2: configuracion aditiva por agente

Extender el esquema existente, conservando compatibilidad con equipos antiguos. El contrato objetivo por agente es:

```yaml
execution:
  runtime: codex-cli
  provider: openai
  model: <provider-model-id>
  capabilityClass: standard
  selectionMode: manual | automatic
  fallback:
    enabled: true
    targets: []
  budget:
    maxTokensPerTask: null
    maxUsdPerTask: null
  memoryLayer:
    enabled: false
```

Reglas:

- Campos nuevos opcionales y defaults compatibles con el comportamiento actual.
- No reinterpretar silenciosamente `runtimeType` o `modelId` existentes.
- Separar runtime (proceso que ejecuta) de proveedor/modelo (motor solicitado).
- Validar combinaciones soportadas y devolver error explicito; no caer silenciosamente a Claude.
- Mantener el fallback nativo como opcion compatible, pero registrar cualquier uso.
- Secretos se resuelven por entorno y nunca se guardan en plantillas exportables.
- UI, API, persistencia, import/export, backup/restore y migracion deben compartir el mismo contrato.
- El presupuesto por equipo existente se conserva; el presupuesto por agente agrega un limite mas estricto, no lo sustituye.

Pruebas minimas:

- migracion desde un equipo del baseline;
- round-trip API/UI/almacenamiento/export/import;
- matriz de runtime/proveedor/modelo valida e invalida;
- defaults de datos legacy;
- enforcement de presupuesto;
- mismas fixtures en Windows/WSL2 y Linux VPS.

## 8. Fase 3: politica del modelo menos costoso suficientemente capaz

Agregar un selector compatible con la seleccion nativa, no reemplazar el `ModelManager` ni los adapters existentes.

### 8.1 Catalogo versionado

Mantener configuracion no secreta con:

- proveedor, modelo y runtime compatible;
- clase de capacidad: `basic`, `standard`, `advanced`, `frontier`;
- capacidades requeridas: contexto, herramientas, vision, razonamiento o codigo;
- precio de entrada/salida con fuente y fecha de vigencia;
- disponibilidad por entorno;
- limites y estado habilitado.

Los precios nunca se suponen actuales: se actualizan en un commit revisable y se registra la version del catalogo usada en cada decision.

### 8.2 Algoritmo

1. Si hay seleccion manual valida, usarla y registrar `reason=manual_override`.
2. Si es automatica, derivar requisitos de la clase de capacidad declarada, no del contenido secreto de la tarea.
3. Filtrar modelos incompatibles, no disponibles o fuera de presupuesto.
4. Ordenar candidatos suficientes por costo estimado y criterio estable de desempate.
5. Ejecutar el candidato mas barato.
6. Escalar solo despues de un fallo clasificado y permitido: capacidad insuficiente, limite de contexto, rate limit, indisponibilidad o timeout.
7. No escalar por salida subjetivamente “mejorable” sin un gate objetivo.

### 8.3 Recibo de ejecucion

Cada intento debe registrar, sin secretos:

- modo y razon de seleccion;
- clase y requisitos;
- catalogo/precios usados;
- proveedor, runtime y modelo solicitados;
- proveedor, runtime y modelo ejecutados;
- fallback/escalamiento y fallo clasificado;
- tokens de entrada/salida/total o `null`/`No disponible`;
- costo o `null`/`No disponible`;
- presupuesto antes/despues;
- resultado y correlacion de tarea/agente.

Gate M1: pruebas deterministas demuestran prioridad manual, candidato automatico mas barato, rechazo de insuficientes y escalamiento solo por fallos clasificados.

## 9. Fase 4: adaptador Memory Layer

Memory Layer se agrega como fuente secundaria. La memoria y Wiki nativas siguen habilitadas y con sus rutas, skills, APIs y datos intactos.

Flujo por tarea:

1. comprobar `memoryLayer.enabled` para el agente;
2. construir consulta minima desde objetivo, tarea y proyecto;
3. pedir solo los fragmentos necesarios;
4. redactar secretos antes de incluir contexto o logs;
5. inyectar contexto delimitado con referencias de origen;
6. registrar latencia, referencias y resultado, no contenido sensible;
7. ante timeout, error o ausencia, continuar con memoria/Wiki nativas y marcar fallo no bloqueante.

Requisitos:

- interfaz de adaptador desacoplada de transporte y proveedor;
- configuracion/credenciales separadas por entorno;
- limites de tiempo, tamano y numero de referencias;
- proteccion contra prompt injection en contenido recuperado;
- cache opcional local por entorno, nunca compartida como SQLite;
- boton/flag por agente y default desactivado hasta configurar;
- prueba de que apagar Memory Layer restaura el comportamiento nativo.

Gate ML1: el fixture recibe una referencia comprobable de Memory Layer; el mismo fixture termina si Memory Layer falla; memoria y Wiki nativas conservan sus pruebas.

## 10. Fase 5: persistencia, exportacion y sincronizacion segura

No se montara una misma carpeta, volumen, SQLite o sesion entre Windows y VPS.

Versionar o exportar unicamente:

- plantillas de equipos;
- configuracion no secreta de agentes;
- runtime/proveedor/modelo por agente;
- politica y catalogo de modelos;
- adaptador/configuracion no secreta de Memory Layer;
- skills propios;
- runbooks y fixtures.

Mantener separados:

- secretos y credenciales;
- `CREWLY_HOME`;
- bases locales y sidecars SQLite;
- identidad de dispositivo;
- sesiones y procesos;
- logs;
- rutas absolutas;
- estados en vuelo.

Metodo inicial obligatorio: dos instancias independientes, mismo commit y configuracion versionada por Git; proyectos sincronizados por Git. Backup portable solo se usa mediante create/preview/restore y nunca como almacenamiento activo compartido.

El modo multi-node nativo solo reemplazara este metodo si pasa el gate MN1:

- Windows y VPS autenticados como dispositivos distintos;
- conexion TLS y relay autenticado;
- delegacion remota a un agente concreto;
- progreso y respuesta final retornan al origen;
- reconexion no duplica la tarea;
- memoria/equipos sincronizan exactamente segun el contrato documentado;
- no se comparten archivos locales;
- prueba repetible con capturas, IDs y logs sanitizados.

## 11. Fase 6: despliegue minimo al VPS

No tocar servicios productivos antes del inventario y la aprobacion del plan de puertos/proxy.

### 11.1 Descubrimiento de solo lectura

Registrar:

- distribucion y version de SO/kernel;
- CPU, RAM, disco y limites;
- Node.js, npm, Git, Docker y PM2;
- usuarios/grupos y posibilidad de usuario dedicado no-root;
- puertos ocupados y listeners;
- firewall;
- process manager existente;
- reverse proxy, dominios, certificados y autenticacion existentes;
- ubicacion de datos, logs y backups;
- conflictos con servicios productivos.

No registrar valores de secretos.

### 11.2 Despliegue

1. Crear usuario dedicado no-root cuando sea posible.
2. Instalar exactamente el mismo fork y SHA aceptado en Windows.
3. Fijar dependencias con lockfile y verificar checksums/build/tests.
4. Persistir `CREWLY_HOME` en una ruta dedicada con permisos minimos.
5. Elegir el mecanismo ya existente mas adecuado:
   - PM2 si el host ya lo usa y el PTY necesita acceso directo al host;
   - Docker Compose si aislamiento, volumenes y runtimes funcionan en la prueba.
6. Configurar inicio automatico usando el mecanismo elegido.
7. Configurar logs y rotacion reutilizando PM2/Docker/system facilities.
8. Mantener Crewly escuchando en loopback o red privada detras del proxy.
9. Exponer dashboard solo por HTTPS y autenticacion; verificar API, WebSocket y assets.
10. Configurar health externo y alerta sin incluir secretos.

### 11.3 Runbook obligatorio

Crear `docs/adoption/vps-runbook.md` con comandos exactos e idempotentes para:

- install;
- deploy;
- start;
- stop;
- restart;
- status;
- logs;
- backup;
- restore preview;
- restore;
- update;
- rollback.

Cada deploy debe capturar SHA anterior, backup verificado y comando de rollback antes de mutar. No usar root salvo necesidad explicada. No abrir puertos directos del dashboard.

Gate V1: reinicio real del VPS conserva equipos, tareas y memoria; autostart, health, logs, backup, restore y rollback quedan probados.

## 12. Matriz de aceptacion y evidencia

| # | Criterio | Evidencia obligatoria |
| --- | --- | --- |
| 1 | Crewly funciona en Windows nativo o WSL2 | SO/runtime, comandos, build/tests, health y captura del dashboard. |
| 2 | Dashboard abre desde Windows | URL local, HTTP/WebSocket correctos y captura con timestamp. |
| 3 | Equipo Codex termina tarea | ID de equipo/tarea, transcript sanitizado y respuesta final visible. |
| 4 | Config por agente se respeta | Recibo solicitado vs ejecutado para cada agente. |
| 5 | Selector elige modelo economico suficiente | Catalogo fijado, candidatos, decision y prueba determinista. |
| 6 | Memory Layer aporta contexto | Referencia recuperada y efecto observable en fixture. |
| 7 | Reinicio conserva estado | IDs y conteos antes/despues, memoria consultable. |
| 8 | Mismo commit llega al VPS | SHA exacto en ambos hosts. |
| 9 | Autostart VPS | Evidencia tras reboot, no solo restart de proceso. |
| 10 | Dashboard remoto seguro | HTTPS valido, auth requerida, WebSocket funcional, puerto interno no publico. |
| 11 | Fixture VPS termina | ID, transcript y respuesta final visible. |
| 12 | Operacion VPS funciona | logs, health, backup, preview, restore y rollback ejercitados. |
| 13 | No se comparte estado local | Rutas/volumenes distintos e identidades de dispositivo distintas. |
| 14 | No se elimino Crewly | diff/manifiesto/dependencias/regresion; `REMOVED_COMPONENTS: NONE`. |
| 15 | BOS sigue intacto | Ningun checkout, servicio o despliegue BOS usado/modificado. |

Una prueba simulada o un test unitario no sustituye el fixture real. Los fixtures no usan repositorios productivos ni datos sensibles.

## 13. Gates de avance

- `G0 Baseline`: auditoria de consumidores y suite baseline documentadas.
- `G1 Windows`: fixture local con respuesta final visible.
- `G2 Config`: configuracion y recibos por agente probados.
- `G3 Model policy`: seleccion y escalamiento deterministas probados.
- `G4 Memory Layer`: aporte y fallo no bloqueante probados.
- `G5 VPS preflight`: inventario, conflictos, TLS/auth y rollback aprobados.
- `G6 VPS`: mismo commit, autostart y fixture con respuesta final.
- `G7 Recovery`: backup/restore/restart/rollback reales.
- `G8 Preservation`: regresiones aceptables y componentes removidos igual a ninguno.
- `G9 BOS`: solo despues de G1-G8; requiere una autorizacion separada.

## 14. Seguridad y reglas de parada

- No usar repositorios productivos en pruebas.
- No usar force-push ni operaciones Git destructivas.
- No hacer cambios destructivos en VPS.
- No abrir puertos sin autenticacion y TLS.
- No mostrar, guardar en Git ni copiar secretos entre entornos.
- No ejecutar como root salvo necesidad documentada.
- No restaurar sin preview, backup previo y rollback listo.
- Detenerse ante conflicto con servicio productivo, destino ambiguo, credencial no autorizada, eliminacion de componente o imposibilidad de producir evidencia.

## 15. Formato de entrega final

La entrega de implementacion debe completar exactamente este bloque con valores comprobados; usar `UNVERIFIED`, `NOT_CONFIGURED`, `NOT_APPLICABLE` o `No disponible` cuando corresponda, nunca inferencias:

```text
CREWLY_BASELINE:
CREWLY_HEAD:
BRANCH:
WINDOWS_NATIVE_STATUS:
WSL2_STATUS:
WINDOWS_OFFICIAL_RUNTIME:
VPS_OS:
VPS_DEPLOYMENT:
VPS_PROCESS_MANAGER:
VPS_URL:
TLS:
AUTH:
HEALTH:
BACKUP:
RESTORE:
ROLLBACK:
PER_AGENT_PROVIDER:
PER_AGENT_RUNTIME:
PER_AGENT_MODEL:
MODEL_POLICY:
MEMORY_LAYER:
NATIVE_MEMORY_PRESERVED:
MULTI_NODE_NATIVE_SUPPORT:
WINDOWS_VPS_SYNC_METHOD:
LOCAL_FIXTURE_RESULT:
VPS_FIXTURE_RESULT:
FINAL_RESPONSE_LOCAL:
FINAL_RESPONSE_VPS:
REGRESSIONS:
REMOVED_COMPONENTS: NONE
COMMITS:
PUSH:
RECOMMENDATION:
```

## 16. Estado al aprobar este plan

```text
CREWLY_BASELINE: a11a964fbef818f2fc3c98402f501f3e5843918b
CREWLY_HEAD: a11a964fbef818f2fc3c98402f501f3e5843918b
BRANCH: plan/crewly-adoption-windows-vps
WINDOWS_NATIVE_STATUS: PREFLIGHT_ONLY
WSL2_STATUS: WSL2_ENGINE_AVAILABLE; USER_DISTRO_NOT_VALIDATED
WINDOWS_OFFICIAL_RUNTIME: UNDECIDED_PENDING_FIXTURE
VPS_OS: UNVERIFIED
VPS_DEPLOYMENT: NOT_STARTED
VPS_PROCESS_MANAGER: UNDECIDED_PENDING_INVENTORY
VPS_URL: NOT_CONFIGURED
TLS: NOT_CONFIGURED
AUTH: NOT_CONFIGURED
HEALTH: NOT_RUN
BACKUP: CODE_PRESENT; NOT_EXERCISED
RESTORE: CODE_PRESENT; NOT_EXERCISED
ROLLBACK: CODE_PRESENT_FOR_RESTORE; DEPLOY_ROLLBACK_NOT_EXERCISED
PER_AGENT_PROVIDER: PARTIAL_IN_BASELINE
PER_AGENT_RUNTIME: PRESENT_IN_BASELINE; NOT_FIXTURE_PROVEN
PER_AGENT_MODEL: PARTIAL_IN_BASELINE; CREWLY_AGENT_MODEL_ID
MODEL_POLICY: NOT_IMPLEMENTED_OR_PROVEN
MEMORY_LAYER: NOT_INTEGRATED
NATIVE_MEMORY_PRESERVED: YES_AT_BASELINE
MULTI_NODE_NATIVE_SUPPORT: UNVERIFIED
WINDOWS_VPS_SYNC_METHOD: PLANNED_GIT_PLUS_INDEPENDENT_RUNTIME_STATE
LOCAL_FIXTURE_RESULT: NOT_RUN
VPS_FIXTURE_RESULT: NOT_RUN
FINAL_RESPONSE_LOCAL: NOT_AVAILABLE
FINAL_RESPONSE_VPS: NOT_AVAILABLE
REGRESSIONS: NOT_ASSESSED
REMOVED_COMPONENTS: NONE
COMMITS: NONE
PUSH: NOT_PERFORMED
RECOMMENDATION: EXECUTE G0 THEN WINDOWS_NATIVE G1; DO NOT INTEGRATE BOS
```
