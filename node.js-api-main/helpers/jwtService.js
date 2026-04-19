const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const RefreshToken = require('../models/RefreshToken');

function generateToken(user) {
  const payload = {
    sub: user.email,
    id: user._id.toString(),
    role: user.role,
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    issuer: process.env.JWT_ISSUER,
    audience: process.env.JWT_AUDIENCE,
    expiresIn: '1d',
  });
}

/**
 * Opaque refresh token üretir ve veritabanına kaydeder.
 * @returns {string} refresh token
 */
async function generateRefreshToken(userId) {
  const token = crypto.randomBytes(40).toString('hex');
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 gün

  await RefreshToken.create({ token, userId, expiresAt });
  return token;
}

/**
 * Login/register sonrası JWT + refresh token çifti üretir.
 */
async function generateTokenPair(user) {
  const accessToken = generateToken(user);
  const refreshToken = await generateRefreshToken(user._id);
  return { accessToken, refreshToken };
}

module.exports = { generateToken, generateRefreshToken, generateTokenPair };
