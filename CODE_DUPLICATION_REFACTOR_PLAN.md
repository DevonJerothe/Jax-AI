# Code Duplication Refactor Plan

## Goal

Create a small, consistent Views component system that removes repeated form fields, editor wrappers, option cards, login sections, card grids, image cards, tag chips, and timestamp formatting.

## Main Duplicate Areas

### Themed Fields and Editors

Current duplicates:

- `FormField`
- `FormEditor`
- `AppSheetField`
- `AppSheetEditor`
- `LoreBookTextField`
- `LoreBookTextEditor`
- local `TextField(...).styledFormField()` wrappers
- local `EnhancedTextEditor` wrappers

Plan:

1. Add `PocketAI/Views/Components/ThemedFormComponents.swift`.
2. Implement:
   - `ThemedSectionHeader`
   - `ThemedTextField`
   - `ThemedTextEditor`
   - `ThemedOptionCard`
   - `ThemedToggleRow`
   - `ThemedStepperRow`
   - `ThemedSliderRow`
3. Keep `AppSheetContainer` and `AppSheetButtonStyle` sheet-specific.
4. Convert `AppSheetField`, `AppSheetEditor`, `LoreBookTextField`, and `LoreBookTextEditor` into thin wrappers or remove them.
5. Migrate screens incrementally:
   - `NewTemplateView` and `ChatNoteView` first, because they already use app sheet components.
   - `LoreBookView` and `LoreBookEntryDetailView`.
   - `ConnectionSettingsView`, `SamplerSettingsView`, and `GeneralSettingsView`.
   - `CharacterCardSettingsView`, `UserPersonaView`, and `NewChatView`.

Acceptance criteria:

- There is one default styled text field implementation.
- There is one default fixed-height editor implementation.
- Domain wrappers do not duplicate styling.
- New form rows can be built without manually repeating `padding/background/clipShape`.

### Thumbnail Cards and Result Grids

Current duplicates:

- `CharacterCardPreview`
- `BooruBrowserPostCard`
- `ChubBrowserCard`
- parts of `LoreBookPreview`

Plan:

1. Add `ThumbnailInfoCard`.
2. Support image inputs:
   - local `Image?`
   - remote `URL?`
   - fallback system image
3. Support content slots:
   - title
   - subtitle
   - leading metadata
   - trailing metadata
   - optional badge/count
4. Replace browser cards first because Chub and BotBooru are nearly identical.
5. Replace local character cards after adding local image/data support.
6. Update `PaginatedResultsGridView` to accept configurable columns and derive `gridCellColumns` from the actual column count.

Acceptance criteria:

- Chub and BotBooru card bodies contain only model-to-card mapping.
- Local character cards share image fallback and card chrome.
- Changing card spacing/corner radius happens in one place.

### Browser Shell and Account Settings

Current duplicates:

- Logged-out browser empty state in Chub and BotBooru.
- Loading/empty/results branching in Chub and BotBooru.
- Login/logout/refresh status cards in Chub and BotBooru settings.

Plan:

1. Add `BrowserContentShell`.
2. Add `BrowserSearchToolbar` with slots for provider-specific menus.
3. Add `ProviderAccountStatusCard`.
4. Add `ProviderLoginForm`.
5. Keep provider-specific settings in separate sections:
   - BotBooru browsing filters
   - Chub excluded topics
6. Split `ChubAIBrowserVIew.swift` and `BooruBrowserView.swift` after shared components land.

Acceptance criteria:

- Chub and BotBooru main views share the same shell.
- Chub and BotBooru settings share account/login UI.
- Provider files focus on provider-specific model mapping and settings.

### Profile/Character Editing

Current duplicates:

- `CharacterCardSettingsView`
- `UserPersonaView`
- `NewChatView`
- `CharImportView` preview

Plan:

1. Add `EditableAvatarHeader` with `PhotosPicker` support.
2. Add `ProfileNameField`.
3. Add `ProfileTextEditorSection`.
4. Add a shared `loadSelectedPhotoData` helper or tiny view model method.
5. Use the components in `UserPersonaView` first.
6. Convert `CharacterCardSettingsView` once collapsible sections are extracted.

Acceptance criteria:

- Image data loading code exists in one helper path.
- Avatar/name layout is consistent across persona, character, and manual chat creation.
- Editor styling is identical across profile screens.

### Chips, Tags, and Metadata

Current duplicates:

- Lorebook key chips
- Chub excluded topic chips
- character/browser metadata text rows

Plan:

1. Add `TagChip` and `RemovableTagChip`.
2. Use chips in `LoreBookEntryRow` and `ChubAISettingsView`.
3. Add `MetadataFooterRow` for thumbnail cards if needed.

Acceptance criteria:

- Removable topic/key chips share hit target, background, and icon behavior.

## Suggested File Layout

- `PocketAI/Views/Components/ThemedFormComponents.swift`
- `PocketAI/Views/Components/ThumbnailInfoCard.swift`
- `PocketAI/Views/Components/BrowserComponents.swift`
- `PocketAI/Views/Components/ProfileEditorComponents.swift`
- `PocketAI/Views/Components/TagChip.swift`
- `PocketAI/Views/Components/DateFormatting.swift`

## Migration Sequence

1. Add new components without deleting old wrappers.
2. Migrate low-risk sheet/lorebook screens.
3. Migrate browser cards and shell.
4. Migrate character/persona/new-chat editors.
5. Remove obsolete wrappers.
6. Run app build and manually verify:
   - settings navigation
   - character creation/editing
   - persona creation/editing
   - Chub and BotBooru browsing
   - lorebook create/edit

