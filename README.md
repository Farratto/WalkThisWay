# Walk This Way
## Features
* If turn starts and character is prone and not unconscious, it asks if they want to use half their movement speed to stand up.

## Installation
Download [WalkThisWay.ext](https://github.com/Farratto/WalkThisWay/releases) and place in the extensions subfolder of the Fantasy Grounds data folder.  Or download from the Forge!

## Attribution
SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development.
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC.
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

##Details
On turn start, the extension will check the character, whose turn just started, for the prone condition.  If it finds it, it will check if that same actor has any of the following effects:
Grappled, Paralyzed, Petrified, Restrained, Unconscious, SPEED: none, Tasha's Hideous Laughter, Unable to Stand, & NoStand.
If the actor has prone, but not any of the above effects, the extension will provide a small popup window to the screen of the party that controls that character.  The window asks if the person wants to stand up.  If they answer yes, the extension will remove the effect that contains prone and add an effect that says "SPEED: 0.5" that lasts until end of turn.  If they answer no, close the window, or ignore the window, the extension will do nothing.
The window can be moved and it remembers where it was.  It can be ignored and it will go away at the end of turn without consequences.

##Known Limitations
"Prone" should be on an effect by itself.  Not all code writers adhere to this best practice.  If prone is part of a larger effect, the entire effect will be deleted.  Example: "Complex Effect; Poisoned; Grappled; DMGO: 1d6 fire; Prone; So Many Things".  The entire effect will be deleted if the user hits yes.

##Still Being Developed
Hopefully I'll have the limiations above addressed soon.  Thank you for your patience.
If you find any additional effects, where a user is not able to stand up, please let me know.  Or any other concerns or suggestions are welcome.  Enjoy!