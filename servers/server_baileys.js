/**
 * KeepSIMs WhatsApp Bot Server (Baileys Edition)
 * 
 * Uses @whiskeysockets/baileys which connects directly to WhatsApp's 
 * WebSocket protocol — NO Chrome/Puppeteer needed.
 * RAM usage: ~30MB vs 500MB+ with whatsapp-web.js
 */
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, makeCacheableSignalKeyStore } = require('@whiskeysockets/baileys');
const pino = require('pino');
const express = require('express');
const qrcode = require('qrcode-terminal');
require('dotenv').config({ path: require('path').join(__dirname, '.env') });

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


// Supabase Configuration
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !supabaseKey) { console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in servers/.env'); process.exit(1); }

/**
 * Shared helper to send authorized REST requests to Supabase
 */
async function supabaseRequest(path, options = {}) {
  const url = `${supabaseUrl}/rest/v1/${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...(options.headers || {})
    }
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Supabase REST Error (${response.status}): ${errText}`);
  }

  return response.json();
}

/**
 * Normalize phone numbers to a standardized sequence of digits
 */
function normalizePhoneNumber(raw) {
  if (!raw) return '';
  let clean = raw.split('@')[0];
  clean = clean.replace(/\D/g, '');
  if (clean.startsWith('00')) clean = clean.substring(2);
  if (clean.startsWith('0')) clean = clean.substring(1);
  return clean;
}

/**
 * Core Business Logic: Processes offline refill requests from SMS or WhatsApp
 */
