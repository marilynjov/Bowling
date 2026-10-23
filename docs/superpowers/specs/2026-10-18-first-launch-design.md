# First launch (#6)

Replaces `OnboardingPlaceholder` with the first-launch flow from the Phase 1 spec
(§7, Home): the owner's name and handedness, the bowling style question, and a short
explanation of the three entry modes. "Restore from iCloud" stays hidden until phase 2.

**Done when** (issue #6): the answer sets `statsProfile` and the default stats scope, and
can be changed in Settings. The default scope is left empty, which means "follow the
bowling style" (Phase 1 spec §6), so no scope is written. Settings (#13) changes the
style with the existing `BowlerRepository.setStatsProfile`.

## Flow

One step per screen in a `NavigationStack`, so Back works. Nothing is saved until the
last step: the answers live in a draft, and **Start** creates the owner in one call.
Creating the owner flips `AppModel.needsOnboarding` and the root shows the tabs, as the
placeholder does today. Quitting halfway saves nothing, so the next launch starts over.

Saving after each step was rejected: the owner existing ends onboarding, so the flow
would vanish after step 1.

### 1. Welcome

- Title "Welcome".
- "Your name": a text field, focused on appear, `.textContentType(.name)`, submit moves
  focus off the field.
- "You bowl": Right and Left. Nothing preselected.
- **Continue** is enabled once the name is non-blank after trimming whitespace and a hand
  is picked.

### 2. How do you bowl?

- Above the options: "This decides which stats you see. You can change it anytime in
  Settings."
- Three option cards, nothing preselected:

  | Option | Line | `StatsProfile` |
  |---|---|---|
  | Casually | Now and then, for fun. | `.casual` |
  | In a league | A regular league night, and you want your league average. | `.league` |
  | Competitively | Leagues and tournaments, and you want every number. | `.competitive` |

- **Continue** is enabled once one is picked.

### 3. Ways to score

- Title "Ways to score".
- Three rows:
  - **Pin by pin** (tagged "Default"): "Tap the pins on each ball. Unlocks leaves,
    splits, and spare stats."
  - **Count only**: "Enter how many pins fell on each ball."
  - **Final score**: "Just type the game's score."
- Below: "You pick one for each session."
- **Start** creates the owner.

## Look

D1 style (`2026-10-14-visual-style-design.md`): canvas background; option cards and
handedness choices on Surface with a Hairline border, the picked one with a 2 pt accent
border and an accent checkmark; the primary button is `.borderedProminent` (accent).
Each step scrolls, with its button pinned at the bottom (`safeAreaInset`), so it stays
reachable at AX5.

## Accessibility

- Option cards and hand choices are buttons whose label is the option and line, with the
  `.isSelected` trait when picked.
- The disabled Continue keeps its label; VoiceOver reads it as dimmed.
- Every step works at AX5 without clipping.

## Errors

- **Start** is disabled while the write runs, so a double tap can't create two owners.
- A thrown error (for example `.ownerAlreadyExists` or `.invalidBowler(.emptyName)`)
  goes to `app.error`, which the root's shared alert shows with the existing
  `ErrorText`; Start is enabled again.

## Code

`Bowling/Features/Onboarding/`:

| File | Holds |
|---|---|
| `OnboardingDraft.swift` | `name`, `handedness: Handedness?`, `style: StatsProfile?`; `canLeaveProfile`, `canFinish`; `createOwner(in: BowlerRepository) throws -> BowlerRecord?` (nil, saving nothing, unless `canFinish`) |
| `OnboardingFlow.swift` | The `NavigationStack`, the draft as `@State`, Start's write through `app.write` |
| `ProfileStep.swift`, `BowlingStyleStep.swift`, `ScoringModesStep.swift` | The three screens, each with light, dark, and AX3 previews |
| `ChoiceCard.swift` | The selectable card used by steps 1 and 2 |

`RootView` shows `OnboardingFlow`; `OnboardingPlaceholder.swift` is deleted.

## Testing

`BowlingTests/Onboarding/OnboardingDraftTests.swift`, against an in-memory store:

- Profile Continue: off for an empty, spaces-only, or newline-only name; off without a
  hand; on with " Ana " and Left.
- Finish: off without a style; on with all three answers.
- `createOwner` stores the trimmed name, the hand, and the style, and leaves `statsScope`
  nil.
- `createOwner` with no style or no hand returns nil and saves no owner, instead of
  saving a guess.

The full first-launch UI test belongs to #15.

## Not in this issue

- Restore from iCloud (phase 2).
- Changing the style in Settings (#13).
- The tap standing or tap fallen default (#13, after the #3 findings).
