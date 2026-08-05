/**
 * Tests for TeamMemberRow component
 * Tests loading states, status display, and button interactions
 */

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { TeamMemberRow } from './TeamMemberRow';
import { TeamMember } from '@/types';

// Mock lucide-react icons
vi.mock('lucide-react', () => ({
  Play: () => <span data-testid="play-icon">Play</span>,
  Square: () => <span data-testid="square-icon">Square</span>,
  Loader2: () => <span data-testid="loader-icon">Loader</span>,
}));

// Mock OverflowMenu component
vi.mock('@/components/UI/OverflowMenu', () => ({
  OverflowMenu: ({ items }: { items: Array<{ label: string; onClick: () => void }> }) => (
    <div data-testid="overflow-menu">
      {items.map((item, index) => (
        <button key={index} onClick={item.onClick} data-testid={`menu-item-${index}`}>
          {item.label}
        </button>
      ))}
    </div>
  ),
}));

/**
 * Create a default test member
 */
function createTestMember(overrides: Partial<TeamMember> = {}): TeamMember {
  return {
    id: 'member-1',
    name: 'Test Developer',
    role: 'developer',
    sessionName: 'test-session',
    agentStatus: 'inactive',
    workingStatus: 'idle',
    runtimeType: 'claude-code',
    createdAt: '2024-01-01T00:00:00.000Z',
    updatedAt: '2024-01-01T00:00:00.000Z',
    ...overrides,
  };
}

