// Add this file to your rent95-api under: src/controllers/uploads.controller.ts
//
// Generates short-lived signatures so the mobile client can upload directly
// to Cloudinary. We never proxy the file bytes through our server — that
// saves bandwidth and gives the client a real progress bar.
//
// npm install cloudinary  (~50 KB, no native deps)

import type { Request, Response, NextFunction } from 'express';
import { v2 as cloudinary } from 'cloudinary';
import { z } from 'zod';
import { env } from '../config/env';
import { ok } from '../utils/response';
import { BadRequestError } from '../utils/errors';

// Configure once at import time.
cloudinary.config({
  cloud_name: env.CLOUDINARY_CLOUD_NAME,
  api_key: env.CLOUDINARY_API_KEY,
  api_secret: env.CLOUDINARY_API_SECRET,
  secure: true,
});

const requestSchema = z.object({
  /**
   * `listing`  → products/{userId}/{timestamp}
   * `avatar`   → users/{userId}/avatar
   * `review`   → reviews/{userId}
   *
   * See spec §15.2 for the object-path convention.
   */
  purpose: z.enum(['listing', 'avatar', 'review']),

  /**
   * Optional public_id fragment. Cloudinary generates one otherwise. We use
   * this so retrying an upload with the same key idempotently replaces the
   * previous version rather than creating a duplicate.
   */
  publicIdSuffix: z.string().max(64).regex(/^[a-zA-Z0-9_-]+$/).optional(),
});

/**
 * Returns everything the client needs to make ONE upload:
 *   - `signature`  — SHA1(sorted signed params + api_secret)
 *   - `timestamp`  — must match what the client sends
 *   - `folder`     — pre-scoped so a compromised client can't dump into
 *                    another user's folder
 *   - `apiKey`     — Cloudinary API key (public — safe to expose)
 *   - `cloudName`  — the Cloudinary cloud identifier
 *   - `uploadUrl`  — assembled URL the client POSTs multipart to
 *
 * Signatures are valid for ~1 hour on Cloudinary's side. We don't
 * pre-generate a pool — one signature per upload keeps replay risk low.
 */
export async function createSignature(req: Request, res: Response, next: NextFunction) {
  try {
    if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_SECRET) {
      throw new BadRequestError('Uploads are not configured on the server.');
    }

    const { purpose, publicIdSuffix } = requestSchema.parse(req.body);
    const userId = req.auth!.sub;
    const timestamp = Math.floor(Date.now() / 1000);
    const folder = _folderFor(purpose, userId);

    // Everything in this object gets included in the signature. Fields sent
    // by the client at upload time that aren't in this object are IGNORED
    // by Cloudinary (unsigned params). See:
    // https://cloudinary.com/documentation/upload_images#generating_authentication_signatures
    const paramsToSign: Record<string, string | number> = {
      folder,
      timestamp,
    };
    if (publicIdSuffix) {
      paramsToSign.public_id = `${folder}/${publicIdSuffix}`;
    }

    const signature = cloudinary.utils.api_sign_request(paramsToSign, env.CLOUDINARY_API_SECRET);

    return ok(res, {
      signature,
      timestamp,
      folder,
      publicId: paramsToSign.public_id ?? null,
      apiKey: env.CLOUDINARY_API_KEY,
      cloudName: env.CLOUDINARY_CLOUD_NAME,
      uploadUrl: `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/upload`,
    });
  } catch (e) {
    next(e);
  }
}

function _folderFor(purpose: 'listing' | 'avatar' | 'review', userId: string): string {
  switch (purpose) {
    case 'listing':
      // Products aren't created yet at signature time, so we scope by owner.
      // The client can move the media into a product-scoped folder later,
      // but for MVP the flat owner-scoped folder is fine.
      return `products/${userId}`;
    case 'avatar':
      return `users/${userId}/avatar`;
    case 'review':
      return `reviews/${userId}`;
  }
}
