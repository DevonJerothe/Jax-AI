# PocketAI Agent Guide

## View Organization

SwiftUI screens live under `PocketAI/Views` and are grouped by feature:

- `Views/Chat`: chat list, chat screen, chat settings, chat notes, new chat, and template editing screens.
- `Views/Characters`: character cards, character editing, character import, and user persona screens.
- `Views/LoreBooks`: lore book list, editor, entries, previews, and lore book-specific wrappers.
- `Views/Settings`: app settings, connection settings, and sampler settings screens.
- `Views/Browsers`: provider browser screens such as Chub AI and BotBooru.
- `Views/Components`: reusable view components shared across features.

## Component Placement

Use `Views/Components` for view pieces that are reused across features or are likely to be reused soon.

- `Components/Form`: shared themed form fields, text editors, option cards, toggles, steppers, sliders, and basic form wrappers.
- `Components/Settings`: shared settings cards, navigation rows, and settings controls.
- `Components/Sheets`: shared sheet containers, headers, and sheet button styles.
- `Components/ViewModifiers`: reusable custom modifiers and styles.
- `Components/UITextView`: UIKit-backed text editing bridges.

Keep feature-specific wrappers in their feature folder when they add domain naming or model mapping without duplicating styling.

## Refactor Rules

- Prefer shared components for repeated padding, background, corner radius, label, and editor styling.
- Avoid splitting views into many tiny structs unless the piece is reused, independently meaningful, or reduces a large view's complexity.
- Keep provider-specific model mapping in provider screens; move only shared shell, card, login, or status UI into components.
- When adding a new view, place it in the feature folder first. Promote it to `Components` only after reuse is clear.
- Preserve existing behavior during organization-only changes. Move files and extract duplicate UI chrome separately from business logic changes.
