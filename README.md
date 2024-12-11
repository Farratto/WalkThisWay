## Walk This Way
**Current Version**: ~dev_version~ \
**Updated**: ~date~

This extension provides a small popup window at the start of a person's turn that asks if they want to stand up, if they are prone. Version 2 of this extension now also calculates total effective speed after effects in combat tracker.

### Installation

Install from the [Fantasy Grounds Forge](https://forge.fantasygrounds.com/shop/items/1940/view). \
You can find the source code at Farratto's [GitHub](https://github.com/Farratto/WalkThisWay/releases). \
You can ask questions at the [Fantasy Grounds Forum](https://www.fantasygrounds.com/forums/showthread.php?82914-Walk-this-Way-for-5e). \
Video explaining how to use at [YouTube](https://youtu.be/FmA9JoUoXps).

### Details

The prone checker will also check for any conditions that dissalow a creature to stand up.  If it finds one, it will not ask the player if they want to stand up.  The following conditions are currently supported.

* Grappled; Paralyzed; Petrified; Restrained; Unconscious; Tasha's Hideous Laughter; Unable to Stand; SPEED: none; NOSTAND; SPEED: max(0)

The window asks if the person wants to stand up.  If they answer okay, the extension will remove the effect that contains prone and add an effect that says "SPEED: halved" that lasts until the end of turn.  If they answer cancel, close the window, or ignore the window, the extension will do nothing. \
The window  can be ignored and it will go away at the end of turn without consequences. \
The speed effects that are recognized:

| Effect | Description |
| :--- | :--- |
| SPEED: none | rooted
| SPEED: -10 or SPEED: 10 dec | decreases all speeds by 10 |
| SPEED: 10 inc | increases all speeds by 10 |
| SPEED: 60 | increases all speeds to 60 (speeds already above 60 will be unchanged) |
| SPEED: type(climb) | adds a new speed 'climb' and sets it to be the same as walking speed |
| SPEED: 60 type(fly) | adds a new speed 'Fly' and sets only the new speed to 60 |
| SPEED: -30 type(fly) | decreases fly speed by 30 |
| SPEED: type(-fly) | removes fly speed |
| SPEED: 5 max or SPEED: max(5) | none of the speeds can exceed 5
| SPEED: difficult | difficult terrain handling (halves all speeds except fly) |
| SPEED: halved | halves all speeds (after inc/dec); stackable |
| SPEED: doubled | doubles all speeds (after inc/dec); stackable |

Supports RAW encumbered (both standard and variant) and exhaustion rules. \
Coming soon: reduces speed when wearing armor the character is not strong enough to wear.

The extension updates all the speeds on the speed field in the combat tracker.  Character sheets still show base speed.  There is an optional window that shows all the speeds for a character and all the effects affecting their speed.You can have the window open automatically on your turn through an option setting.  Or you can open the window at any time by double-clicking the speed field on a character sheet or the combat tracker.

Option setting (for GM and players) to change the units that speed is displayed in.  Current choices are feet, meters, and tiles.  Automatically rounds final speed down to nearest half tile.  Another option for the GM to change the units that spell effect speeds work with.

Current Extension/Module Support: Better Combat Effects, Pets, GrimPress's 5e Automatic Effects, Team Twohy's 5e Effects Coding, Assistant GM, Mad Nomad's Character Sheet Effects Display, 5E Auto Encumbrance, Exhausted

### Other Rulesets

This extension was designed with 5e in mind, but I have ported it to work on most (all?) rulesets.

* Unable to Stand; SPEED: none; NOSTAND; Unconscious

If you would like me to add to this list, or make more specific accomodations for your ruleset, please let me know.

### Pathfinder 2e

In addition to the above universal checks, when under the Pathfinder 2e ruleset, this extension will check for the following conditions:

* Dead; Paralyzed; Dying; Immobilized; Petrified; Restrained; Grabbed; Stunned

### Still Being Developed

If you find any additional effects, where a user is not able to stand up, please let me know.  Or any other concerns or suggestions are welcome. \

Enjoy!

### Attribution

SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development. \
headerpoweratwill.webp and headerpowerenc.webp copied from included Smiteworks themes. \
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC. \
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

### Change Log

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