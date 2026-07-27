// Add this file to your rent95-api under: src/services/push.service.ts
//
// Sends FCM pushes to a specific user by looking up their registered device
// tokens. Uses the Firebase Admin SDK; add it with:
//
//   npm install firebase-admin
//
// Configure via one of:
//   - GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
//   - FCM_SERVICE_ACCOUNT_JSON_BASE64=<base64-encoded service account JSON>

import { readFileSync } from 'node:fs';
import admin from 'firebase-admin';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { prisma } from '../config/prisma';

let _initialized = false;

function initFirebase() {
  if (_initialized) return;
  try {
    if (admin.apps.length > 0) {
      _initialized = true;
      return;
    }

    if (env.FCM_SERVICE_ACCOUNT_JSON_BASE64) {
      const json = JSON.parse(
        Buffer.from(env.FCM_SERVICE_ACCOUNT_JSON_BASE64, 'base64').toString('utf-8'),
      );
      admin.initializeApp({ credential: admin.credential.cert(json) });
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      const json = JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf-8'));
      admin.initializeApp({ credential: admin.credential.cert(json) });
    } else {
      logger.warn('FCM service-account not configured — push disabled');
      return;
    }

    _initialized = true;
  } catch (err) {
    logger.error({ err }, 'FCM init failed');
  }
}

export type PushMessage = {
  title: string;
  body: string;
  /**
   * `type` is the notification kind (e.g. 'message_received', 'booking_accepted').
   * Mobile client's NotificationRouter uses this + entityId to decide which
   * screen to open on tap.
   */
  type: string;
  entityId?: string;
  /**
   * Any additional data-only fields. Values MUST be strings — that's an FCM
   * requirement. Numbers/booleans need to be stringified before sending.
   */
  data?: Record<string, string>;
};

/**
 * Send a push to every device the user has registered.
 *
 * - Silently no-ops when FCM isn't configured, so local dev works fine.
 * - Removes dead tokens on `messaging/registration-token-not-registered`.
 */
export async function pushToUser(userId: string, message: PushMessage): Promise<void> {
  initFirebase();
  if (!_initialized) return;

  const tokens = await prisma.deviceToken.findMany({ where: { userId }, select: { token: true } });
  if (tokens.length === 0) return;

  const payload: admin.messaging.MulticastMessage = {
    tokens: tokens.map((t) => t.token),
    notification: { title: message.title, body: message.body },
    data: {
      type: message.type,
      ...(message.entityId ? { entityId: message.entityId } : {}),
      ...(message.data ?? {}),
    },
    android: { priority: 'high', notification: { channelId: 'rent95_general' } },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(payload);
    const deadTokens: string[] = [];

    response.responses.forEach((resp, i) => {
      if (!resp.success) {
        const code = resp.error?.code;
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          deadTokens.push(tokens[i]!.token);
        }
      }
    });

    if (deadTokens.length > 0) {
      await prisma.deviceToken.deleteMany({ where: { token: { in: deadTokens } } });
    }
  } catch (err) {
    logger.error({ err }, 'FCM push failed');
  }
}

/**
 * Helper the rest of the codebase should call — persists the notification
 * to the DB AND pushes it. Keeps the two in sync.
 */
export async function notifyUser(
  userId: string,
  args: PushMessage & { skipPersist?: boolean },
): Promise<void> {
  if (!args.skipPersist) {
    await prisma.notification.create({
      data: {
        userId,
        title: args.title,
        body: args.body,
        type: args.type,
        data: {
          ...(args.entityId ? { entityId: args.entityId } : {}),
          ...(args.data ?? {}),
        },
      },
    });
  }
  await pushToUser(userId, args);
}
