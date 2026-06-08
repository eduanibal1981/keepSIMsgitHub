---
name: KeepSIMs Core
colors:
  surface: '#0d141d'
  surface-dim: '#0d141d'
  surface-bright: '#333a44'
  surface-container-lowest: '#080f17'
  surface-container-low: '#151c25'
  surface-container: '#192029'
  surface-container-high: '#232a34'
  surface-container-highest: '#2e353f'
  on-surface: '#dce3f0'
  on-surface-variant: '#bcc9cd'
  inverse-surface: '#dce3f0'
  inverse-on-surface: '#2a313b'
  outline: '#869397'
  outline-variant: '#3d494c'
  surface-tint: '#4cd7f6'
  primary: '#4cd7f6'
  on-primary: '#003640'
  primary-container: '#06b6d4'
  on-primary-container: '#00424f'
  inverse-primary: '#00687a'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#ffb95f'
  on-tertiary: '#472a00'
  tertiary-container: '#e79400'
  on-tertiary-container: '#563400'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#acedff'
  primary-fixed-dim: '#4cd7f6'
  on-primary-fixed: '#001f26'
  on-primary-fixed-variant: '#004e5c'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#0d141d'
  on-background: '#dce3f0'
  surface-variant: '#2e353f'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Outfit
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Outfit
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  numeric-data:
    fontFamily: Outfit
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  container-max: 1440px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style
The design system embodies a "High-Tech Utility" aesthetic, blending the precision of fintech with the futuristic allure of a command center. It targets tech-savvy global travelers and enterprise SIM managers who value speed, clarity, and a premium digital experience. 

The visual language is rooted in **Glassmorphism** and **Dark Mode**, utilizing high-contrast neon accents to draw attention to critical data points. The atmosphere is sophisticated and nocturnal, evoking the feeling of a high-end night-time interface. Every element should feel like it is floating on a deep, infinite plane, separated by light, transparency, and subtle refractive borders.

## Colors
This design system operates exclusively in a dark palette to reduce eye strain and maximize the vibrancy of neon accents. 

- **Primary (Neon Cyan):** Used for primary actions, navigation highlights, and active data streams.
- **Secondary (Neon Green):** Reserved for "Active" SIM statuses, successful transactions, and positive growth indicators.
- **Tertiary (Neon Amber):** Used for low-data warnings, expiring SIMs, and system alerts.
- **Surface Strategy:** The background is a deep black-gray. Surfaces use a semi-transparent version of the surface hex with a backdrop blur to create the glass effect.
- **Text:** White is used for maximum readability on primary headers, while Light Gray provides hierarchy for metadata and labels.

## Typography
**Outfit** is selected for its geometric purity and modern, tech-forward character. 

- **Headlines:** Use Bold and SemiBold weights to establish a clear hierarchy against the dark background.
- **Data Display:** A specific `numeric-data` role is defined for SIM numbers, data balances, and pricing, emphasizing legibility and a slight "monospaced" geometric feel.
- **Labels:** Small caps or increased letter spacing should be applied to `label-md` to denote section headers and metadata categories.
- **Accessibility:** Ensure that secondary text (#9CA3AF) is only used for non-essential info to maintain high contrast ratios.

## Layout & Spacing
The layout follows a **Fluid Grid** model with a 12-column structure for desktop. 

- **Dashboard Anatomy:** A fixed left-hand sidebar (280px) houses primary navigation, while the main content area utilizes dynamic padding (32px on desktop, 16px on mobile).
- **Rhythm:** An 8px base unit drives all spacing. Consistent use of `md` (24px) for internal card padding and `lg` (48px) for section vertical spacing ensures an airy, premium feel despite data density.
- **Mobile Reflow:** On mobile devices, the 12-column grid collapses to 1 column. Sidebar navigation transforms into a bottom tab bar or a glass-morphic hamburger overlay.

## Elevation & Depth
Depth is created through "Light and Glass" rather than traditional heavy shadows.

- **Level 1 (Base):** The deep #0A0C10 background.
- **Level 2 (Cards/Surfaces):** #15181E with 60% opacity, a 16px backdrop blur, and a 1px solid border at 10% white opacity. This creates the "frosted glass" look.
- **Level 3 (Active/Hover):** When an element is focused or active, apply a "Neon Glow." This is an outer glow (drop shadow) using the primary cyan or secondary green color with a 15-20px blur at 30% opacity.
- **Interactive Elements:** Buttons and interactive chips should have a subtle inner glow on their top edge to simulate a physical light source hitting the rim of the glass.

## Shapes
The shape language is modern and approachable but maintains structural integrity. 

- **Primary Radius:** 0.5rem (8px) is the standard for cards and input fields.
- **Large Radius:** 1.5rem (24px) is reserved for parent containers or large hero-style dashboard widgets.
- **Indicators:** Use "Pill" shapes for status chips (Active, Expired) to distinguish them from functional buttons.
- **Borders:** All glass elements must have a thin 1px border. This "stroke" acts as the edge of the glass, catching light and separating the surface from the dark background.

## Components
- **Buttons:** Primary buttons use a solid Neon Cyan fill with black text for high impact. Secondary buttons use a glass background with a Cyan border and white text. Use a 4px glow on hover.
- **Glass Cards:** The centerpiece component. Must feature `backdrop-filter: blur(16px)`, a subtle linear gradient background (Top-Left to Bottom-Right), and a thin border.
- **Input Fields:** Dark background (#0A0C10) with a 1px border that turns Neon Cyan on focus. The cursor and label should glow slightly when active.
- **Status Chips:** Small, pill-shaped elements. Instead of solid fills, use a 10% opacity background of the status color (Green/Amber) with a high-saturation text color and a leading dot icon.
- **Data Visualizations:** Charts should use Neon Cyan for primary data lines with a subtle gradient area fill underneath. Grid lines should be faint (#FFFFFF at 5% opacity).
- **Icons:** Use thin-stroke (2pt) vector icons. For active states, icons should take on the primary color and a soft outer glow.
