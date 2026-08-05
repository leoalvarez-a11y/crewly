import { describe, expect, it } from 'vitest';
import { RuntimeAvailabilityService } from './runtime-availability.service.js';

describe('RuntimeAvailabilityService', () => {
  it('reports authenticated runtimes without returning credential output', async () => {
    const service = new RuntimeAvailabilityService(async (file, args) => {
      if (args[0] === '--version') return { stdout: `${file} 1.0`, stderr: '', exitCode: 0 };
      if (file === 'codex') return { stdout: 'Logged in using ChatGPT', stderr: '', exitCode: 0 };
      return { stdout: '{"loggedIn":true,"authMethod":"subscription","token":"secret"}', stderr: '', exitCode: 0 };
    });
    const result = await service.detect();
    expect(result.every((item) => item.status === 'authenticated')).toBe(true);
    expect(JSON.stringify(result)).not.toContain('secret');
  });

  it('classifies missing binaries as unavailable', async () => {
    const service = new RuntimeAvailabilityService(async () => ({ stdout: '', stderr: 'not found', exitCode: 127 }));
    expect((await service.detect()).every((item) => item.status === 'unavailable')).toBe(true);
  });
});
