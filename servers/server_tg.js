/**
 * KeepSIMs Telegram Bot Daemon
 * 
 * Uses raw Node.js fetch to long-poll the Telegram API.
 * Securely binds users to their chat IDs using a Security Definer RPC function.
 * Zero heavy dependencies (no telegraf/node-telegram-bot-api required).
 */

require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zwxswagokhgbuzrrbnhr.supabase.co';
// We use the SAFE public ANON_KEY because our RPC function is SECURITY DEFINER
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;

if (!SUPABASE_KEY || !TELEGRAM_BOT_TOKEN) {
    console.error("🚨 Missing required environment variables: SUPABASE_KEY or TELEGRAM_BOT_TOKEN.");
    process.exit(1);
}

const TG_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;
let updateOffset = 0;

/**
 * Sends a message back to the user via Telegram
 */
async function sendTelegramMessage(chatId, text) {
    try {
        await fetch(`${TG_API}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                chat_id: chatId,
                text: text,
                parse_mode: 'Markdown'
            })
        });
    } catch (err) {
        console.error(`[Telegram] Error sending message to ${chatId}:`, err);
    }
}

/**
 * Binds the Telegram Chat ID to the User ID via the Secure Supabase RPC
 */
async function bindUserToChat(userId, chatId) {
    const url = `${SUPABASE_URL}/rest/v1/rpc/bind_telegram_bot`;
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        },
        body: JSON.stringify({
            p_user_id: userId,
            p_chat_id: String(chatId)
        })
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Supabase RPC failed (${response.status}): ${errText}`);
    }
}

/**
 * Processes a single Telegram Update
 */
async function handleUpdate(update) {
    const message = update.message;
    if (!message || !message.text) return;

    const text = message.text.trim();
    const chatId = message.chat.id;

    // We check if the message matches our deep link command: /start bind_USERID
    // The Telegram app passes the parameter exactly like that when opened from a link: t.me/Bot?start=bind_USERID
    const bindRegex = /^\/start\s+bind_([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/i;
    const match = text.match(bindRegex);

    if (match) {
        const userId = match[1];
        console.log(`[Bot] Received bind request. Linking User ID: ${userId} to Chat ID: ${chatId}`);

        try {
            await bindUserToChat(userId, chatId);
            console.log(`[Bot] Successfully bound User ${userId} to Chat ${chatId}.`);
            await sendTelegramMessage(
                chatId, 
                "✅ *Success!*\n\nYour account has been securely linked. You will now receive important SIM Shield notifications directly in this chat."
            );
        } catch (err) {
            console.error(`[Bot] Failed to bind user ${userId}:`, err);
            await sendTelegramMessage(
                chatId, 
                "❌ *Error linking account.*\n\nPlease try clicking the link from the KeepSIMs app again. If the issue persists, contact support."
            );
        }
    } else if (text === '/start') {
        await sendTelegramMessage(
            chatId,
            "👋 Welcome to the *KeepSIMs Shield Bot*!\n\nTo link your account and receive interactive notifications here, please initiate the linking process directly from the **Notification Settings** inside your KeepSIMs app."
        );
    }
}

/**
 * Long-polling loop to constantly listen for new Telegram messages
 */
async function pollTelegramUpdates() {
    try {
        const response = await fetch(`${TG_API}/getUpdates?offset=${updateOffset}&timeout=30`);
        if (response.ok) {
            const data = await response.json();
            if (data.ok && data.result) {
                for (const update of data.result) {
                    updateOffset = update.update_id + 1;
                    await handleUpdate(update);
                }
            }
        }
    } catch (err) {
        // Suppress network timeout errors since it's normal for long-polling
        if (!err.message.includes('timeout') && !err.message.includes('fetch')) {
            console.error("[Bot] Polling error:", err.message);
        }
    }

    // Schedule next poll immediately
    setTimeout(pollTelegramUpdates, 1000);
}

// Start daemon
console.log("🚀 KeepSIMs Telegram Bot Daemon is starting...");
console.log("Listening for /start bind_ requests...");
pollTelegramUpdates();
