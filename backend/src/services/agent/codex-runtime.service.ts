import { RuntimeAgentService } from './runtime-agent.service.abstract.js';
import { SessionCommandHelper } from '../session/index.js';
import { RUNTIME_TYPES, type RuntimeType } from '../../constants.js';
import { delay } from '../../utils/async.utils.js';

/**
 * OpenAI Codex CLI specific runtime service implementation.
 * Handles Codex CLI initialization, detection, and interaction patterns.
 */
export class CodexRuntimeService extends RuntimeAgentService {
	constructor(sessionHelper: SessionCommandHelper, projectRoot: string) {
		super(sessionHelper, projectRoot);
	}

	protected getRuntimeType(): RuntimeType {
		return RUNTIME_TYPES.CODEX_CLI;
	}

	/** Detect the interactive self-update selector shown before the Codex UI. */
	private isCodexUpdatePrompt(output: string): boolean {
		return output.includes('Update available!')
			&& output.includes('Skip until next version')
			&& output.includes('Press enter to continue');
	}

	/** Detect Codex's first-use trust confirmation for a project directory. */
	private isCodexTrustPrompt(output: string): boolean {
		return output.includes('Do you trust the contents of this directory?')
			&& output.includes('Yes, continue')
			&& output.includes('Press enter to continue');
	}

	/**
	 * Wait for Codex while safely dismissing its optional update prompt.
	 * Selecting "Skip until next version" avoids modifying the installed CLI
	 * during an agent launch and prevents every new PTY from blocking.
	 */
	async waitForRuntimeReady(
		sessionName: string,
		timeout: number,
		checkInterval: number = 2000,
	): Promise<boolean> {
		const startTime = Date.now();
		let updatePromptHandled = false;
		let trustPromptHandled = false;

		while (Date.now() - startTime < timeout) {
			const output = this.sessionHelper.capturePane(sessionName);
			if (!trustPromptHandled && this.isCodexTrustPrompt(output)) {
				this.logger.info('Codex workspace trust prompt detected, accepting', { sessionName });
				await this.sessionHelper.sendEnter(sessionName);
				trustPromptHandled = true;
				await delay(1000);
				continue;
			}

			if (!updatePromptHandled && this.isCodexUpdatePrompt(output)) {
				this.logger.info('Codex update prompt detected, deferring update', { sessionName });
				await this.sessionHelper.sendKey(sessionName, 'Down');
				await this.sessionHelper.sendKey(sessionName, 'Down');
				await this.sessionHelper.sendEnter(sessionName);
				updatePromptHandled = true;
				await delay(1000);
				continue;
			}

			if (this.getRuntimeReadyPatterns().some((pattern) => output.includes(pattern))) {
				this.logger.info('Codex CLI ready', {
					sessionName,
					totalElapsed: Date.now() - startTime,
					updatePromptHandled,
					trustPromptHandled,
				});
				return true;
			}

			if (this.getRuntimeErrorPatterns().some((pattern) => output.includes(pattern))) {
				return false;
			}

			await delay(checkInterval);
		}

		this.logger.warn('Timeout waiting for Codex CLI', { sessionName, timeout });
		return false;
	}

	/**
	 * Codex CLI runtime detection.
	 *
	 * NOTE: Do not use active key probes (Ctrl+C, '/', etc.) here. Codex can
	 * interpret those as shell input/cancel and drop back to zsh, which causes
	 * false negatives and unintended exits during health checks.
	 */
	protected async detectRuntimeSpecific(sessionName: string): Promise<boolean> {
		const output = this.sessionHelper.capturePane(sessionName, 120);
		const readyPatterns = this.getRuntimeReadyPatterns();
		const hasReadySignal = readyPatterns.some((pattern) => output.includes(pattern));

		this.logger.debug('Codex detection completed', {
			sessionName,
			hasReadySignal,
		});

		return hasReadySignal;
	}

	/**
	 * Codex CLI specific ready patterns
	 */
	protected getRuntimeReadyPatterns(): string[] {
		return [
			'Codex CLI',
			'codex>',
			'Ready for commands',
			'OpenAI Codex',
			'model:',
			'token:',
			'Connected to OpenAI',
			'Welcome to Codex',
			'Initialized successfully',
		];
	}

	/**
	 * Codex CLI specific exit patterns for runtime exit detection
	 */
	protected getRuntimeExitPatterns(): RegExp[] {
		return [
			/codex.*exited/i,
			/Session\s+ended/i,
			/Conversation interrupted/i,
		];
	}

	/**
	 * Codex CLI specific error patterns
	 */
	protected getRuntimeErrorPatterns(): string[] {
		const commonErrors = ['Permission denied', 'No such file or directory'];
		return [
			...commonErrors,
			'command not found: codex',
			'OpenAI API error',
			'Authentication failed',
			'Invalid API key',
			'Rate limit exceeded',
			'Token limit exceeded',
		];
	}

	/**
	 * Check if Codex CLI is installed and configured
	 */
	async checkCodexInstallation(): Promise<{
		isInstalled: boolean;
		version?: string;
		message: string;
	}> {
		try {
			// This would check if Codex CLI is available
			// Could run: codex --version or similar
			return {
				isInstalled: true,
				message: 'OpenAI Codex CLI is available',
			};
		} catch (error) {
			return {
				isInstalled: false,
				message: 'OpenAI Codex CLI not found or not configured',
			};
		}
	}

	/**
	 * Initialize Codex in an existing session
	 */
	async initializeCodexInSession(sessionName: string): Promise<{
		success: boolean;
		message: string;
	}> {
		try {
			await this.executeRuntimeInitScript(sessionName);
			return {
				success: true,
				message: 'OpenAI Codex CLI initialized successfully',
			};
		} catch (error) {
			return {
				success: false,
				message:
					error instanceof Error
						? error.message
						: 'Failed to initialize OpenAI Codex CLI',
			};
		}
	}
}
