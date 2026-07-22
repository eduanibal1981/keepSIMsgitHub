# Product Requirements Document (PRD) - KeepSIMs Core v2.0

## 1. Product Overview
**Product Name:** KeepSIMs Core
**Platform:** Mobile Application (iOS & Android via Flutter)
**Target Audience:** Tech-savvy global travelers, digital nomads, expatriates, and enterprise SIM managers who value speed, clarity, and a premium digital experience.
**Product Purpose:** KeepSIMs is a centralized, high-performance platform designed to simplify the management, top-up, and monitoring of multiple SIM cards. It acts as a "SIM Shield" to protect expat SIM cards from deactivation, enabling users to track data usage, automate recharges, and manage expenses securely.

## 2. Pain Points Solved
*   **SIM Deactivation Anxiety:** Expats and travelers losing their home country numbers due to missed top-ups.
*   **Pricing Opacity:** Hidden fees and markup ambiguity when recharging international lines.
*   **Low-Connectivity Top-Ups:** Struggling to buy data or top-up when the internet connection is weak or non-existent.
*   **Fragmented Management:** Juggling different carrier apps and tracking multiple data balances across family members or enterprise departments.

## 3. Core Features & Capabilities

### 3.1. Advanced SIM Management & Protection
*   **Line Overview:** Add, remove, and monitor multiple SIM lines globally.
*   **Home-Mode Decoupling:** Protection status is decoupled from physical location. A user can reside in the SIM's home country but still maintain "Protection" rules.
*   **Status Tracking:** Visual indicators for SIM status (Active, Low Data, Expired).

### 3.2. Wallet, Ledger & Payments
*   **Digital Wallet:** In-app wallet to hold funds for friction-free, zero-fee top-ups.
*   **Server-Side Pricing & Ledger:** All money paths are strictly server-side. Pricing is computed from a live, cached Zendit catalog and gateway fees table.
*   **Atomic Transactions:** Wallet deducts/refunds and ledger insertions happen atomically. A double-charge is impossible.
*   **PayPal Integration:** Secure deposits and plan payments verified via backend webhooks acting as the absolute source of truth.

### 3.3. Refill Engine (Instant, Scheduled, Premium)
*   **Instant Refill:** Pay-as-you-go manual top-ups directly from the wallet or external gateways.
*   **Custom Scheduled Refills:** User-defined automated recharges on specific dates or thresholds.
*   **Premium Auto-Mini Refills:** Background workers execute small, continuous top-ups (pre-paid yearly) to keep lines active without user intervention.

### 3.4. Offline Recharge & Connectivity Fallbacks
*   **Offline Mode:** Deeply cached carrier rules and catalogs allow the app to function offline.
*   **Alternative Channels:** Dedicated SMS, IVR, and WhatsApp channels configured via backend systems to trigger top-ups when internet access drops.

### 3.5. Smart Notifications & Alert Preferences
*   **Unified Dispatcher:** Omni-channel notification system routing through OneSignal, with FCM and Email fallbacks.
*   **Granular Preferences:** Users can toggle specific alert categories (e.g., top-up success/failure, wallet low, line critical, geo-fence, promo) natively inside the app.

## 4. Product Tiers & Pricing Model (Database-Driven)
*   **Standard Plan (Pay-As-You-Go):** $2.50/yr base service fee per line. Refills are charged dynamically at base cost + app fee + gateway fees. Wallet refills incur 0% gateway fees.
*   **Premium Plan (Pre-paid Auto-Refill):** Pre-paid annually. Includes the base service fee plus the upfront cost of all scheduled mini-refills needed to keep the line alive for a year. Auto-mini worker processes these without per-execution wallet debits.

## 5. Technical Architecture & Security

### 5.1. Frontend
*   **Framework:** Flutter (Dart 3+) with Riverpod state management.
*   **Design Aesthetic:** "High-Tech Utility" utilizing glassmorphism, dark mode, and fluid grids. Neon Cyan/Green/Amber accents for statuses.

### 5.2. Backend & Database
*   **Platform:** Supabase (PostgreSQL).
*   **Security (RLS):** Strict Row Level Security. Clients have read-only access to execution and transaction tables. All writes occur via `SECURITY DEFINER` RPCs or edge functions.
*   **Dynamic Configurations:** Fees, margins, and operational toggles are stored in `system_configs`, `payment_gateways`, and `carrier_rules`—changeable without app redeploys.

### 5.3. Worker Ecosystem
*   **Node.js/PM2 Workers (VM-Hosted):** Dedicated daemon workers manage the queues securely:
    *   `worker_instant_refill.js`
    *   `worker_auto_mini_refill.js`
    *   `worker_auto_custom_refill.js`
*   **Offer Validation:** Workers cross-reference requested offers against cached catalogs to ensure exact price matching and prevent client-side manipulation.

## 6. Success Metrics
*   **System Reliability:** 0% double charges and seamless handling of edge cases (failed top-ups correctly refunded atomically).
*   **Transaction Friction:** Minimized steps to recharge; instant, accurate server-side pricing.
*   **User Engagement:** High reliance on the app's dashboard metrics and automated protection services.
