// Add this file to your rent95-api under: src/controllers/device-token.controller.ts
//
// Registers / revokes FCM tokens for the authenticated user. Referenced from
// the mobile app's ApiDeviceTokenRepository via:
//   POST   /api/users/device-token   { token, platform }
//   DELETE /api/users/device-token   { token }

import type { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../config/prisma';
import { ok } from '../utils/response';

const registerSchema = z.object({
  token: z.string().min(10).max(4096),
  platform: z.enum(['ios', 'android', 'web', 'macos', 'windows', 'linux', 'unknown']),
});

const revokeSchema = z.object({
  token: z.string().min(10).max(4096),
});

export async function register(req: Request, res: Response, next: NextFunction) {
  try {
    const { token, platform } = registerSchema.parse(req.body);
    const userId = req.auth!.sub;

    // Upsert so re-registering the same token silently updates ownership
    // (useful when a device is passed between accounts).
    await prisma.deviceToken.upsert({
      where: { token },
      create: { token, platform, userId },
      update: { userId, platform },
    });

    return ok(res, { registered: true });
  } catch (e) {
    next(e);
  }
}

export async function revoke(req: Request, res: Response, next: NextFunction) {
  try {
    const { token } = revokeSchema.parse(req.body);
    const userId = req.auth!.sub;

    // Only delete our own token — never someone else's.
    await prisma.deviceToken.deleteMany({ where: { token, userId } });
    return ok(res, { revoked: true });
  } catch (e) {
    next(e);
  }
}
