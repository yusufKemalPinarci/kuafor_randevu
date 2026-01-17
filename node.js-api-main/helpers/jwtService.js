const jwt = require('jsonwebtoken');

function generateToken(user) {
  const payload = {
    sub: user.email,
    id: user._id.toString(),
    role: user.role,
    jti: require('crypto').randomBytes(16).toString('hex'),
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    issuer: process.env.JWT_ISSUER,
    audience: process.env.JWT_AUDIENCE,
    expiresIn: `${process.env.JWT_EXPIRE_DAYS}d`,
  });
}

module.exports = { generateToken };
