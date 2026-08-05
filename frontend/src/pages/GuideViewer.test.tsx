import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { GuideViewer } from './GuideViewer';

describe('GuideViewer', () => {
  afterEach(() => vi.restoreAllMocks());

  it('renders a bundled guide and resolves its visual assets', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('# Guía visual\n\n![Inicio](assets/guia-visual/01-inicio.png)'));
    render(<MemoryRouter initialEntries={['/help/guide/GUIA_DE_USO']}><Routes><Route path="/help/guide/:slug" element={<GuideViewer />} /></Routes></MemoryRouter>);

    expect(await screen.findByRole('heading', { name: 'Guía visual' })).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Inicio' })).toHaveAttribute('src', '/docs/es/assets/guia-visual/01-inicio.png');
    expect(fetch).toHaveBeenCalledWith('/docs/es/GUIA_DE_USO.md', expect.objectContaining({ signal: expect.any(AbortSignal) }));
  });
});
