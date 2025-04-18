## Walk This Way
**Current Version**: ~v-dev~ \
**Updated**: ~date~

This extension provides a small popup window at the start of a person's turn that asks if they want to stand up, if they are prone. Version 2 of this extension now also calculates total effective speed after effects in combat tracker.

### Installation

Install from the [Fantasy Grounds Forge](https://forge.fantasygrounds.com/shop/items/1940/view). \
You can find the source code at Farratto's [GitHub](https://github.com/Farratto/WalkThisWay). \
You can ask questions at the [Fantasy Grounds Forum](https://www.fantasygrounds.com/forums/showthread.php?82914). \
Video explaining how to use at [YouTube](https://youtu.be/FmA9JoUoXps).

### Details

The prone checker will also check for any conditions that disallow a creature to stand up.  If it finds one, it will not ask the player if they want to stand up.  The following conditions are currently supported.

* Grappled; Paralyzed; Petrified; Restrained; Unconscious; Tasha's Hideous Laughter; Unable to Stand; SPEED: none; NOSTAND; SPEED: max(0)

The window asks if the person wants to stand up.  If they answer okay, the extension will remove the effect that contains prone and add an effect that says "SPEED: halved" that lasts until the end of turn.  If they answer cancel, close the window, or ignore the window, the extension will do nothing. \
The window  can be ignored and it will go away at the end of turn without consequences. \
The speed effects that are recognized:

| Effect | Description |
| :--- | :--- |
| SPEED: none | rooted
| SPEED: -10 or SPEED: 10 dec or SPEED: dec(10) | decreases all speeds by 10 |
| SPEED: 10 inc or SPEED: inc(10) | increases all speeds by 10 |
| SPEED: 60 | increases all speeds to 60 (speeds already above 60 will be unchanged) |
| SPEED: type(climb) | adds a new speed 'climb' and sets it to be the same as walking speed |
| SPEED: 60 type(fly) | adds a new speed 'Fly' and sets only the new speed to 60 |
| SPEED: -30 type(fly) | decreases fly speed by 30 |
| SPEED: type(-fly) | removes fly speed |
| SPEED: 5 max or SPEED: max(5) | none of the speeds can exceed 5
| SPEED: difficult | difficult terrain handling (halves all speeds except fly) |
| SPEED: halved | halves all speeds (after inc/dec); stackable |
| SPEED: doubled | doubles all speeds (after inc/dec); stackable |
| SPEED: tripled | triples all speeds (after inc/dec); stackable |
| SPEED: free | ignores effects that reduce speed except roots, prone, exhausted, & encumbered (see 5E's  Freedom of Movement) |

Supports 5e RAW encumbered (both standard and variant), exhaustion, dash, and 2024 athlete feat rules.  Reduces speed when character is wearing armor the character is not strong enough to wear.  Checks for 2014 dwarfs first.

The extension updates all the speeds on the speed field in the combat tracker.  Character sheets still show base speed.  There is an optional window that shows all the speeds for a character and all the effects affecting their speed.You can have the window open automatically on your turn through an option setting.  Or you can open the window at any time by double-clicking the speed field on a character sheet or the combat tracker.

Option setting (for GM and players) to change the units that speed is displayed in.  Current choices are feet, meters, and tiles.  Automatically rounds final speed down to nearest half tile.  Typing /distunits followed by either ft, m, or tiles will change the units that the effects are processed in.  This is advanced usage and I don't recommend unless all your effects are not in feet (unusual).

Current Extension/Module Support: Better Combat Effects, Pets, GrimPress's 5e Automatic Effects, Team Twohy's 5e Effects Coding, Assistant GM, Mad Nomad's Character Sheet Effects Display, 5E Auto Encumbrance, Exhausted, Temporal Fixation, Step Counter, Map Parcels

Note: Known limitation with Mad Nomad's Character Sheet Tweaks: Changed units will not display on player character sheets (but still works on CT, speed windows, and NPCs)

### Other Rulesets

This extension was designed with 5e in mind, but I have ported it to work on most rulesets.  I believe any ruleset will work for the prone functionality.  But since I haven't gone through the individual rules of other rulesets, I've included the folowing recognized effects:

* Unable to Stand; SPEED: none; NOSTAND; Unconscious

If you would like me to add to this list, or make more specific accomodations for your ruleset, please let me know.

Any ruleset based on DnD or Pathfinder should work for speed calculations and thus for supporting maximum speed limitation in Step Counter.  If you find that one of these rulesets is not working or you have another ruleset you'd like me to add, please let me know.

### Pathfinder 2e

In addition to the above universal checks, when under the Pathfinder 2e ruleset, this extension will check for the following conditions:

* Dead; Paralyzed; Dying; Immobilized; Petrified; Restrained; Grabbed; Stunned

### Pathfinder 1e and DnD 3.5e

In addition to the above universal checks, when under the Pathfinder 1e ruleset, this extension will check for the following conditions:

* Cowering, Dazed, Dead, Dying, Grappled, Helpless, Paralyzed, Petrified, Pinned, Stable. Stunned, Unconscious, Exhausted, Entangled

### Still Being Developed

If you find any additional effects, where a user is not able to stand up, please let me know.  Or any other concerns or suggestions are welcome.

Enjoy!

### Attribution

SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development. \
headerpoweratwill.webp and headerpowerenc.webp copied from included Smiteworks themes. \
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC. \
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

### Change Log

* v2.8.2: IXED: toggling option to enable or disable speed effects was not affecting immediately
* v2.8.1: FIXED: special speeds on charSheet requiring reload to update; rare console error.
* v2.8.0: NEW tag: SPEED: free (see 5e Freedom of Movement and readme or forum). FEATURE: 5E support for heavy armor Str requirement. PRE-FIX: Speed box moved for FGU update 4.7
* v2.7.0: Added support for some speed-related PFRPG conditions. New speed effect: SPEED: tripled.
* v2.6.1: FIXED: nil error with speed effects on some non-5E rulesets
* v2.6.0: Now supporting SPEED effects and movement limitation for all rulesets based on DnD or PF
* v2.5.3: Renewed support for Exhausted extension. Cut the cord on Step Counter.
* v2.5.2: FIXED: introduced error when encountering creatures with no speed
* v2.5.1: FIXED: Base Speed on PC charsheet not displaying correctly in some instances.
* v2.5.0: Reduced option clutter. New option to auto-close speed window. Accomodations for Step Counter
* v2.4.0: FEATURE: vehicle support. FIXED: rare nil error. Minor aesthetic improvements.
* v2.3.4: FIXED: several minor bugs. Shout out to RocketVaultGames for constant vigilence!
* v2.3.3: Negative Interaction with MNM CharSheet Tweaks. FIXED
* v2.3.2: Speed label not displaying on PC main tab. FIXED
* v2.3.1: Sometimes reporting incorrect speed on player character sheets: FIXED
* v2.3.0: Rare error window when mistyping SPEED effect. FIXED
* v2.2.9: Support for Athlete Feat. Improved Speed field interpretation.
* v2.2.8: Dash processing unintentionally homebrewed: Now uses RAW.
* v2.2.7: Effect checking not specific enough: Fixed. Past update broke PFRPG2: Fixed.
* v2.2.6: WtW interfering with disabling effects: Fixed.
* v2.2.5: Rare bug with JackOfAllThings: Fixed.
* v2.2.4: Mad Nomad granted permission to use bonus numbers without his extension present.
* v2.2.3: Improved UI. Speed not updating when disabling effect: Fixed. Other minor changes.
* v2.2.1: Bug reported with AE and BCEG: Fixed.
* v2.2.0: Aesthetic Improvements
* v2.1.2: Negative Interaction with Turbo: Fixed.
* v2.1.1: Erroneous calc with new speedless type: Fixed. Rare Error: Fixed. Small aesthetic improvement.
* v2.1.0: First Run Display Bugs: Fixed. Windows not coming to front: Fixed.
* v2.0.0: Speed Calculator. Condition Detection/Removal Improvement. UI Improvements.
* v1.4.6: Bug with BCE: fixed.
* v1.4.5: Assistant GM support. Minor Performance improvement.
* v1.4.3: Pets extension support. Query Window Improved.
* v1.4.2: More specific support for Pathfinder 2e added.
* v1.4.0: Ported for other rulesets.
* v1.3.4: Bug reported in interaction with BCE. Fixed
* v1.3.3: Made query window more theme-friendly.
* v1.3.2: Added Support for Team Twohy's 5e Effects Coding. Made changes under the hood to improve accuracy and efficiency.
* v1.2.5: New Options allowing players to individually disable the reminder windows (if DM allows).
* v1.2.0: Full support added for BCE & FZ.