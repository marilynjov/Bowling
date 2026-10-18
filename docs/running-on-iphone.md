# Running the app on your iPhone

A free Apple ID is enough. Each of us signs with our own Apple ID, set in a personal file
git ignores, so `project.pbxproj` never changes when someone signs in.

## One-time setup

1. **Add your Apple ID to Xcode:** Xcode → Settings → Apple Accounts → +.
2. **Find your team ID** (10 characters). Connect nothing yet; in Terminal:

   ```sh
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```

   The team ID is the `OU=` value. If the command finds nothing, open the project, pick
   your team once in the Bowling target's Signing & Capabilities tab, copy the
   `DEVELOPMENT_TEAM` value from `git diff`, then undo it with
   `git restore Bowling.xcodeproj/project.pbxproj`.
3. **Create your personal file:**

   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   Then edit `Config/Local.xcconfig`:

   | | `DEVELOPMENT_TEAM` | `BUNDLE_ID_SUFFIX` |
   |---|---|---|
   | marilynjov | your team ID | leave empty |
   | SantiagoM99 | your team ID | `.santiago` |

   A free Apple ID owns the bundle IDs it registers, so the second person needs a suffix:
   their app is `com.marilynjov.bowling.santiago`. Both apps can sit on one phone.
4. **Prepare the iPhone:** connect it with a cable, tap **Trust**, then turn on
   Settings → Privacy & Security → **Developer Mode** (the phone restarts).

## Every time

1. Pull the branch you want to try and open `Bowling.xcodeproj`. If Xcode was already
   open, close and reopen the project after creating `Local.xcconfig`.
2. Choose your iPhone as the run destination and press **⌘R**.
3. The first time, the phone may refuse to open the app: Settings → General → VPN &
   Device Management → your Apple ID → **Trust**.

With a free Apple ID the app stops opening after 7 days. Press ⌘R again to reinstall.

## Don't

- Don't pick a team in Signing & Capabilities after setup: Xcode writes it into
  `project.pbxproj`. If `git status` shows that file changed and you didn't mean to, run
  `git restore Bowling.xcodeproj/project.pbxproj`.
- Don't commit `Config/Local.xcconfig` (git ignores it already).

## Pin deck test (#3)

Debug builds only: Home → Settings (gear) → **Pin deck test**. Switch between the Pins and
Circles decks and between Tap fallen and Tap standing, then bowl a game with the deck and
the Strike/Spare, Miss, and Foul buttons. Undo and New game are in the toolbar. Nothing is
saved.