async function processOfflineRefill({ sender, channel }) {
  const normalized = normalizePhoneNumber(sender);
  console.log(`[Offline Refill] Processing request from ${sender} (${normalized}) via ${channel}`);

  if (!normalized) {
    return '⚠️ SIM Shield Alert: Unable to identify your phone number format.';
  }

  // 1. Authenticate user by phone number
  let settingsList = await supabaseRequest(`offline_refill_settings?custom_phone_number=ilike.*${normalized}*&select=*,profiles(*)`);
  let settings = settingsList && settingsList[0];

  if (!settings) {
    const profiles = await supabaseRequest(`profiles?phone=ilike.*${normalized}*&select=*`);
    if (profiles && profiles.length > 0) {
      const profile = profiles[0];
      const checkSettings = await supabaseRequest(`offline_refill_settings?user_id=eq.${profile.id}&select=*`);
      settings = checkSettings && checkSettings[0] 
        ? { ...checkSettings[0], profiles: profile } 
        : { user_id: profile.id, is_enabled: true, profiles: profile };
    }
  }

  if (!settings || !settings.profiles) {
    return `🔒 *SIM Shield Assistant* 🔒\n\nHello! We received an offline request from this number, but we couldn't find a registered SIM Shield account with an active Premium subscription associated with this number.\n\nOffline Refill is a premium feature allowing you to restore data/minutes with zero connection. Please register this phone number under your profile and upgrade to Premium inside the app!`;
  }

  const userId = settings.user_id;
  const profile = settings.profiles;

  // 2. Validate Premium subscription
  if (profile.subscription_tier !== 'premium') {
    return `🔒 *SIM Shield Assistant* 🔒\n\nHi ${profile.full_name || 'User'},\nOffline Refill is exclusive to Premium subscription tiers. Upgrade in the app to access offline refills via SMS/WhatsApp!`;
  }

  // 4. Identify target SIM line
  let targetSimLineId = settings.target_sim_line_id;
  let simLine;

  if (!targetSimLineId) {
    const simLines = await supabaseRequest(`sim_lines?user_id=eq.${userId}&status=eq.active&select=*`);
    if (simLines && simLines.length > 0) {
      simLine = simLines[0];
    }
  } else {
    const simLines = await supabaseRequest(`sim_lines?id=eq.${targetSimLineId}&select=*`);
    if (simLines && simLines.length > 0) {
      simLine = simLines[0];
    }
  }

  if (!simLine) {
    return `⚠️ *SIM Shield Offline Refill* ⚠️\n\nHi ${profile.full_name || 'User'},\nWe couldn't identify a target SIM line to refill. Please configure your default target SIM in the SIM Shield Console.`;
  }

  // 5. Check Wallet Balance
  const wallets = await supabaseRequest(`wallets?user_id=eq.${userId}&select=*`);
  if (!wallets || wallets.length === 0) {
    return `⚠️ *SIM Shield Offline Refill* ⚠️\n\nRefill failed: Wallet not found. Please log in to the app to sync your wallet.`;
  }

  const wallet = wallets[0];
  const refillAmount = parseFloat(settings.default_refill_amount || 10.00);

  if (parseFloat(wallet.balance) < refillAmount) {
    return `⚠️ *SIM Shield Offline Refill Failed* ⚠️\n\nHi ${profile.full_name || 'User'},\nYou requested an offline refill of $${refillAmount.toFixed(2)} USD, but your current wallet balance is only $${parseFloat(wallet.balance).toFixed(2)} USD.\n\nPlease top up your wallet in the SIM Shield app when you have connection, or enable Auto-Fund.`;
  }

  // 6. Perform Refill Transactions
  const newBalance = parseFloat(wallet.balance) - refillAmount;

  // Step 6a: Update wallet balance
  await supabaseRequest(`wallets?id=eq.${wallet.id}`, {
    method: 'PATCH',
    body: JSON.stringify({ balance: newBalance, updated_at: new Date().toISOString() })
  });

  // Step 6b: Insert wallet transaction
  await supabaseRequest('wallet_transactions', {
    method: 'POST',
    body: JSON.stringify({
      wallet_id: wallet.id,
      user_id: userId,
      amount: refillAmount,
      balance_before: parseFloat(wallet.balance),
      balance_after: newBalance,
      type: 'topup_debit',
      description: `Offline Balance Refill via ${channel}`,
      reference_id: `offline_refill_${channel.toLowerCase()}_${Date.now()}`
    })
  });

  // Step 6c: Log the Top-Up Execution
  await supabaseRequest('topup_executions', {
    method: 'POST',
    body: JSON.stringify({
      sim_line_id: simLine.id,
      user_id: userId,
      amount: refillAmount,
      currency: 'USD',
      status: 'success',
      validity_days_added: 30,
      executed_at: new Date().toISOString()
    })
  });

  // Step 6d: Extend SIM Line Validity
  const currentValidity = simLine.validity_expires_at ? new Date(simLine.validity_expires_at) : new Date();
  const extendedValidity = new Date(currentValidity.getTime() + 30 * 24 * 60 * 60 * 1000);
  await supabaseRequest(`sim_lines?id=eq.${simLine.id}`, {
    method: 'PATCH',
    body: JSON.stringify({
      last_topup_at: new Date().toISOString(),
      validity_expires_at: extendedValidity.toISOString(),
      status: 'active',
      updated_at: new Date().toISOString()
    })
  });

  // Step 6e: Log Line Activity
  await supabaseRequest('line_activity_log', {
    method: 'POST',
    body: JSON.stringify({
      sim_line_id: simLine.id,
      user_id: userId,
      activity_type: 'refill',
      description: `Offline balance refill of $${refillAmount.toFixed(2)} USD via ${channel}`,
      status: 'success'
    })
  });

  // 7. Dynamic USSD Suggestion Lookup
  let ussdGuideSection = '';
  if (simLine.carrier_id) {
    const suggestions = await supabaseRequest(`carrier_ussd_suggestions?carrier_id=eq.${simLine.carrier_id}&select=*`);
    if (suggestions && suggestions.length > 0) {
      ussdGuideSection = `\n📲 *How to Activate your Data+Call Pack:*\nTo activate your plan using your new SIM balance, dial:\n`;
      suggestions.forEach(s => {
        ussdGuideSection += `👉 *${s.plan_name}* ($${parseFloat(s.cost).toFixed(2)}): Dial **${s.ussd_code}**\n`;
      });
    }
  }

  // 8. Return Success response string
  return `🎉 *SIM Shield Offline Refill Successful!* 🎉\n\nHi ${profile.full_name || 'Premium User'},\nWe have successfully refilled **$${refillAmount.toFixed(2)} USD** cash onto your SIM +${simLine.phone_number}.\n\n💵 *Deducted from Wallet:* $${refillAmount.toFixed(2)} USD\n👛 *Remaining Wallet Balance:* $${newBalance.toFixed(2)} USD\n${ussdGuideSection}\nThank you for choosing SIM Shield Premium!`;
}

// ============================================================
// Baileys WhatsApp Connection (NO Chrome/Puppeteer needed!)
// ============================================================

let sock;
let isReady = false;
let currentQr = null;

// --- Anti-Ban Queue System ---
const messageQueue = [];
let isProcessingQueue = false;

