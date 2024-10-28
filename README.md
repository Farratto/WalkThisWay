## Walk This Way

**Current Version**: ~dev_version~ \
**Updated**: ~date~

This extension provides a small popup window at the start of a person's turn that asks if they want to stand up. It happens when a character is prone but does not have one of the conditions that prevents them from standing up.

### Installation

Install from the [Fantasy Grounds Forge](https://forge.fantasygrounds.com/shop/items/1940/view). \
You can find the source code at Farratto's [GitHub](https://github.com/Farratto/WalkThisWay/releases). \
You can ask questions at the [Fantasy Grounds Forum](https://www.fantasygrounds.com/forums/showthread.php?82914-Walk-this-Way-for-5e). \

### Details

On turn start, the extension will check the character, whose turn just started, for the prone condition.  If it finds it, it will check if that same actor has any of the following effects:

* Grappled; Paralyzed; Petrified; Restrained; Unconscious; Tasha's Hideous Laughter; Unable to Stand; SPEED: none; NOSTAND

If the actor has prone, but not any of the above effects, the extension will provide a small popup window to the screen of the party that controls that character.  The window asks if the person wants to stand up.  If they answer yes, the extension will remove the effect that contains prone and add an effect that says "SPEED: 0.5" that lasts until end of turn.  If they answer no, close the window, or ignore the window, the extension will do nothing. \
The window can be moved and it remembers where it was.  It can be ignored and it will go away at the end of turn without consequences. \
Current Extension/Module Support: Better Combat Effects, Pets, GrimPress's 5e Automatic Effects, & Team Twohy's 5e Effects Coding

### Other Rulesets

This extension was designed with 5e in mind, but I have ported it to work on most (all?) rulesets.  If you're running a ruleset other than 5e, it will check for prone and much less specific settings for not being able to stand:

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
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC. \
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

### Change Log

* 1.4.3: Pets extension support. Query Window Improved.
* 1.4.2: More specific support for Pathfinder 2e added.
* 1.4.0: Ported for other rulesets.
* 1.3.4: Bug reported in interaction with BCE. Fixed
* 1.3.3: Made query window more theme-friendly.
* 1.3.2: Added Support for Team Twohy's 5e Effects Coding. Made changes under the hood to improve accuracy and efficiency.
* 1.2.5: New Options allowing players to individually disable the reminder windows (if DM allows).
* 1.2.0: Now will only delete entire effect line if you ask it to. Added a toggle option to turn the extension on/off live. Full support added for BCE & FZ.