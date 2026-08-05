import React, { useEffect, useState } from 'react';
import { settingsService } from '../../services/settings.service';
import type { RuntimeAvailability } from '../../types/settings.types';

const PRICING_REFERENCES = { OpenAI: 'https://openai.com/api/pricing/', Anthropic: 'https://www.anthropic.com/pricing' } as const;

/** Displays runtime availability and unknown-safe cost information. */
export const ProviderCostsTab: React.FC = () => {
  const [runtimes, setRuntimes] = useState<RuntimeAvailability[]>([]);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { void settingsService.getProviderAvailability().then(setRuntimes).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : 'No disponible')); }, []);
  return <section className="space-y-5">
    <div className="rounded-lg border border-border-dark p-5"><h2 className="text-lg font-semibold">Crewly open source</h2><p>Sin costo de licencia. Crewly Pro es opcional.</p></div>
    {error && <p role="alert">{error}</p>}
    <div className="grid gap-4">{runtimes.map((item) => <article key={item.runtime} className="rounded-lg border border-border-dark p-5 grid md:grid-cols-2 gap-2">
      <h3 className="font-semibold md:col-span-2">{item.provider} - {item.runtime}</h3>
      <p>Runtime instalado: {item.installed ? 'Si' : 'No'}</p><p>Autenticacion disponible: {item.authenticated ? 'Si' : 'No'}</p>
      <p>Modalidad: {item.authenticationMode}</p><p>Version: {item.version ?? 'No disponible'}</p>
      <p>Modelo: Configurable por agente</p><p>Clase de capacidad: Configurable por agente</p>
      <p>Presupuesto configurado: No disponible</p><p>Tokens disponibles: No disponible</p>
      <p>Costo registrado: No disponible</p><a className="text-primary" href={PRICING_REFERENCES[item.provider]} target="_blank" rel="noreferrer">Precios oficiales</a>
    </article>)}</div>
    <p className="text-sm text-text-secondary-dark">Las tarifas pueden cambiar. Catalogo actualizado: 2026-08-05. Los importes desconocidos se muestran como No disponible.</p>
  </section>;
};

export default ProviderCostsTab;
