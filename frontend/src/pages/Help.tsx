import React from 'react';
import { BookOpen, ExternalLink } from 'lucide-react';
import { useTranslation } from 'react-i18next';

const GUIDES = [
  '01-INICIO-Y-DASHBOARD', '02-PROYECTOS', '03-EQUIPOS', '04-AGENTES-Y-ROLES',
  '05-PROVEEDORES-RUNTIMES-Y-MODELOS', '06-CHAT-Y-SOLICITUDES', '07-TAREAS-Y-WORK-ITEMS',
  '08-TERMINALES-EN-VIVO', '09-QA-VERIFICACION-Y-RETRABAJO', '10-MEMORIA',
  '11-WIKI-Y-BASE-DE-CONOCIMIENTO', '12-SKILLS-Y-MARKETPLACE', '13-PRESUPUESTOS-TOKENS-Y-COSTOS',
  '14-LOGS-Y-SALUD', '15-BACKUP-Y-RESTAURACION', '16-CLOUD-RELAY-Y-MOVIL', '17-SLACK',
  '18-WHATSAPP-BAILEYS', '19-CONFIGURACION', '20-SOLUCION-DE-PROBLEMAS',
] as const;

/** Visible in-product index for the Spanish documentation shipped with Crewly. */
export const Help: React.FC = () => {
  const { t } = useTranslation();
  return <div className="max-w-5xl mx-auto space-y-6">
    <header><h1 className="text-3xl font-bold">{t('help.title')}</h1><p className="text-text-secondary-dark">{t('help.subtitle')}</p></header>
    <a className="flex items-center gap-2 text-primary" href="/docs/es/GUIA_DE_USO.md" target="_blank" rel="noreferrer"><BookOpen className="w-5 h-5" />Guia principal<ExternalLink className="w-4 h-4" /></a>
    <div className="grid md:grid-cols-2 gap-3">{GUIDES.map((guide) => <a key={guide} href={`/docs/es/${guide}.md`} target="_blank" rel="noreferrer" className="rounded-lg border border-border-dark p-4 hover:border-primary"><span className="font-medium">{guide.replace(/-/g, ' ')}</span></a>)}</div>
    <a className="block text-primary" href="/docs/es/COSTOS-Y-SUSCRIPCIONES.md" target="_blank" rel="noreferrer">Costos y suscripciones</a>
  </div>;
};

export default Help;
