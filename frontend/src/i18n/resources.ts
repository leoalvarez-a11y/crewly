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
  Dashboard: 'Inicio', Projects: 'Proyectos', Teams: 'Equipos', Agents: 'Agentes', Tasks: 'Tareas', Requests: 'Solicitudes', Activity: 'Actividad', Memory: 'Memoria', Skills: 'Skills', Budgets: 'Presupuestos', Models: 'Modelos', Settings: 'Configuracion', Approvals: 'Aprobaciones', Escalations: 'Escalaciones', Backups: 'Respaldos', Cloud: 'Nube', Mobile: 'Movil', Health: 'Salud', Terminals: 'Terminales', 'No data available': 'No hay datos disponibles', 'No results found': 'No se encontraron resultados', 'Something went wrong': 'Ocurrio un error', Loading: 'Cargando', Save: 'Guardar', Cancel: 'Cancelar', Create: 'Crear', Delete: 'Eliminar', Edit: 'Editar', Status: 'Estado', Error: 'Error', Success: 'Correcto', Pending: 'Pendiente', Active: 'Activo', Inactive: 'Inactivo', Documentation: 'Documentacion', Usage: 'Uso', Security: 'Seguridad', Triggers: 'Automatizaciones', Missions: 'Misiones', 'Work Items': 'Elementos de trabajo', 'Cloud Portal': 'Nube', Integrations: 'Integraciones', Credentials: 'Credenciales', System: 'Sistema', General: 'General', Roles: 'Roles', Favorites: 'Favoritos', Collapse: 'Contraer', Help: 'Ayuda', WhatsApp: 'WhatsApp', Slack: 'Slack', Wiki: 'Wiki', Marketplace: 'Marketplace', Chat: 'Chat',
};
