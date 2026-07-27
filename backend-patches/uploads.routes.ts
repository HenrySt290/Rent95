// Add this file to your rent95-api under: src/routes/uploads.routes.ts
//
// Then in src/app.ts:
//   import uploadsRoutes from './routes/uploads.routes';
//   app.use('/api/uploads', uploadsRoutes);

import { Router } from 'express';
import * as uploadsController from '../controllers/uploads.controller';
import { requireAuth } from '../middleware/auth';
import rateLimit from 'express-rate-limit';

// Signatures are cheap to generate but each one is essentially a free upload
// slot at Cloudinary — cap the rate to something well above legitimate use
// but low enough to make abuse obvious.
const signatureLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many upload requests. Slow down and try again.' },
});

const router: Router = Router();
router.post('/signature', requireAuth, signatureLimiter, uploadsController.createSignature);

export default router;
