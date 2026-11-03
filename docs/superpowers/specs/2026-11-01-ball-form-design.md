# Ball add and edit form — design

Issue #29 · Phase 1b · owner:frontend · branch `feat/29-ball-form` (from `feat/28-arsenal-list`)
Phase 1 spec §7 "Add and edit form" and §3.3 are the authority. Contract §3.6 (`BallFields`,
`addBall(_:)`, `updateBall`, `setPhoto`, `setRetired`, `deleteBall`) is used as is.

## Goal

One form adds a ball or edits any of its fields, sets its photo, and retires or deletes it.
Only name and weight are required. Factory finish seeds the current surface on add.

## 1. Entry

- `AppModel.isAddingBall` becomes `ballForm: BallFormTarget?`:
  `enum BallFormTarget: Hashable, Identifiable { case add; case edit(BallID) }`.
- Arsenal's Add button and the empty state's Add ball set `.add`.
- Tapping an Arsenal row, active or retired, sets `.edit(id)`. This is temporary: #30 points
  the row at ball detail and moves Edit to the detail header.
- `ErrorPresenter.addBall` becomes `.ballForm`. It is topmost while `ballForm` is set.

## 2. Form layout

`BallFormSheet`, a `Form` in a `NavigationStack`. The title is "Add ball" or "Edit ball".
It has Cancel and Save. Save is off until `canSave`. Sections, in order:

1. **Identity:**
   - photo row (§4)
   - Name
   - Brand
   - Weight (picker, 6–16 lb, "Choose" until picked on add)
   - Color
   - Serial number
2. **Construction:**
   - Coverstock (picker over `Coverstock`, with "Not set" for `.unknown`)
   - Coverstock name
   - Core type (picker over `CoreType`, with "Not set")
   - Core name
   - RG
   - Differential
   - Intermediate differential, shown only when the core type is asymmetric
   - Factory finish
   - Release date (month and year)
3. **Use:**
   - Role (segmented: Strike, Spare, Both)
   - Purchase date (range up to today)
   - Current surface. On add it is blank, with the prompt "Same as factory finish".
   - Resurface every … games (number field; blank means no reminder)
4. **Notes:** a multi-line `TextField(axis: .vertical)`.
5. **Edit only:**
   - "Retire ball", or "Return to arsenal" when the ball is retired
   - "Delete ball", destructive (§5)

**Dates.** An unset optional date shows an "Add release date" or "Add purchase date" button.
Tapping it sets today and shows the `DatePicker` with a clear button.

**Field error.** A number field that doesn't parse shows its message under the field
("Enter a number", "Enter a whole number of at least 1") and keeps Save off. It does not
raise an alert.

## 3. Model: `BallForm`

It replaces `BallDraft`. A value type, unit tested without views.

- `init()` builds an empty add form.
- `init(editing id: BallID, detail: BallDetail)` copies `detail.fields`. Number fields
  become text using the current locale.
- It stores text for `rg`, `differential`, `intermediateDifferential` and
  `resurfaceIntervalGames`. Every other field is stored as in `BallFields`.
- `weightPounds: Int?` is nil until picked.
- `canSave`: the name isn't blank, the weight is set, and every number field is valid.
- `fieldError(_:) -> String?` gives a number field's message.
- `fields() -> BallFields?` returns nil unless `canSave`.
  - Blank number text becomes nil.
  - Decimals parse with the current locale's separator.
  - `intermediateDifferential` is nil unless `coreType == .asymmetric`.
- `photo: PhotoChange` is `.unchanged`, `.set(Data)` or `.removed`.
- `save(to: BowlingStore) throws -> BallID`:
  - Calls `addBall(_:)` or `updateBall(_:with:)`.
  - Then applies `photo` through `setPhoto` or `removePhoto`.
  - If the photo step throws after the ball is saved, the error propagates, and the ball
    stays saved.

`AppModel.saveBall(_ form: BallForm) throws`:
- It writes through `write`, then closes the sheet.
- It does nothing when `ballForm` is nil, so a double tap can't add twice. This is the
  current `addBall` guard.

## 4. Photo

- The photo row shows the current photo, the picked photo, or the #28 placeholder.
- Next to it are `PhotosPicker(selection:matching: .images)` ("Choose photo" or "Change
  photo") and, when there is a photo, "Remove photo".
- A picked item loads as `Data`. `BallPhoto.downscaled(_ data: Data) -> Data?`:
  - scales to at most 1024 px on the longest side, never upscaling
  - encodes JPEG at quality 0.8
  - returns nil for data that isn't an image, which shows "Couldn't use that photo."
- The photo is held in the form until Save, so Cancel discards it.
- No camera capture in this issue.

## 5. Retire and delete

Both are edit only and save nothing else from the form.

- **Retire / Return to arsenal:**
  - `AppModel.setBallRetired(_ id: BallID, _ retired: Bool) throws` calls `setRetired`.
  - It closes the sheet.
  - A retired ball's form shows "Return to arsenal".
- **Delete:**
  - A confirmation dialog asks "Delete this ball? Its photo and maintenance log are deleted
    too." with Delete and Cancel.
  - `AppModel.deleteBall(_ id: BallID) throws` calls `deleteBall` and closes the sheet.
- **Ball with games:**
  - `deleteBall` throws `.ballHasGames(count:)`.
  - The form catches it and shows an alert with `ErrorText`'s existing message ("This ball
    was used in N games. Retire it instead.") and two buttons: **Retire** (as above) and
    Cancel.
  - It does not go through the shared alert, because the shared alert has only OK.

## 6. Testing

Swift Testing, `BowlingTests/Arsenal/`.

**BallFormTests:**
- `canSave` with no name, a blank name, no weight, and a bad RG.
- Round trip: `BallForm(editing:detail:).fields()` equals `detail.fields` for a fully
  filled ball.
- Number parsing: blank becomes nil; "2.52" becomes 2.52; "abc" gives an error; an
  interval of "0" gives an error.
- An intermediate differential is dropped unless the core is asymmetric.
- Save, through the store:
  - Add with a factory finish and a blank surface reads back that surface.
  - Edit one field and the others are unchanged.
  - An `.unknown` role is kept.
  - `.set` stores a photo, `.removed` clears it, and `.unchanged` keeps it.

**BallPhotoTests:**
- A 4000×3000 image comes out 1024×768 and under `maxPhotoBytes`.
- A 500×400 image keeps its size.
- Data that isn't an image returns nil.

**AppModelTests:**
- `saveBall` closes the sheet and doesn't add twice.
- Deleting a ball with games throws `.ballHasGames` and keeps the sheet open.
- Retire closes the sheet and moves the ball to `retiredBalls()`.

**Previews:** Add, and Edit of a fully filled ball, in light, dark and AX5, plus Edit of a
retired ball.

## Not in scope

- Ball detail and its Edit button (#30).
- The notification permission request when an interval is first set, and the resurface
  reminder (#32).
- Camera capture.
- Compare (#31).
