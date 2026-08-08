import { hasEncodingDamage, repairTextEncoding } from './text-encoding.js';

describe('text encoding repair', () => {
  it('repairs reversible UTF-8 decoded as Latin-1', () => {
    expect(repairTextEncoding('ConfiguraciÃ³n â€” MÃ©xico')).toBe('Configuración — México');
  });

  it('repairs the Spanish replacement-character patterns observed in chat', () => {
    expect(repairTextEncoding('La ejecuci�n est� activa y espera autom�ticamente.')).toBe(
      'La ejecución está activa y espera automáticamente.',
    );
    expect(repairTextEncoding('Har� la aceptaci�n; despu�s responder� aqu�.')).toBe(
      'Haré la aceptación; después responderé aquí.',
    );
    expect(repairTextEncoding('dise�ada para categor�a e im�genes')).toBe(
      'diseñada para categoría e imágenes',
    );
  });

  it('repairs question-mark substitutions without changing real questions', () => {
    expect(repairTextEncoding('Actualizaci?n: termin? la verificaci?n. Qu? falta?')).toBe(
      'Actualización: terminó la verificación. Qué falta?',
    );
    expect(repairTextEncoding('¿Qué falta?')).toBe('¿Qué falta?');
  });

  it('does not turn a damaged question ending into an accented suffix', () => {
    expect(repairTextEncoding('¿por qué solo esos son elegibles�')).toBe(
      '¿por qué solo esos son elegibles?',
    );
  });

  it('repairs common persisted task and documentation vocabulary', () => {
    expect(repairTextEncoding('Documentaci�n en espa�ol: revisi�n expl�cita de c�digo.')).toBe(
      'Documentación en español: revisión explícita de código.',
    );
  });

  it('normalizes casing and first-person forms produced by older repairs', () => {
    expect(repairTextEncoding('ACEPTACIón POST-FIX; no los toquó.')).toBe(
      'ACEPTACIÓN POST-FIX; no los toqué.',
    );
  });

  it('reports damage that remains unknown', () => {
    expect(hasEncodingDamage(repairTextEncoding('palabra�desconocida'))).toBe(true);
    expect(hasEncodingDamage(repairTextEncoding('Configuración correcta'))).toBe(false);
  });
});
