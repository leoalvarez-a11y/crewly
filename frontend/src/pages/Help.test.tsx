import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import '../i18n';
import { Help } from './Help';

describe('Help', () => {
  it('links the principal, module, and cost guides', () => {
    render(<Help />);
    expect(screen.getByText('Guia principal')).toHaveAttribute('href', '/docs/es/GUIA_DE_USO.md');
    expect(screen.getAllByRole('link').length).toBe(22);
  });
});
