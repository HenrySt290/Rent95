// Add these routes to your rent95-api under: src/routes/user.routes.ts
// (or wherever your `/api/users/*` router lives).
//
// If you don't yet have a user.routes.ts, drop this snippet into src/app.ts
// alongside the other `app.use('/api/...', ...)` calls.

import { Router } from 'express';
import * as deviceTokenController from '../controllers/device-token.controller';
import { requireAuth } from '../middleware/auth';

const router: Router = Router();

// FCM device tokens — see mobile app's PushRegistrar.
router.post('/device-token', requireAuth, deviceTokenController.register);
router.delete('/device-token', requireAuth, deviceTokenController.revoke);

export default router;

// Then in src/app.ts:
//   import userRoutes from './routes/user.routes';
//   app.use('/api/users', userRoutes);
