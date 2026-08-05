# Crewly local en Windows con WSL2

## Uso diario

Haz doble clic en `Crewly.lnk` en el escritorio de Windows. El acceso directo
ejecuta un lanzador oculto que abre Ubuntu WSL2 como `zytto`, inicia el checkout
Linux de Crewly, espera hasta 90 segundos a que el servicio esté saludable y
abre el dashboard en `http://localhost:8787`.

Si Crewly ya está saludable, el lanzador no crea otra instancia: abre el
dashboard existente.

## Detener y consultar logs

- `Detener Crewly.lnk` solicita una parada limpia del supervisor, espera la
  terminación y limpia únicamente procesos y sesiones `crewly_*` pertenecientes
  al checkout operativo.
- `Crewly Logs.lnk` abre una terminal visible con las últimas 100 líneas y las
  sigue durante un máximo de 120 segundos.

Los logs persistentes están en `/home/zytto/.crewly/logs/crewly-local.log`.

## Ubicaciones oficiales

- Distribución: `Ubuntu` en WSL2
- Usuario: `zytto`
- Checkout: `/home/zytto/crewly/source`
- `CREWLY_HOME`: `/home/zytto/.crewly`
- Dashboard: `http://localhost:8787`
- Health: `http://localhost:8787/health`

Crewly no se ejecuta desde `/mnt/c` y estos lanzadores no dependen de
`docker-desktop`.

## Estado y solución de problemas

Para revisar el estado desde Ubuntu:

```bash
/home/zytto/crewly/source/scripts/crewly-local-status.sh
```

Si el acceso directo muestra un error:

1. Abre `Crewly Logs.lnk` y revisa el mensaje más reciente.
2. Confirma que `Ubuntu` aparece con versión 2 mediante `wsl --list --verbose`.
3. Confirma que Node.js es 22 o superior con `node -v` dentro de Ubuntu.
4. Si el build falta después de actualizar el código, ejecuta una sola vez
   `npm ci` y `npm run build` en `/home/zytto/crewly/source`.
5. Consulta también `%LOCALAPPDATA%\Crewly\windows-launcher.log` para errores
   del lanzador de Windows.

El script de inicio no instala dependencias ni recompila en cada ejecución.

## Recrear o actualizar los accesos directos

Ejecuta desde PowerShell, sin privilegios de administrador:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\zytto\Documents\Codex\crewly\source\windows-launcher\Install-CrewlyShortcuts.ps1"
```

El instalador obtiene la ubicación real del escritorio mediante la API de
Windows y actualiza los tres accesos directos de forma idempotente.
