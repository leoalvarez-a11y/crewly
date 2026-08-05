import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export type RuntimeAvailabilityStatus = 'installed_unauthenticated' | 'authenticated' | 'blocked_credentials' | 'blocked_installation' | 'unavailable';
export type AuthenticationMode = 'chatgpt_subscription' | 'openai_api' | 'claude_subscription' | 'anthropic_console_api' | 'bedrock' | 'vertex' | 'unknown' | 'none';

export interface RuntimeAvailability {
  provider: 'OpenAI' | 'Anthropic';
  runtime: 'Codex CLI' | 'Claude Code';
  installed: boolean;
  authenticated: boolean;
  status: RuntimeAvailabilityStatus;
  version: string | null;
  authenticationMode: AuthenticationMode;
}

type SafeRunner = (file: string, args: string[]) => Promise<{ stdout: string; stderr: string; exitCode: number }>;

/** Runs an executable without a shell and returns only bounded diagnostic output. */
const defaultRunner: SafeRunner = async (file, args) => {
  try {
    const result = await execFileAsync(file, args, { timeout: 10_000, maxBuffer: 16_384 });
    return { stdout: result.stdout.trim(), stderr: result.stderr.trim(), exitCode: 0 };
  } catch (error) {
    const safe = error as { stdout?: string; stderr?: string; code?: number };
    return { stdout: String(safe.stdout ?? '').trim(), stderr: String(safe.stderr ?? '').trim(), exitCode: Number(safe.code ?? 1) };
  }
};

/** Detects supported CLI runtimes and auth status without reading credential files. */
export class RuntimeAvailabilityService {
  constructor(private readonly runner: SafeRunner = defaultRunner) {}

  /** Returns safe availability records for Codex and Claude Code. */
  async detect(): Promise<RuntimeAvailability[]> {
    return Promise.all([this.detectCodex(), this.detectClaude()]);
  }

  private async detectCodex(): Promise<RuntimeAvailability> {
    const version = await this.runner('codex', ['--version']);
    if (version.exitCode !== 0) return this.unavailable('OpenAI', 'Codex CLI');
    const auth = await this.runner('codex', ['login', 'status']);
    const authenticated = auth.exitCode === 0 && /logged in/i.test(`${auth.stdout} ${auth.stderr}`) && !/not logged in/i.test(`${auth.stdout} ${auth.stderr}`);
    return { provider: 'OpenAI', runtime: 'Codex CLI', installed: true, authenticated, status: authenticated ? 'authenticated' : 'installed_unauthenticated', version: version.stdout || version.stderr || null, authenticationMode: authenticated ? 'chatgpt_subscription' : 'none' };
  }

  private async detectClaude(): Promise<RuntimeAvailability> {
    const version = await this.runner('claude', ['--version']);
    if (version.exitCode !== 0) return this.unavailable('Anthropic', 'Claude Code');
    const auth = await this.runner('claude', ['auth', 'status']);
    let authenticated = false;
    let mode: AuthenticationMode = 'none';
    try {
      const parsed = JSON.parse(auth.stdout) as { loggedIn?: boolean; authMethod?: string };
      authenticated = parsed.loggedIn === true;
      const method = String(parsed.authMethod ?? '').toLowerCase();
      mode = method.includes('api') ? 'anthropic_console_api' : method.includes('bedrock') ? 'bedrock' : method.includes('vertex') ? 'vertex' : authenticated ? 'claude_subscription' : 'none';
    } catch { authenticated = auth.exitCode === 0 && /logged in/i.test(auth.stdout); mode = authenticated ? 'unknown' : 'none'; }
    return { provider: 'Anthropic', runtime: 'Claude Code', installed: true, authenticated, status: authenticated ? 'authenticated' : 'installed_unauthenticated', version: version.stdout || version.stderr || null, authenticationMode: mode };
  }

  private unavailable(provider: RuntimeAvailability['provider'], runtime: RuntimeAvailability['runtime']): RuntimeAvailability {
    return { provider, runtime, installed: false, authenticated: false, status: 'unavailable', version: null, authenticationMode: 'none' };
  }
}

export const runtimeAvailabilityService = new RuntimeAvailabilityService();
