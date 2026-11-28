# ForeverSurvivalBuffs

A small reminder for **WoW: Forever**: an icon shows up for each buff you're missing, and nothing
shows when you have them all.

- **Survival buffs** (on by default): **Well Fed**, the one-hour **camp buff**, and the **Cozy
  Sleeping Bag** (only if you have one, and not at the maximum level).
- **Your class buffs**: tick the ones you want, from the buffs of your class that stay on you:
  Arcane Intellect, Frost/Ice Armor, Mage Armor, Ice Barrier, Mana Shield, Inner Fire, Power Word:
  Fortitude, Mark of the Wild, Thorns, Battle Shout, blessings and auras, aspects, Demon Armor,
  Lightning Shield and more. Group versions (Arcane Brilliance, Prayer of Fortitude...) count too.
- **Weapon enhancements**: sharpening stones, weightstones, wizard and mana oils, poisons and shaman
  imbues, for your main hand and off hand.
- **Alchemy**: the elixirs, flasks and protection potions in your bags (Elixir of the Mongoose,
  Flask of the Titans, Greater Fire Protection Potion...). Only the ones you carry show up; the
  reminder shows while the buff is off and you still have one.

Choices are kept per class. Any default can be turned off.

**Dungeons and raids** have their own list: the buffs window's two tabs, *Outside* and *Dungeons and
raids*, choose which one you change, and the addon switches between them by itself when you go in and
out. For example, class buffs only in dungeons, without the camp and the sleeping bag. Until you
change it, the dungeon list is the same as the other one.

**Warn before a buff runs out:** the clock on each buff in the buffs window (and the one below
the list, for all of them) makes a buff's reminder show again, softly fading in and out,
a few minutes before it ends: 3 by default, from 1 to 10 in the options. Only the sleeping bag is
ticked at first.

## How to use

- **Minimap button:** left-click opens the buffs window (tick what you want to be reminded of),
  right-click the options. Both also work from the game's AddOns menu.
- **Move the reminders:** Alt + drag, or untick *Lock position* in the options to place them.
- **Options:** Options > AddOns > ForeverSurvivalBuffs (or the gear in the buffs window): show or hide
  the reminders, hide them in combat, icon size, how long before the end to warn, position, minimap
  button.

In combat and in some instances the game hides your buffs from addons. Then the addon keeps what it
last saw, and checks again as soon as it can.

## Commands

| Command | What it does |
|---|---|
| `/fsb` | Open the buffs window |
| `/fsb on`, `/fsb off` | Turn the reminders on or off |
| `/fsb unlock`, `/fsb lock` | Move the reminders, then lock them in place |
| `/fsb reset` | Put the reminders back in their first place |
| `/fsb options` | Open the settings |
| `/fsb minimap` | Show or hide the minimap button |
| `/fsb diag` | List your buffs and what the addon sees (for bug reports) |

## Install

Extract the `ForeverSurvivalBuffs` folder into `World of Warcraft\_forever_\Interface\AddOns\`.

## Languages

English and Português (Brasil). Spell names come from the game, in your language.

## License

[MIT](LICENSE)
