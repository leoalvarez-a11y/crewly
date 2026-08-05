import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import '../../i18n';
import { LocalizedDocument } from './LocalizedDocument';

describe('LocalizedDocument', () => {
  it('localizes legacy labels but preserves raw terminal output', () => {
    render(<><LocalizedDocument /><span>Projects</span><pre>Projects</pre></>);
    expect(screen.getByText('Proyectos')).toBeInTheDocument();
    expect(screen.getByText('Projects')).toBeInTheDocument();
  });
});
