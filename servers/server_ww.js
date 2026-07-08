const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const express = require('express');

const app = express();
app.use(express.json());

// CORS — allow Flutter Web (Chrome) to call this server
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

const client = new Client({
    authStrategy: new LocalAuth({ dataPath: './.wwebjs_auth' }),
    puppeteer: {
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage', // IMPORTANT FOR LINUX/VPS
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu'
        ]
    }
});

let isReady = false;

client.on('qr', (qr) => {
    console.log('SCAN THIS QR CODE WITH YOUR WHATSAPP:');
    qrcode.generate(qr, { small: true });
});

client.on('ready', () => {
    console.log('WhatsApp Bot (whatsapp-web.js) Ready!');
    isReady = true;
});

client.on('disconnected', (reason) => {
    console.log('Client was logged out', reason);
    isReady = false;
});

client.initialize();

app.post('/send', async (req, res) => {
    if (!isReady) {
        return res.status(503).json({ success: false, error: 'WhatsApp client is not ready yet.' });
    }

    try {
        const { phone, message } = req.body;
        
        if (!phone || !message) {
            return res.status(400).json({ success: false, error: 'Phone and message are required.' });
        }

        const formattedPhone = `${phone}@c.us`;
        await client.sendMessage(formattedPhone, message);
        console.log(`[Outgoing] Successfully sent to ${phone}!`);
        
        res.json({ success: true });
    } catch (error) {
        console.error('[Error sending message]', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`KeepSIMs whatsapp-web.js Express server running on port ${PORT}`);
});
