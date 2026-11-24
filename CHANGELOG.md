# Changelog

All notable changes to ForeverSurvivalBuffs are listed here.

## Unreleased

## 1.1.3

- Simpler minimap button tooltip: just the name and what the left and right clicks do.
- Portuguese: "Clique esquerdo" and "Clique direito" in the tooltips.

## 1.1.2

- A list of buffs for dungeons and raids: the buffs window has two tabs, "Outside" and "Dungeons and
  raids", and the addon switches between the two lists by itself when you go in and out. Until you
  change it, the dungeon list is the same as the other one.

## 1.1.1

- Class buffs are recognised at every rank, also when the game names the higher ranks differently.
  In Portuguese, rank 1 of Arcane Intellect is "Inteligência Arcana" and the others "Intelecto
  Arcano": only rank 1 counted, so the buff showed as missing.
- The buffs window shows the names of the ranks you learned when they differ
  ("Inteligência Arcana / Intelecto Arcano").

## 1.1.0

- Fixed the Lua error "Auras cannot be accessed when secret while tainted": in combat and in some
  instances the game hides your buffs from addons. The addon no longer reads them then, and keeps
  what it last saw until you can be checked again.
- Choose your buffs: besides Well Fed, the camp buff and the sleeping bag, you can tick the buffs of
  your class that stay on you (Arcane Intellect, the mage armors, Ice Barrier, Inner Fire, Power Word:
  Fortitude, Battle Shout, blessings, aspects and more) and the temporary enhancements on your
  weapons (sharpening stones, oils, poisons, shaman imbues). The three survival buffs are still on by
  default, and each can be turned off. Choices are kept per class.
- A window lists every buff you can choose, with whether it's on you right now.
- Minimap button: left-click opens the buffs window, right-click the options. The same in the
  game's AddOns menu.
- An options panel (Options > AddOns > ForeverSurvivalBuffs): turn the reminders off, hide them in
  combat (on by default), unlock to place them, icon size, reset the position, the minimap button.
- The sleeping bag reminder no longer shows at the maximum level (it only gives experience).
- The reminders keep their position from 1.0.x. Slash command `/fsb` (`/fsb help` lists the rest);
  `/sb` and `/fbr` are gone.
- English and Português (Brasil).

## 1.0.0

- First release (CurseForge only): reminders for Well Fed, the camp buff and the Cozy Sleeping Bag.