describe('TeamMemberRow', () => {
  const defaultProps = {
    member: createTestMember(),
    teamId: 'team-1',
  };

  describe('rendering', () => {
    it('should render member name', () => {
      render(<TeamMemberRow {...defaultProps} />);
      expect(screen.getByText('Test Developer')).toBeInTheDocument();
    });

    it('should render session name', () => {
      render(<TeamMemberRow {...defaultProps} />);
      expect(screen.getByText('Session: test-session')).toBeInTheDocument();
    });

    it('should display "Stopped" when session is not active', () => {
      render(<TeamMemberRow {...defaultProps} />);
      expect(screen.getByText('Stopped')).toBeInTheDocument();
    });

    it('should display avatar initial when no avatar provided', () => {
      render(<TeamMemberRow {...defaultProps} />);
      expect(screen.getByText('T')).toBeInTheDocument(); // First letter of "Test Developer"
    });

    it('should display emoji avatar when provided', () => {
      const member = createTestMember({ avatar: '🤖' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByText('🤖')).toBeInTheDocument();
    });

    it('should display image avatar when URL is provided', () => {
      const member = createTestMember({ avatar: 'https://example.com/avatar.png' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      const img = screen.getByAltText('Test Developer');
      expect(img).toHaveAttribute('src', 'https://example.com/avatar.png');
    });
  });

  describe('status display', () => {
    it('should show "Stopped" for inactive status', () => {
      const member = createTestMember({ agentStatus: 'inactive' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByText('Stopped')).toBeInTheDocument();
    });

    it('should show "Started" for active status', () => {
      const member = createTestMember({ agentStatus: 'active' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByText('Started')).toBeInTheDocument();
    });

    it('should show "Starting..." for activating status', () => {
      const member = createTestMember({ agentStatus: 'activating' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByText('Starting...')).toBeInTheDocument();
    });
  });

  describe('start button', () => {
    it('should show Play button when member is inactive', () => {
      const member = createTestMember({ agentStatus: 'inactive' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByTestId('play-icon')).toBeInTheDocument();
    });

    it('should call onStart when Play button is clicked', async () => {
      const onStart = vi.fn().mockResolvedValue(undefined);
      const member = createTestMember({ agentStatus: 'inactive' });
      render(<TeamMemberRow {...defaultProps} member={member} onStart={onStart} />);

      const playButton = screen.getByTitle('Start');
      fireEvent.click(playButton);

      expect(onStart).toHaveBeenCalledWith('member-1');
    });

    it('should show loading state when starting', async () => {
      let resolveStart: () => void;
      const startPromise = new Promise<void>((resolve) => {
        resolveStart = resolve;
      });
      const onStart = vi.fn().mockReturnValue(startPromise);
      const member = createTestMember({ agentStatus: 'inactive' });

      render(<TeamMemberRow {...defaultProps} member={member} onStart={onStart} />);

      const playButton = screen.getByTitle('Start');
      fireEvent.click(playButton);

      // Should show loader while starting
      await waitFor(() => {
        expect(screen.getByText('Starting...')).toBeInTheDocument();
      });

      // Resolve the promise
      resolveStart!();

      // Wait for loading to finish
      await waitFor(() => {
        expect(screen.queryByText('Starting...')).not.toBeInTheDocument();
      });
    });

    it('should disable button while starting', async () => {
      let resolveStart: () => void;
      const startPromise = new Promise<void>((resolve) => {
        resolveStart = resolve;
      });
      const onStart = vi.fn().mockReturnValue(startPromise);
      const member = createTestMember({ agentStatus: 'inactive' });

      render(<TeamMemberRow {...defaultProps} member={member} onStart={onStart} />);

      const playButton = screen.getByTitle('Start');
      fireEvent.click(playButton);

      // Button should be disabled
      await waitFor(() => {
        expect(playButton).toBeDisabled();
      });

      // Resolve and cleanup
      resolveStart!();
      await waitFor(() => {
        expect(playButton).not.toBeDisabled();
      });
    });
  });

  describe('stop button', () => {
    it('should show Square button when member is active', () => {
      const member = createTestMember({ agentStatus: 'active' });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      expect(screen.getByTestId('square-icon')).toBeInTheDocument();
    });

    it('should call onStop when Stop button is clicked', async () => {
      const onStop = vi.fn().mockResolvedValue(undefined);
      const member = createTestMember({ agentStatus: 'active' });
      render(<TeamMemberRow {...defaultProps} member={member} onStop={onStop} />);

      const stopButton = screen.getByTitle('Stop');
      fireEvent.click(stopButton);

      expect(onStop).toHaveBeenCalledWith('member-1');
    });

    it('should show loading state when stopping', async () => {
      let resolveStop: () => void;
      const stopPromise = new Promise<void>((resolve) => {
        resolveStop = resolve;
      });
      const onStop = vi.fn().mockReturnValue(stopPromise);
      const member = createTestMember({ agentStatus: 'active' });

      render(<TeamMemberRow {...defaultProps} member={member} onStop={onStop} />);

      const stopButton = screen.getByTitle('Stop');
      fireEvent.click(stopButton);

      // Should show "Stopping..." text
      await waitFor(() => {
        expect(screen.getByText('Stopping...')).toBeInTheDocument();
      });

      // Resolve the promise
      resolveStop!();

      // Wait for loading to finish
      await waitFor(() => {
        expect(screen.queryByText('Stopping...')).not.toBeInTheDocument();
      });
    });
  });

  describe('overflow menu', () => {
    it('should show View Terminal option when session exists', () => {
      const onViewTerminal = vi.fn();
      const member = createTestMember({ sessionName: 'test-session' });
      render(
        <TeamMemberRow
          {...defaultProps}
          member={member}
          onViewTerminal={onViewTerminal}
        />
      );

      expect(screen.getByText('View Terminal')).toBeInTheDocument();
    });

    it('should not show View Terminal option when no session', () => {
      const onViewTerminal = vi.fn();
      const member = createTestMember({ sessionName: undefined });
      render(
        <TeamMemberRow
          {...defaultProps}
          member={member}
          onViewTerminal={onViewTerminal}
        />
      );

      expect(screen.queryByText('View Terminal')).not.toBeInTheDocument();
    });

    it('should call onViewTerminal when View Terminal is clicked', () => {
      const onViewTerminal = vi.fn();
      const member = createTestMember({ sessionName: 'test-session' });
      render(
        <TeamMemberRow
          {...defaultProps}
          member={member}
          onViewTerminal={onViewTerminal}
        />
      );

      fireEvent.click(screen.getByText('View Terminal'));
      expect(onViewTerminal).toHaveBeenCalledWith(member);
    });
  });

  describe('execution observability', () => {
    it('shows requested execution outcome and unavailable telemetry', () => {
      const member = createTestMember({
        provider: 'openai',
        runtimeType: 'codex-cli',
        executionReceipt: {
          catalogVersion: 'test-v1', provider: 'openai', requestedRuntime: 'codex-cli',
          executedRuntime: 'codex-cli', requestedModel: null, executedModel: 'openai/cheap',
          capabilityClass: 'strong_coding', selectionReason: 'automatic_cheapest_sufficient',
          fallbackUsed: false, fallbackClassification: null, inputTokens: null, outputTokens: null,
          totalTokens: null, costUsd: null, memoryLayerConsulted: true,
          memoryReferences: ['memory://fixture'], recordedAt: '2026-08-04T00:00:00.000Z',
        },
      });
      render(<TeamMemberRow {...defaultProps} member={member} />);
      const summary = screen.getByTestId('execution-summary');
      expect(summary).toHaveTextContent('Runtime: codex-cli → codex-cli');
      expect(summary).toHaveTextContent('Model: Runtime default → openai/cheap');
      expect(summary).toHaveTextContent('Capability: strong_coding');
      expect(summary).toHaveTextContent('Fallback: no');
      expect(summary).toHaveTextContent('Tokens: No disponible');
      expect(summary).toHaveTextContent('Memory: yes');
      expect(summary).toHaveTextContent('References: memory://fixture');
    });
  });

  describe('loading state interactions', () => {
    it('should not allow multiple simultaneous start clicks', async () => {
      let resolveStart: () => void;
      const startPromise = new Promise<void>((resolve) => {
        resolveStart = resolve;
      });
      const onStart = vi.fn().mockReturnValue(startPromise);
      const member = createTestMember({ agentStatus: 'inactive' });

      render(<TeamMemberRow {...defaultProps} member={member} onStart={onStart} />);

      const playButton = screen.getByTitle('Start');

      // Click twice rapidly
      fireEvent.click(playButton);
      fireEvent.click(playButton);

      // Should only be called once due to isLoading check
      expect(onStart).toHaveBeenCalledTimes(1);

      // Cleanup
      resolveStart!();
    });

    it('should reset loading state after operation completes', async () => {
      // Create a promise that resolves after a delay
      let resolveStart: () => void;
      const startPromise = new Promise<void>((resolve) => {
        resolveStart = resolve;
      });
      const onStart = vi.fn().mockReturnValue(startPromise);
      const member = createTestMember({ agentStatus: 'inactive' });

      render(<TeamMemberRow {...defaultProps} member={member} onStart={onStart} />);

      const playButton = screen.getByTitle('Start');
      fireEvent.click(playButton);

      // Verify loading state is active
      await waitFor(() => {
        expect(playButton).toBeDisabled();
      });

      // Resolve the promise
      resolveStart!();

      // Wait for loading to reset
      await waitFor(() => {
        expect(playButton).not.toBeDisabled();
      });
    });
  });
});
