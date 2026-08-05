import { render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import '../../i18n';
import { LocalizedDocument } from './LocalizedDocument';

describe('LocalizedDocument', () => {
  it('localizes legacy labels but preserves raw terminal output', () => {
    render(<><LocalizedDocument /><span>Projects</span><pre>Projects</pre></>);
    expect(screen.getByText('Proyectos')).toBeInTheDocument();
    expect(screen.getByText('Projects')).toBeInTheDocument();
  });

  it('localizes dynamic dashboard labels and accessible attributes', async () => {
    const { rerender } = render(<><LocalizedDocument /><span>4 members</span><button aria-label="Open Terminal">Terminal</button></>);
    expect(screen.getByText('4 miembros')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Abrir terminal' })).toBeInTheDocument();
    rerender(<><LocalizedDocument /><span>7 members</span><button aria-label="Open Terminal">Terminal</button></>);
    await waitFor(() => expect(screen.getByText('7 miembros')).toBeInTheDocument());
  });
});
