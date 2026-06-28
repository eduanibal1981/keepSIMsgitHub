# Product Specification Document (PRD)

## 1. Product Overview
**Product Name:** KeepSIMs Core
**Platform:** Mobile Application (iOS & Android via Flutter)
**Target Audience:** Tech-savvy global travelers and enterprise SIM managers who value speed, clarity, and a premium digital experience.
**Product Purpose:** KeepSIMs is a centralized, high-performance platform designed to simplify the management, top-up, and monitoring of multiple SIM cards. It enables individuals, families, and businesses to track data usage, automate recharges, and manage expenses seamlessly from a single, intuitive interface.

## 2. Design Aesthetic & User Experience
The app features a **"High-Tech Utility"** design language, utilizing a glassmorphism and dark mode aesthetic.
* **Atmosphere:** Sophisticated, nocturnal, and futuristic (neon cyan, green, and amber accents against deep black-gray backgrounds).
* **Usability:** Emphasis on legibility with specific typography for numeric data. Data should be easy to digest at a glance via fluid grids and high-contrast status chips.

## 3. Core Features & Capabilities

### 3.1. SIM Management (`sim_lines`)
* **Line Overview:** Add, remove, and monitor multiple SIM lines.
* **Status Tracking:** Visual indicators for SIM status (e.g., Active [Neon Green], Low Data [Neon Amber], Expired).
* **Data & Usage Monitoring:** Real-time visibility into data balances and expiration dates.

### 3.2. Dashboard (`dashboard`)
* **Centralized View:** High-level summary of all active SIMs, total data consumption, and pending alerts.
* **Analytics:** Visual charts mapping usage trends.

### 3.3. Wallet & Payments (`wallet`, `payments`, `topup`)
* **Digital Wallet:** In-app wallet to hold funds for instant, friction-free transactions.
* **Top-ups:** Add credit or data plans to any connected SIM card directly through the app.
* **Scheduled Top-ups (`scheduled_topups`):** Automate recharges on a specific date or when data falls below a certain threshold.
* **Offline Recharge (`offline_recharge`):** Capability to recharge or manage SIMs in low-connectivity environments.

### 3.4. Organization & Sharing (`household`)
* **Household/Group Management:** Group SIMs into households or enterprise departments.
* **Shared Balances:** Ability to monitor and manage SIMs for family members or employees.

### 3.5. Alerts & Notifications (`notifications`)
* **Real-time Alerts:** Push notifications for critical events such as low data warnings, successful top-ups, expiring SIMs, or offline recharge status.

### 3.6. Additional Utilities
* **Geo/Location Features (`geo`):** Location-aware features potentially mapping SIM usage or suggesting local plans.
* **Referral System (`referrals`):** Invite friends or businesses to KeepSIMs to earn wallet credits or discounts.
* **Authentication & Profiles (`auth`, `profile`):** Secure login, user onboarding, and personalized profile settings.
* **Support (`support`):** In-app customer service and help center.

## 4. Technical Architecture
* **Frontend Framework:** Flutter (Dart 3+)
* **State Management:** Riverpod 3.x with strict unidirectional data flow.
* **Backend / Database:** Supabase (PostgreSQL)
* **Code Architecture:** Strict 5-Layer Clean Architecture (`model` -> `contract` -> `repository` -> `controller` -> `ui`).
* **Data Models:** Immutable models generated via Freezed, automatically serializing `camelCase` to `snake_case` for Supabase compatibility.

## 5. Success Metrics
* **User Engagement:** High frequency of daily active users checking dashboard metrics.
* **Transaction Friction:** Time-to-recharge should be minimal (ideally under 3 clicks).
* **System Reliability:** Error-free data fetching and offline capability reliability.
