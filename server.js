const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const qrcode = require('qrcode-terminal');

const app = express();
app.use(express.json());

const client = new Client({ authStrategy: new LocalAuth() });

// Show QR in terminal on first run — scan with your phone
client.on('qr', qr => qrcode.generate(qr, { small: true }));
client.on('ready', () => console.log('WhatsApp ready!'));
client.initialize();

// Single endpoint: POST { phone, message }
app.post('/send', async (req, res) => {
  const { phone, message } = req.body;
  try {
    // phone format: country code + number, e.g. "96891234567"
    const chatId = `${phone}@c.us`;
    await client.sendMessage(chatId, message);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

app.listen(3000, () => console.log('Server running on port 3000'));