const twilio = require('twilio');

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken  = process.env.TWILIO_AUTH_TOKEN;
const fromNumber = process.env.TWILIO_PHONE_NUMBER;

const client = twilio(accountSid, authToken);

async function sendSMS(phone, code) {   // ← burada sendSMS
  try {
    const message = await client.messages.create({
      body: `Randevu doğrulama kodunuz: ${code}`,
      from: fromNumber,
      to: phone
    });
    return message;
  } catch (err) {
    console.error('SMS gönderilemedi:', err);
    throw err;
  }
}

module.exports = { sendSMS };   // ← exportta da sendSMS
