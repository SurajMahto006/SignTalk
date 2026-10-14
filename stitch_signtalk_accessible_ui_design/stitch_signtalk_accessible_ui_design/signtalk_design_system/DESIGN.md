---
name: SignTalk Design System
colors:
  surface: '#fcf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fcf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#414755'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#6b38d4'
  on-secondary: '#ffffff'
  secondary-container: '#8455ef'
  on-secondary-container: '#fffbff'
  tertiary: '#006b27'
  on-tertiary: '#ffffff'
  tertiary-container: '#008733'
  on-tertiary-container: '#f7fff2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#e9ddff'
  secondary-fixed-dim: '#d0bcff'
  on-secondary-fixed: '#23005c'
  on-secondary-fixed-variant: '#5516be'
  tertiary-fixed: '#72fe88'
  tertiary-fixed-dim: '#53e16f'
  on-tertiary-fixed: '#002107'
  on-tertiary-fixed-variant: '#00531c'
  background: '#fcf8fb'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 22px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
---

## Brand & Style

This design system embodies an Apple-inspired, human-centric aesthetic tailored for assistive communication and real-time Indian Sign Language (ISL) interpretation. It bridges gestural and vocal worlds through clarity, quiet confidence, and immediate accessibility. 

The emotional signature is calming, intuitive, and dignified—eschewing clinical sterility in favor of a warm, polished consumer utility. Visual hierarchy is guided by crisp typography, subtle tonal elevations, spacious touch affordances, and distinct dual-modality accenting (vibrant electric blue for active camera gestures and soft violet for speech conversion).

## Colors

The palette leverages high-legibility neutrals paired with targeted functional accents:

- **Primary (`#007AFF`)**: Represents action, ISL camera recognition, primary interactive buttons, and primary active navigation tabs. Tints include `#EBF5FF` for icon containers and tag badges.
- **Secondary (`#8B5CF6`)**: Anchors speech-to-text, listening states, and vocal transcription surfaces. Accompanied by `#EBE7FA` for soft backgrounds and tactile accent cards.
- **Tertiary (`#34C759`)**: Handles positive verification, camera ready indicators, and granted system permissions.
- **Canvas & Surfaces**: The base backdrop rests at `#F5F5F7` (Apple system grey light), while interactive cards, sheets, and text fields pop on pure `#FFFFFF`.
- **Dividers & Strokes**: Precise, subtle hairline borders use `#E5E5EA`.
- **Text & Hierarchy**: Primary headers and body typography utilize `#1D1D1F`. Secondary metadata, microcopy, timestamps, and placeholder labels sit at `#6E6E73`.

## Typography

Set entirely in `Inter` to provide optical clarity at glancing reading distances and under rapid translation feeds. 

- Large titles (`headline-xl`, `headline-lg`) feature tight negative tracking (`-0.02em`) and bold weight to establish rapid section anchoring.
- Interactive controls and primary labels use medium-to-semibold weights (`600`) to guarantee high contrast against light surfaces.
- Body sizes follow standard mobile legibility thresholds, never dipping below `14px` for instructional text or transcription outputs.
- Microcopy, navigation labels, and status tags (`label-md`, `label-sm`) maintain generous line spacing to prevent visual crowding in dense interface states.

## Layout & Spacing

The layout employs an iOS-standard single-column fluid frame structured around a base 4px/8px rhythm:

- **Mobile Viewport Margin**: Consistent `16px` (1rem) lateral margin across all main app screens, maintaining safe margins from edge bezels.
- **Card Spacing & Insets**: Cards and interactive container rows maintain `16px` inner padding, separated by `12px` to `16px` vertical gaps.
- **Touch Targets**: All interactive elements (pills, circular icon buttons, list items) strictly respect minimum touch boundaries of 44x44px.
- **Fixed System Shell**: A persistent top header bar (`44px` height below the status bar) and a 4-tab bottom navigation bar (`84px` height including bottom home indicator inset) frame every screen.

## Elevation & Depth

Visual separation relies on crisp surface layering rather than heavy drop shadows:

- **Surface Tier 0 (Canvas)**: Background color `#F5F5F7`.
- **Surface Tier 1 (Cards & Groups)**: Pure white `#FFFFFF` paired with an ultra-subtle border stroke (`1px solid #E5E5EA`) and a soft ambient shadow: `box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04)`.
- **Floating Controls & Modals**: Camera action triggers and recording FABs utilize higher ambient dispersal: `box-shadow: 0 8px 24px rgba(0, 122, 255, 0.24)`.
- **Overlays & Visual Indicators**: Translucent backdrop blurs (`backdrop-filter: blur(20px); background: rgba(245, 245, 247, 0.8)`) are applied to the persistent bottom bar and navigation headers.

## Shapes

The interface embraces organic, friendly rounded forms:

- **Cards & Viewfinder**: Primary modules use `rounded-2xl` (`16px` corner radius) for containment blocks, live video feeds, and conversation bubbles.
- **Buttons & Pills**: Action buttons, input bars, bottom secondary action pills, and status tags employ fully pill-shaped geometry (`rounded-full` or `9999px`).
- **Icon Enclosures**: Standard icon backdrops are circular (`rounded-full`) or smooth squircle avatars.

## Components

### Buttons
- **Primary Pill**: Height `48px`, background `#007AFF`, text `#FFFFFF`, font weight `600`, full pill radius (`9999px`). Includes leading icon support.
- **Secondary / Action Pill**: Background `#FFFFFF` or `#F2F2F7`, border `1px solid #E5E5EA`, text `#1D1D1F`.
- **Microphone FAB**: Circular container (`72px × 72px`), `#007AFF` core, layered with concentric pulsing ripple rings (`rgba(0, 122, 255, 0.12)`).

### Input Fields & Bottom Bar
- **Chat Input Bar**: Full pill container (`44px` height) with `#FFFFFF` fill, `#E5E5EA` border, housing placeholder text (`#6E6E73`) and a circular `#007AFF` submit button on the right.
- **Search Bar**: Light gray field (`#EBEBED`) with `10px` radius, subtle search glyph prefix, and clear button suffix.

### Cards & Grouped Lists
- **Action Cards**: Large surface (`#FFFFFF`), `16px` corner radius, housing a `48px` colored round icon badge (`#EBF5FF` or `#EBE7FA`), title, subtitle, and an iOS chevron-right indicator (`#C7C7CC`).
- **Grouped Settings Table**: Inset grouped style (`#FFFFFF`), separated by `#E5E5EA` hairline dividers with standard `16px` leading icon indentation.

### Chips & Tags
- **Modality Badges**: Pill-shaped micro-tags (`height: 24px`, padding `0 10px`) indicating interaction type (e.g., `#EBF5FF` with `#007AFF` text for ISL Gesture; `#EBE7FA` with `#8B5CF6` text for Typed/Spoken text).

### Status Indicators
- **Camera / Voice Status**: Pill container or inline pill dot: Ready (`#34C759`), Listening (`#007AFF`), Paused (`#FF9500`), Error (`#FF3B30`).

### Bottom Navigation
- **4-Tab Bar**: Persistent frosted bar containing 4 equal-width slots: **Home**, **Translate**, **Conversations**, and **Settings**. Active tabs render `#007AFF` icons and titles; inactive render `#8E8E93`.