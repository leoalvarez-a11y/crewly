import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import '../i18n';
import { Help } from './Help';

describe('Help', () => {
  it('links the principal, module, and cost guides', () => {
    render(<Help />);
    expect(screen.getByText('Guia interactiva con imagenes')).toHaveAttribute('href', '/docs/es/GUIA_INTERACTIVA.html');
    expect(screen.getAllByRole('link').length).toBe(22);
  });
});