// Helper: random delay
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function processMessageQueue() {
  if (isProcessingQueue || messageQueue.length === 0) return;
  isProcessingQueue = true;

  while (messageQueue.length > 0) {
    if (!isReady) {
      console.log("[Queue] Paused processing because WhatsApp is not ready.");
      break;
    }

    const { jid, phone, message } = messageQueue.shift();

    try {
      console.log(`[Queue] Processing message for ${phone}...`);
      
      // Simulate "Typing..." presence
      await sock.sendPresenceUpdate('composing', jid);
      
      // Random delay between 2 to 5 seconds to simulate human typing time
      const typingTime = Math.floor(Math.random() * (5000 - 2000 + 1)) + 2000;
      await delay(typingTime);

      // Stop typing and send
      await sock.sendPresenceUpdate('paused', jid);
      await sock.sendMessage(jid, { text: message });
      
      console.log(`[Queue] Successfully sent to ${phone}!`);
      
      // Random wait before processing the NEXT message in the queue (3 to 8 seconds)
      const interMessageDelay = Math.floor(Math.random() * (8000 - 3000 + 1)) + 3000;
      if (messageQueue.length > 0) {
         console.log(`[Queue] Waiting ${interMessageDelay}ms before next message to avoid spam detection...`);
         await delay(interMessageDelay);
      }

    } catch (e) {
      console.error(`[Queue Error] Failed to send to ${phone}:`, e);
    }
  }

  isProcessingQueue = false;
}

async function connectWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState('./.baileys_auth');

  sock = makeWASocket({
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
    },
    printQRInTerminal: true,
    logger: pino({ level: 'silent' }),
    browser: ['KeepSIMs Bot', 'Chrome', '120.0.0'],
  });

  // Save credentials whenever they update
  sock.ev.on('creds.update', saveCreds);

  // Connection updates
  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      currentQr = qr;
      console.log('\n📱 Scan this QR code with WhatsApp:');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'close') {
      isReady = false;
      currentQr = null;
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
      
      if (statusCode === 401 || statusCode === 403) {
        console.error(`🚨 [CRITICAL ANTI-BAN ALERT] WhatsApp session was invalidated or banned! Status: ${statusCode}`);
        console.error('Do NOT restart aggressively. You must inspect the number manually in the WhatsApp app.');
        return; // Prevent auto-reconnect loops that worsen the ban
      }

      console.log(`[WhatsApp] Connection closed. Status: ${statusCode}. Reconnecting: ${shouldReconnect}`);
      
      if (shouldReconnect) {
        setTimeout(() => connectWhatsApp(), 5000);
      } else {
        console.log('[WhatsApp] Logged out. Delete .baileys_auth folder and restart to re-scan QR.');
      }
    }

    if (connection === 'open') {
      isReady = true;
      currentQr = null;
      console.log('WhatsApp Bot Ready!');
      // Resume queue if there are pending messages
      if (messageQueue.length > 0) {
        processMessageQueue();
      }
    }
  });

  // Listen for incoming messages
  sock.ev.on('messages.upsert', async (m) => {
    if (m.type !== 'notify') return;

    for (const msg of m.messages) {
      if (msg.key.fromMe) continue; // Skip our own messages

      const body = (msg.message?.conversation || msg.message?.extendedTextMessage?.text || '').trim().toLowerCase();
      const sender = msg.key.remoteJid;

      if (!body || !sender) continue;

      // Handle "status" command
      if (body === 'status' || body === 'حالة') {
        try {
          const simCards = await supabaseRequest('sim_cards?select=phone_number,carrier,status,balance,balance_updated_at&order=phone_number');

          let reply = '📊 *SIM Card Status Report*\n\n';
          for (const sim of simCards) {
            const status = sim.status === 'active' ? '🟢' : '🔴';
            reply += `${status} *${sim.phone_number}* (${sim.carrier})\n`;
            reply += `   Balance: ${sim.balance ?? 'N/A'}\n`;
            reply += `   Updated: ${sim.balance_updated_at ? new Date(sim.balance_updated_at).toLocaleString() : 'Never'}\n\n`;
          }

          await sock.sendMessage(sender, { text: reply });
        } catch (e) {
          await sock.sendMessage(sender, { text: '❌ Error fetching status: ' + e.message });
        }
      }

      // Handle offline refill commands
      if (body === 'refill' || body === 'recharge' || body === 'offline recharge' || body === 'offline refill') {
        try {
          const response = await processOfflineRefill({
            sender: sender,
            channel: 'WhatsApp'
          });
          await sock.sendMessage(sender, { text: response });
        } catch (err) {
          console.error('[WhatsApp Message Error]', err);
          await sock.sendMessage(sender, { text: `⚠️ SIM Shield Offline Refill Error: ${err.message}` });
        }
      }
    }
  });
}

// Start WhatsApp connection
connectWhatsApp();

/**
 * Endpoint: POST /send (Queues an outbound message to a specific WhatsApp number)
 * Payload: { phone, message }
 */
