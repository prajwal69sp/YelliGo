import { Router } from 'express';
import { pool } from '../db/pool';
import { getAllDriverPositions } from '../redis/geo.service';

export const adminRouter = Router();

/**
 * GET /admin/stats/summary
 * High-level counters for the dashboard header cards.
 */
adminRouter.get('/stats/summary', async (_req, res) => {
  try {
    const [ridesToday, revenueToday, statusBreakdown, driverCounts] = await Promise.all([
      pool.query(
        `SELECT COUNT(*)::int AS count FROM rides WHERE requested_at::date = now()::date`
      ),
      pool.query(
        `SELECT COALESCE(SUM(fare_final), 0)::float AS total
         FROM rides
         WHERE status = 'COMPLETED' AND completed_at::date = now()::date`
      ),
      pool.query(
        `SELECT status, COUNT(*)::int AS count
         FROM rides
         WHERE requested_at::date = now()::date
         GROUP BY status`
      ),
      pool.query(
        `SELECT status, COUNT(*)::int AS count FROM drivers GROUP BY status`
      ),
    ]);

    res.json({
      rides_today: ridesToday.rows[0].count,
      revenue_today: revenueToday.rows[0].total,
      ride_status_breakdown: statusBreakdown.rows,
      driver_status_breakdown: driverCounts.rows,
    });
  } catch (err) {
    console.error('[admin/stats/summary] error:', err);
    res.status(500).json({ error: 'Failed to load summary stats' });
  }
});

/**
 * GET /admin/drivers/live
 * Live positions from Redis GEO, for the map view.
 */
adminRouter.get('/drivers/live', async (_req, res) => {
  try {
    const positions = await getAllDriverPositions();
    res.json({ drivers: positions });
  } catch (err) {
    console.error('[admin/drivers/live] error:', err);
    res.status(500).json({ error: 'Failed to load live driver positions' });
  }
});

/**
 * GET /admin/rides/recent?limit=20
 */
adminRouter.get('/rides/recent', async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 20, 100);
    const result = await pool.query(
      `SELECT r.id, r.status, r.fare_estimated, r.fare_final, r.payment_method,
              r.requested_at, r.completed_at,
              u.full_name AS passenger_name,
              du.full_name AS driver_name
       FROM rides r
       JOIN users u ON u.id = r.passenger_id
       LEFT JOIN drivers d ON d.id = r.driver_id
       LEFT JOIN users du ON du.id = d.user_id
       ORDER BY r.requested_at DESC
       LIMIT $1`,
      [limit]
    );
    res.json({ rides: result.rows });
  } catch (err) {
    console.error('[admin/rides/recent] error:', err);
    res.status(500).json({ error: 'Failed to load recent rides' });
  }
});

/**
 * GET /admin/drivers/pending
 * Drivers awaiting document verification.
 */
adminRouter.get('/drivers/pending', async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT d.id, u.full_name, u.phone_number, d.license_number, d.license_expiry, d.created_at
       FROM drivers d
       JOIN users u ON u.id = d.user_id
       WHERE d.is_document_verified = false
       ORDER BY d.created_at ASC`
    );
    res.json({ drivers: result.rows });
  } catch (err) {
    console.error('[admin/drivers/pending] error:', err);
    res.status(500).json({ error: 'Failed to load pending drivers' });
  }
});

/**
 * PATCH /admin/drivers/:id/verify
 */
adminRouter.patch('/drivers/:id/verify', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE drivers SET is_document_verified = true WHERE id = $1 RETURNING id`,
      [req.params.id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    res.json({ id: req.params.id, is_document_verified: true });
  } catch (err) {
    console.error('[admin/drivers/:id/verify] error:', err);
    res.status(500).json({ error: 'Failed to verify driver' });
  }
});
