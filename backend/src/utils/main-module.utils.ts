/**
 * Determine whether the current argv entry is Crewly's backend entrypoint.
 * Normalize separators because Node reports native backslashes on Windows.
 */
export function isCrewlyMainModule(entryPath: string | undefined): boolean {
	if (!entryPath) {
		return false;
	}
	const normalized = entryPath.replace(/\\/g, '/');
	return normalized.endsWith('/index.ts') || normalized.endsWith('/index.js');
}
