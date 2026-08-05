import { render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ProviderCostsTab } from './ProviderCostsTab';

vi.mock('../../services/settings.service', () => ({ settingsService: { getProviderAvailability: async () => [{ provider: 'OpenAI', runtime: 'Codex CLI', installed: true, authenticated: false, status: 'installed_unauthenticated', version: '1', authenticationMode: 'none' }] } }));

describe('ProviderCostsTab', () => {
  it('uses No disponible for unknown costs and never invents an amount', async () => {
    render(<ProviderCostsTab />);
    await waitFor(() => expect(screen.getByText(/Codex CLI/)).toBeInTheDocument());
    expect(screen.getAllByText(/No disponible/).length).toBeGreaterThan(1);
    expect(screen.queryByText(/\$\d/)).not.toBeInTheDocument();
  });
});
