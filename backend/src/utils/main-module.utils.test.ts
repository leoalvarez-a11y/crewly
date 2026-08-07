import { isCrewlyMainModule } from './main-module.utils.js';

describe('isCrewlyMainModule', () => {
	it('recognizes the compiled Windows entrypoint', () => {
		expect(
			isCrewlyMainModule('C:\\crewly\\dist\\backend\\backend\\src\\index.js'),
		).toBe(true);
	});

	it('recognizes the POSIX TypeScript entrypoint', () => {
		expect(isCrewlyMainModule('/opt/crewly/backend/src/index.ts')).toBe(true);
	});

	it('rejects missing and unrelated entrypoints', () => {
		expect(isCrewlyMainModule(undefined)).toBe(false);
		expect(isCrewlyMainModule('C:\\crewly\\scripts\\worker.js')).toBe(false);
	});
});
