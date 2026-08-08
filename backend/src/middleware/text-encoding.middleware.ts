import type { RequestHandler, Response } from 'express';
import { repairTextEncodingDeep } from '../utils/text-encoding.js';

/** Ensure every JSON response rendered by the site contains normalized Unicode text. */
export const repairJsonTextEncoding: RequestHandler = (_req, res, next) => {
  const sendJson = res.json.bind(res);
  res.json = ((body: unknown) => sendJson(repairTextEncodingDeep(body))) as Response['json'];
  next();
};