app.post('/send', async (req, res) => {
  const apiKey = req.headers['x-api-key'] || req.headers['x-keep-sims-secret'];
  const API_SECRET = process.env.API_SECRET;
  if (apiKey !== API_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid API Key' });
  }

  const { phone, message } = req.body;
  try {
    if (!isReady) {
      console.log(`[Outgoing Message] Bot not ready yet, rejecting request for ${phone}`);
      return res.status(503).json({ success: false, error: 'WhatsApp bot is still initializing. Please wait.' });
    }
    
    const jid = `${phone}@s.whatsapp.net`;
    
    // Add to anti-ban queue
    messageQueue.push({ jid, phone, message });
    console.log(`[Outgoing Message] Added to queue for ${phone}. Queue length: ${messageQueue.length}`);
    
    // Trigger queue processing asynchronously
    processMessageQueue();
    
    res.json({ success: true, queued: true });
  } catch (e) {
    console.error(`[Outgoing Message Error] Failed to queue for ${phone}:`, e);
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * Endpoint: POST /sms/receive (Simulates an incoming SMS message webhook)
 * Payload: { sender, message }
 */
app.post('/sms/receive', async (req, res) => {
  const { sender, message } = req.body;
  const body = (message || '').trim().toLowerCase();

  if (body === 'refill' || body === 'recharge' || body === 'offline recharge' || body === 'offline refill') {
    try {
      const response = await processOfflineRefill({
        sender: sender,
        channel: 'SMS'
      });
      res.json({ success: true, reply: response });
    } catch (err) {
      console.error('[SMS Processing Error]', err);
      res.status(500).json({ success: false, error: err.message });
    }
  } else {
    res.json({ success: true, reply: 'SIM Shield SMS Ingestion Active. Text REFILL to trigger an offline refill.' });
  }
});

/**
 * Endpoint: GET /qr (Expose QR Code for scanning)
 */
app.get('/qr', (req, res) => {
  if (isReady) {
    return res.send('<h1>WhatsApp is already connected!</h1>');
  }
  if (!currentQr) {
    return res.send('<h1>No QR code available. Please wait or check if the session is logged out.</h1>');
  }
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(currentQr)}`;
  res.send(`
    <html>
      <head>
        <title>Scan WhatsApp QR Code</title>
        <meta http-equiv="refresh" content="5">
      </head>
      <body style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100vh; font-family:sans-serif; background-color:#121212; color:white;">
        <h1>KeepSIMs WhatsApp Setup</h1>
        <p>Scan this QR code with your WhatsApp app:</p>
        <div style="background: white; padding: 20px; border-radius: 10px;">
          <img src="${qrUrl}" alt="WhatsApp QR Code" />
        </div>
        <p style="color:#888; margin-top:20px;">This page will auto-refresh every 5 seconds. If scanned successfully, it will show "WhatsApp is already connected!"</p>
      </body>
    </html>
  `);
});

/**
 * Endpoint: POST /logout (Logs out current WhatsApp session and deletes authentication credentials)
 */
app.post('/logout', async (req, res) => {
  const apiKey = req.headers['x-api-key'] || req.headers['x-keep-sims-secret'];
  const API_SECRET = process.env.API_SECRET;
  if (apiKey !== API_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid API Key' });
  }

  console.log('[WhatsApp Logout] Logout requested.');
  try {
    isReady = false;
    currentQr = null;

    if (sock) {
      try {
        await sock.logout();
      } catch (e) {
        console.log('[WhatsApp Logout] Socket logout failed or already disconnected:', e.message);
      }
      try {
        sock.end();
      } catch (e) {
        // ignore
      }
    }

    // Delete credentials folder to force new QR code on restart
    const fs = require('fs');
    const path = require('path');
    const authDir = path.join(__dirname, '.baileys_auth');
    if (fs.existsSync(authDir)) {
      fs.rmSync(authDir, { recursive: true, force: true });
      console.log('[WhatsApp Logout] Auth credentials directory deleted.');
    }

    // Reinitialize WhatsApp socket after a small delay
    setTimeout(() => {
      connectWhatsApp();
    }, 2000);

    res.json({ success: true, message: 'WhatsApp session logged out and reset successfully.' });
  } catch (e) {
    console.error('[WhatsApp Logout Error] Failed:', e);
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * Endpoint: GET /health (Health check)
 */
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    whatsapp: isReady ? 'connected' : 'disconnected',
    qr: currentQr,
    phone: isReady && sock?.user?.id ? sock.user.id.split(':')[0].split('@')[0] : null,
    uptime: process.uptime()
  });
});

app.listen(3000, () => console.log('Server running on port 3000'));