import React, { useEffect, useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { useParams } from 'react-router-dom';

const SAFE_GUIDE = /^[A-Z0-9_-]+$/;

/** Renders a bundled Spanish guide and resolves its local images safely. */
export const GuideViewer: React.FC = () => {
  const { slug = '' } = useParams<{ slug: string }>();
  const [markdown, setMarkdown] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!SAFE_GUIDE.test(slug)) {
      setError('La guía solicitada no es válida.');
      return;
    }

    const controller = new AbortController();
    setError('');
    setMarkdown('');
    void fetch(`/docs/es/${slug}.md`, { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.text();
      })
      .then(setMarkdown)
      .catch((reason: unknown) => {
        if ((reason as { name?: string }).name !== 'AbortError') {
          setError('No se pudo abrir esta guía. Comprueba que Crewly esté actualizado.');
        }
      });
    return () => controller.abort();
  }, [slug]);

  return <div className="max-w-5xl mx-auto space-y-6">
    <a href="/help" className="inline-flex items-center gap-2 text-primary"><ArrowLeft className="w-4 h-4" />Volver a Ayuda</a>
    {error && <div role="alert" className="rounded-lg border border-red-500/40 bg-red-500/10 p-4 text-red-300">{error}</div>}
    {!error && !markdown && <p className="text-text-secondary-dark">Cargando guía...</p>}
    {markdown && <article className="prose prose-invert max-w-none prose-img:rounded-xl prose-img:border prose-img:border-border-dark">
      <ReactMarkdown components={{
        img: ({ src, alt }) => <img src={src?.startsWith('/') || src?.startsWith('http') ? src : `/docs/es/${src ?? ''}`} alt={alt ?? ''} loading="lazy" />,
        a: ({ href, children }) => {
          const internalGuide = href?.match(/^([A-Z0-9-]+)\.md(?:#.*)?$/);
          const destination = internalGuide ? `/help/guide/${internalGuide[1]}` : href;
          return <a href={destination}>{children}</a>;
        },
      }}>{markdown}</ReactMarkdown>
    </article>}
  </div>;
};

export default GuideViewer;
