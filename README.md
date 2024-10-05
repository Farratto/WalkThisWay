# Walk This Way
## Features
* This extension provides a small popup window at the start of a person's turn that asks if they want to stand up. It happens when a character is prone but does not have one of the conditions that prevents them from standing up.

## Installation
Download from the forge at https://forge.fantasygrounds.com/shop/items/1940/view.
Forum Thread: https://www.fantasygrounds.com/forums/showthread.php?82914-Walk-this-Way-for-5e
Source code available at [WalkThisWay.ext](https://github.com/Farratto/WalkThisWay/releases).

## Details
On turn start, the extension will check the character, whose turn just started, for the prone condition.  If it finds it, it will check if that same actor has any of the following effects:

Grappled, Paralyzed, Petrified, Restrained, Unconscious, Tasha's Hideous Laughter, Unable to Stand, SPEED: none, & NOSTAND.

If the actor has prone, but not any of the above effects, the extension will provide a small popup window to the screen of the party that controls that character.  The window asks if the person wants to stand up.  If they answer yes, the extension will remove the effect that contains prone and add an effect that says "SPEED: 0.5" that lasts until end of turn.  If they answer no, close the window, or ignore the window, the extension will do nothing.

The window can be moved and it remembers where it was.  It can be ignored and it will go away at the end of turn without consequences.

Current Extension/Module Support: Better Combat Effects, Friend Zone, GrimPress's 5e Automatic Effects, & Team Twohy's 5e Effects Coding

## Still Being Developed
If you find any additional effects, where a user is not able to stand up, please let me know.  Or any other concerns or suggestions are welcome.

Enjoy!


## Attribution
SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development.
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC.
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.
