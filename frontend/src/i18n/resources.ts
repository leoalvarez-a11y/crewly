export const DEFAULT_LOCALE = 'es-MX';
export const FALLBACK_LOCALE = 'en-US';
export const LOCALE_STORAGE_KEY = 'crewly.locale';

export const resources = {
  'en-US': { translation: {
    nav: { work: 'WORK', tools: 'TOOLS', system: 'SYSTEM', dashboard: 'Dashboard', projects: 'Projects', teams: 'Teams', missions: 'Missions', chat: 'Chat', wiki: 'Wiki', marketplace: 'Marketplace', triggers: 'Triggers', workItems: 'Work Items', requests: 'Requests', cloud: 'Cloud Portal', usage: 'Usage', security: 'Security', settings: 'Settings', help: 'Help', favorites: 'Favorites', collapse: 'Collapse' },
    settings: { title: 'Settings', subtitle: 'Configure Crewly behavior, providers, roles, and skills', general: 'General', roles: 'Roles', skills: 'Skills', integrations: 'Integrations', apiKeys: 'API Keys', credentials: 'Credentials', system: 'System', providers: 'Providers and costs' },
    help: { title: 'Help', subtitle: 'Step-by-step guides for every visible Crewly module' },
    common: { unavailable: 'Not available', yes: 'Yes', no: 'No' },
  } },
  'es-MX': { translation: {
    nav: { work: 'TRABAJO', tools: 'HERRAMIENTAS', system: 'SISTEMA', dashboard: 'Inicio', projects: 'Proyectos', teams: 'Equipos', missions: 'Misiones', chat: 'Chat', wiki: 'Wiki', marketplace: 'Marketplace', triggers: 'Automatizaciones', workItems: 'Elementos de trabajo', requests: 'Solicitudes', cloud: 'Nube', usage: 'Presupuestos y uso', security: 'Seguridad', settings: 'Configuracion', help: 'Ayuda', favorites: 'Favoritos', collapse: 'Contraer' },
    settings: { title: 'Configuracion', subtitle: 'Configura el comportamiento, proveedores, roles y skills de Crewly', general: 'General', roles: 'Roles', skills: 'Skills', integrations: 'Integraciones', apiKeys: 'Claves API', credentials: 'Credenciales', system: 'Sistema', providers: 'Proveedores y costos' },
    help: { title: 'Ayuda', subtitle: 'Guias paso a paso para cada modulo visible de Crewly' },
    common: { unavailable: 'No disponible', yes: 'Si', no: 'No' },
  } },
} as const;

/** Spanish phrase map used for legacy surfaces while they migrate to keyed translations. */
export const LEGACY_ES_MX_PHRASES: Readonly<Record<string, string>> = {
  Dashboard: 'Inicio', Projects: 'Proyectos', Teams: 'Equipos', Agents: 'Agentes', Tasks: 'Tareas', Requests: 'Solicitudes', Activity: 'Actividad', Memory: 'Memoria', Skills: 'Skills', Budgets: 'Presupuestos', Models: 'Modelos', Settings: 'Configuracion', Approvals: 'Aprobaciones', Escalations: 'Escalaciones', Backups: 'Respaldos', Cloud: 'Nube', Mobile: 'Movil', Health: 'Salud', Terminals: 'Terminales', 'No data available': 'No hay datos disponibles', 'No results found': 'No se encontraron resultados', 'Something went wrong': 'Ocurrio un error', Loading: 'Cargando', Save: 'Guardar', Cancel: 'Cancelar', Create: 'Crear', Delete: 'Eliminar', Edit: 'Editar', Status: 'Estado', Error: 'Error', Success: 'Correcto', Pending: 'Pendiente', Active: 'Activo', Inactive: 'Inactivo', Idle: 'Inactivo', Running: 'En ejecucion', Completed: 'Completado', Blocked: 'Bloqueado', Documentation: 'Documentacion', Usage: 'Uso', Security: 'Seguridad', Triggers: 'Automatizaciones', Missions: 'Misiones', 'Work Items': 'Elementos de trabajo', 'Cloud Portal': 'Nube', Integrations: 'Integraciones', Credentials: 'Credenciales', System: 'Sistema', General: 'General', Roles: 'Roles', Favorites: 'Favoritos', Collapse: 'Contraer', Help: 'Ayuda', WhatsApp: 'WhatsApp', Slack: 'Slack', Wiki: 'Wiki', Marketplace: 'Marketplace', Chat: 'Chat',
  "Welcome back. Here's a summary of your teams and projects.": 'Bienvenido de nuevo. Este es el resumen de tus equipos y proyectos.',
  'Active Projects': 'Proyectos activos', 'Running Agents': 'Agentes en ejecucion', 'In Progress': 'En progreso', Secure: 'Seguro',
  'View All': 'Ver todo', 'Create New Project': 'Crear proyecto', 'Create New Team': 'Crear equipo', Progress: 'Progreso',
  'System team': 'Equipo del sistema', 'Parent team': 'Equipo principal', 'Assign a project to get started': 'Asigna un proyecto para comenzar',
  'Mobile Access': 'Acceso movil', 'Scan with your phone': 'Escanea con tu telefono', 'Open QR code for mobile access': 'Abrir codigo QR para acceso movil', 'Scan QR code for mobile access': 'Escanea el codigo QR para acceso movil',
  Terminal: 'Terminal', Live: 'En vivo', 'Connecting...': 'Conectando...', 'Reconnecting...': 'Reconectando...', Disconnected: 'Desconectado', 'Session:': 'Sesion:',
  'Open Terminal': 'Abrir terminal', 'Close Terminal': 'Cerrar terminal', 'Loading dashboard...': 'Cargando inicio...', 'Just now': 'Ahora mismo',
  'More options': 'Mas opciones', 'Collapse sidebar': 'Contraer barra lateral', 'Resize terminal panel': 'Cambiar tamano del panel de terminal',
};

/** Translates legacy dynamic labels that cannot be represented by an exact phrase key. */
export function translateLegacyEsMx(value: string): string {
  const exact = LEGACY_ES_MX_PHRASES[value];
  if (exact) return exact;
  let match = value.match(/^(\d+) done$/);
  if (match) return `${match[1]} completadas`;
  match = value.match(/^(\d+) members?$/);
  if (match) return `${match[1]} ${match[1] === '1' ? 'miembro' : 'miembros'}`;
  match = value.match(/^(\d+) sub-teams? · (\d+) members?$/);
  if (match) return `${match[1]} ${match[1] === '1' ? 'subequipo' : 'subequipos'} · ${match[2]} ${match[2] === '1' ? 'miembro' : 'miembros'}`;
  match = value.match(/^(\d+)m ago$/);
  if (match) return `hace ${match[1]} min`;
  match = value.match(/^(\d+)h ago$/);
  if (match) return `hace ${match[1]} h`;
  match = value.match(/^(\d+)d ago$/);
  if (match) return `hace ${match[1]} d`;
  match = value.match(/^Updated (.+)$/);
  if (match) return `Actualizado ${match[1]}`;
  match = value.match(/^Last activity: (.+)$/);
  if (match) return `Ultima actividad: ${match[1]}`;
  match = value.match(/^Open: (\d+), In progress: (\d+), Pending: (\d+), Done: (\d+), Blocked: (\d+)$/);
  if (match) return `Abiertas: ${match[1]}, En progreso: ${match[2]}, Pendientes: ${match[3]}, Completadas: ${match[4]}, Bloqueadas: ${match[5]}`;
  match = value.match(/^(.+)'s avatar$/);
  if (match) return `Avatar de ${match[1]}`;
  return value;
}
