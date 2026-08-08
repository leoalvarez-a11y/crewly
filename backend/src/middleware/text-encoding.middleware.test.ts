import express from 'express';
import request from 'supertest';
import { repairJsonTextEncoding } from './text-encoding.middleware.js';

describe('repairJsonTextEncoding', () => {
  it('repairs nested text in API responses without changing identifiers', async () => {
    const app = express();
    app.use(repairJsonTextEncoding);
    app.get('/status', (_req, res) => {
      res.json({
        id: 'agent-123',
        status: ['La ejecuci�n est� activa', { owner: 'Arquitecto l�der' }],
      });
    });

    const response = await request(app).get('/status').expect(200);

    expect(response.body).toEqual({
      id: 'agent-123',
      status: ['La ejecución está activa', { owner: 'Arquitecto líder' }],
    });
  });
});
