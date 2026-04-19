const { Subscription } = require('../models/Subscription');
const { UserRole } = require('../models/User');

/**
 * Middleware: Berberin dükkanının aktif aboneliği olup olmadığını kontrol eder.
 * authMiddleware'den SONRA kullanılmalıdır (req.user gerekli).
 *
 * Kullanım:
 *   router.post('/some-premium-route', authMiddleware, subscriptionMiddleware, handler);
 */
const subscriptionMiddleware = async (req, res, next) => {
  try {
    const user = req.user;
    if (!user) return res.status(401).json({ error: 'Oturum gerekli.' });

    // Müşteriler için abonelik kontrolü gerekmez
    if (user.role === UserRole.CUSTOMER) return next();

    const shopId = user.shopId;
    if (!shopId) {
      return res.status(403).json({ error: 'Abonelik kontrolü için bir dükkana bağlı olmalısınız.' });
    }

    const now = new Date();
    const sub = await Subscription.findOne({
      shopId,
      status: 'active',
      endDate: { $gt: now },
    });

    if (!sub) {
      return res.status(403).json({
        error: 'Bu özelliği kullanmak için aktif bir aboneliğe ihtiyacınız var.',
        code: 'SUBSCRIPTION_REQUIRED',
      });
    }

    req.subscription = sub;
    next();
  } catch (err) {
    res.status(500).json({ error: 'Abonelik kontrol edilemedi.' });
  }
};

module.exports = subscriptionMiddleware;
