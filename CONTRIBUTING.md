# Contributing to ForeverSurvivalBuffs

Thanks for helping out! Bug reports, ideas and pull requests are all welcome.

## Reporting a bug

Open an issue and include:

- what you did, what you expected, and what happened instead;
- the output of `/fsb diag`;
- the full Lua error text, if there was one ([BugSack](https://www.curseforge.com/wow/addons/bugsack) makes this easy);
- your game version (shown by `/fsb diag`).

## Development setup

1. Clone the repository anywhere you like.
2. Link the folder into the game, so `/reload` picks up your changes. From a Command Prompt:

   ```bat
   mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverSurvivalBuffs" "C:\path\to\your\clone"
   ```

   The link must be called `ForeverSurvivalBuffs` (the addon's name), whatever your clone's folder is called.

   On macOS, use `ln -s` into `/Applications/World of Warcraft/_forever_/Interface/AddOns/`.

3. Log in, make changes, and type `/reload`. `/fsb diag` lists your buffs and what the addon sees.

## Code layout

| File | Purpose |
|---|---|
| `Core.lua` | Namespace, secret-safe helpers, event dispatcher, saved variables |
| `Locales.lua` | Translations (`ns.L`) |
| `Catalog.lua` | The buffs that can be chosen: survival buffs, class buffs (by spell ID) and weapon enhancements |
| `Auras.lua` | Reads the player's buffs and weapon enhancements, never while the game keeps them secret |
| `Tracker.lua` | The chosen buffs (per class), their status, and when to look again |
| `UI/Reminders.lua` | The row of reminder icons |
| `UI/BuffWindow.lua`, `UI/BuffRow.xml` | The window to choose the buffs |
| `Minimap.lua` | The minimap button, its right-click menu and the AddOns menu entry |
| `Settings.lua` | The options panel |
| `Slash.lua` | `/fsb` commands and `/fsb diag` |
| `Media/Icon.tga` | The addon's icon in the game's AddOns list (64×64, 32-bit TGA) |

## Guidelines

- **Indentation:** use tabs in Lua, matching the existing code.
- **Language:** write player-facing text in English and wrap it in `L["..."]`, then add the
  translation to each language block in `Locales.lua`. Spell and class names come from the game,
  already translated. Debug and `/fsb diag` output stays in English.
- **Adding a language:** copy the `ptBR` block in `Locales.lua`, change the locale code
  (`deDE`, `frFR`, `esES`, ...) and translate the right-hand side.
- **Secret values:** WoW: Forever restricts addons the same way as Midnight. In combat and in some
  instances aura data is *secret*, and some aura functions raise an error when an addon calls them.
  Read buffs only through `Auras.lua` (it checks `C_Secrets` first), and other game values through
  `ns.Safe` (`Safe.Call`, `Safe.CallAll`, `Safe.Field`).
- **Adding a class buff:** add it to its class in `Catalog.lua` with the spell ID of rank 1 (every
  rank has the same name, and the aura is matched by name). Only buffs that stay on the character.
- **Taint:** don't hook or modify Blizzard frames; everything on screen is the addon's own frames.
- **One change per pull request**, with a short description of what it does and how you tested it
  in game.
- **Changelog:** add a line under *Unreleased* in `CHANGELOG.md`.

## Releasing (maintainers)

1. In the release pull request, move the *Unreleased* changelog entries under a new `## X.Y.Z` heading.
2. Merging it runs `.github/workflows/release.yml`: it builds `ForeverSurvivalBuffs-vX.Y.Z.zip`
   (without the files listed under `ignore` in `.pkgmeta`, and with `@project-version@` in the `.toc`
   replaced by the version), uploads it to CurseForge and creates the GitHub release `vX.Y.Z`.
   It needs the repository secret `CF_API_KEY` and the `X-Curse-Project-ID` line in the `.toc`.

By contributing, you agree that your contributions are licensed under the project's
[MIT License](LICENSE).
