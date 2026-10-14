---
name: SignTalk
colors:
  surface: '#e7fefd'
  surface-dim: '#c8dede'
  surface-bright: '#e7fefd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#e1f8f7'
  surface-container: '#dcf2f2'
  surface-container-high: '#d6edec'
  surface-container-highest: '#d0e7e6'
  on-surface: '#0a1f1f'
  on-surface-variant: '#3f4849'
  inverse-surface: '#203434'
  inverse-on-surface: '#dff5f4'
  outline: '#6f7979'
  outline-variant: '#bfc8c9'
  surface-tint: '#23686d'
  primary: '#00454a'
  on-primary: '#ffffff'
  primary-container: '#155e63'
  on-primary-container: '#94d5da'
  inverse-primary: '#91d1d7'
  secondary: '#4d635c'
  on-secondary: '#ffffff'
  secondary-container: '#d0e8df'
  on-secondary-container: '#536962'
  tertiary: '#004739'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c5f50'
  on-tertiary-container: '#96d6c3'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#adeef3'
  primary-fixed-dim: '#91d1d7'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f54'
  secondary-fixed: '#d0e8df'
  secondary-fixed-dim: '#b4ccc3'
  on-secondary-fixed: '#0a1f1a'
  on-secondary-fixed-variant: '#364b45'
  tertiary-fixed: '#aef0db'
  tertiary-fixed-dim: '#93d3c0'
  on-tertiary-fixed: '#002019'
  on-tertiary-fixed-variant: '#045142'
  background: '#e7fefd'
  on-background: '#0a1f1f'
  surface-variant: '#d0e7e6'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 3rem
    fontWeight: '600'
    lineHeight: 3.5rem
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 2.25rem
    fontWeight: '600'
    lineHeight: 2.75rem
    letterSpacing: -0.015em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 1.75rem
    fontWeight: '600'
    lineHeight: 2.25rem
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: 2rem
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 1.25rem
    fontWeight: '500'
    lineHeight: 1.75rem
  title-md:
    fontFamily: Inter
    fontSize: 1.125rem
    fontWeight: '500'
    lineHeight: 1.625rem
  body-lg:
    fontFamily: Inter
    fontSize: 1.125rem
    fontWeight: '400'
    lineHeight: 1.75rem
  body-md:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.6rem
  body-sm:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.4rem
  label-lg:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '500'
    lineHeight: 1.5rem
  label-md:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '500'
    lineHeight: 1.25rem
  label-sm:
    fontFamily: Inter
    fontSize: 0.75rem
    fontWeight: '600'
    lineHeight: 1rem
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 2rem
  margin-mobile: 1rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
---

## Brand & Style
The brand embodies an empowering, human-centered bridge between the Deaf community and the hearing world through Indian Sign Language (ISL). The interface aesthetic is grounded in calm clarity, dignity, and intuitive intelligence. It avoids clinical coldness and chaotic over-stimulation, adopting an understated, contemporary minimalism with tactile warmth. 

Visual interactions inspire trust and effortless communication through generous negative space, purposeful optical hierarchy, and friendly organic geometry. Motion is fluid and deliberate, mimicking natural gestural cadence rather than snappy, abrupt transitions.

## Colors
The palette is locked strictly to a light-mode presentation to preserve optimal contrast, calm readability, and pristine rendering of gestural camera feeds and avatar visuals.

- **Primary (`#155E63`)**: Deep Teal serves as the core anchor for key actions, brand marks, focused states, and structural icons. It conveys balance, authority, and emotional stability.
- **Secondary (`#DDF5EC`)**: Soft Mint provides calming, expansive container fills, pill backgrounds, and subtle highlight blocks.
- **Tertiary / Accent (`#A7E8D4`)**: Soft Aqua is applied to active gestural feedback rings, progress indicators, and interactive micro-cues.
- **Neutral Main (`#172B2B`)**: Deep Charcoal replaces harsh black for body typography and high-emphasis labels, yielding WCAG AAA compliance against light surfaces without eye strain.
- **Secondary Text (`#697777`)**: Balanced slate gray for secondary captions, timestamps, and placeholder copy.
- **Surface & Canvas**: Canvas base is warm off-white (`#F8FAF9`); interactive cards and modal surfaces rest on pure white (`#FFFFFF`) framed by fine structural borders (`#E2E8E5`).
- **Semantic Error (`#D94A4A`)**: A soft, accessible muted red reserved strictly for system warnings, capture dropouts, or misrecognition alerts.

## Typography
Inter delivers systematic clarity, balanced neutral proportions, and tall x-heights suited for rapid real-time translation and multi-lingual glossing. Generous line-heights enhance readability for neurodivergent and low-vision users. 

Headings feature slight negative tracking for structural cohesion, while labels and micro-copy preserve open letter-spacing to sustain absolute legibility across varied device viewports.

## Layout & Spacing
The layout relies on a strict 8pt base grid for proportional scaling. Touch targets strictly respect an absolute minimum boundary of 48x48px across all responsive form factors to accommodate diverse motor abilities.

- **Mobile (< 768px)**: 4-column fluid grid, 16px margins, 16px gutters. Camera capture interfaces and live translation transcripts adopt vertical split stacking.
- **Tablet (768px - 1024px)**: 8-column grid, 24px margins, 20px gutters. Adaptive side panels surface translation logs alongside continuous video feeds.
- **Desktop (> 1024px)**: 12-column grid constrained to a maximum width of 1280px with 32px canvas margins and 24px gutters, maintaining focused optical paths without wide horizontal eye drift.

## Elevation & Depth
Depth is built on clean tonal layering and soft, diffused ambient light. Glassmorphism, reflective glazes, and heavy drop shadows are intentionally omitted to maintain high optical clarity for Deaf and hard-of-hearing users who rely on sharp contrast.

- **Level 0 (Flat)**: Base canvas `#F8FAF9`.
- **Level 1 (Cards, Modules)**: Pure White (`#FFFFFF`) surface, 1px border of `#E2E8E5`, and a subtle ambient shadow: `0 2px 8px -2px rgba(21, 94, 99, 0.04), 0 1px 4px -1px rgba(23, 43, 43, 0.02)`.
- **Level 2 (Hover States, Floating Quick Controls)**: 1px border of `#DDF5EC`, with an elevated ambient spread: `0 8px 24px -4px rgba(21, 94, 99, 0.08)`.
- **Level 3 (Modals, Assistive Drawers)**: Pure White (`#FFFFFF`) bordered by `#E2E8E5`, supported by: `0 16px 36px -8px rgba(23, 43, 43, 0.12)`. Overlays use a translucent backdrop tint of `rgba(23, 43, 43, 0.35)`.

## Shapes
Geometry uses welcoming, friendly curvatures. Core content containers and camera viewports feature substantial corner radiuses (16px to 24px), eliminating sharp, clinical edges. Small status badges, filters, and primary CTA buttons utilize pill radii (9999px) for approachable, organic ergonomics. Form elements and inner cards retain a 12px to 16px radius for visual harmony.

## Components

- **Buttons**:
  - *Primary*: Deep Teal (`#155E63`) background, White text, fully rounded pill shape (`9999px`), minimum height 48px, horizontal padding `1.5rem`. On hover/focus: tinted overlay `#0E4347`.
  - *Secondary*: Soft Mint (`#DDF5EC`) background, Deep Teal (`#155E63`) text, borderless, minimum height 48px.
  - *Outlined*: Pure White background, 1.5px border in `#155E63`, text `#155E63`. Focused states carry a 3px outer ring in `#A7E8D4`.

- **Pill Badges & Chips**:
  - Compact tags for ISL dialect tags, gesture confidence, and modes.
  - Height 32px, radius `9999px`, padding `0.25rem 0.75rem`. Fill `#DDF5EC` with Deep Teal `#155E63` text in `label-sm`.

- **Cards**:
  - Surface `#FFFFFF`, border 1px solid `#E2E8E5`, corner radius 16px (standard) or 24px (hero sections). Internal padding set to `1.5rem`. Subtle hover elevation shift via ambient shadow.

- **Toggle Switches & Checkboxes**:
  - *Switches*: Outer track 52x32px in `#E2E8E5` (inactive) shifting to `#155E63` (active). Thumb is pure white 26x26px circle with soft shadow.
  - *Checkboxes*: 24x24px with 6px rounded corners, 2px border in `#697777`, filling with `#155E63` and a crisp white check icon when selected.

- **Input Fields**:
  - Height 52px (accommodating comfortable touch interactions), background `#FFFFFF`, border 1.5px `#E2E8E5`, radius 12px, font `body-md`. Focus transitions to a `#155E63` border with a 3px soft halo in `#A7E8D4`.

- **Accessibility & Gestural Feedback Indicators**:
  - *Visual Sign Confirmation Ring*: Concentric halo in `#A7E8D4` pulsing around active video frames to confirm sign recognition.
  - *Audio-Visual Waveform Module*: Real-time speech-to-sign transcription display utilizing `#155E63` bars with soft-rounded tips on a `#DDF5EC` container.
  - *Haptic/Status Notification Banner*: Surface `#FFFFFF`, border-left 4px in `#155E63` (Info) or `#D94A4A` (Error), padded `1rem` with high-contrast text.