# FixGroups v1.4.1
## Addon by bencvt, backported by Kader

Organizing groups is an important, if sometimes tedious, part of running a raid. This addon helps automate the process.

Instead of manually dragging players around in the raid tab, just click a **single button** to set things up the way you want:

* **Rearrange** players so that tanks, melee, ranged, and healers are grouped together. Your priest healers will thank you.

* **Mark** tanks and ensure they have **assist**.

Other features:

* **Split** your raid into two roughly equal sides for raid encounters that need it. Manually combing through damage meters to ensure that your heavy hitters are spread appropriately is for the birds. FixGroups takes care of that for you, integrating with your damage meter addon directly. **Recount**, **Skada**, **TinyDPS**, and **Details!** are all supported.

* **Choose** a "volunteer" when you need someone to handle a certain mechanic in a fight using the **`/choose`** console command. You can narrow down the candidate pool by using **`/choose ranged`**, **`/choose hunter`**, etc. This command has many other uses as well. Type **`/choose`** in-game for details.

* **Track** your group comp automatically. An example comp is **`2/4/13 (5+8)`**, which is shorthand for *"a group composed of 2 tanks, 4 healers, and 13 dps, 5 of which are melee and 8 of which are ranged."*

* Whenever a player joins or leaves your group, the **server message** now includes the player's role and the new comp. Example: *"Darion (Melee) has joined the raid group. 2/4/14 (6+8)."*

* Add the group comp to your UI if you're running a **Data Broker** display addon (**Titan Panel**, **ChocolateBar**, **ElvUI**, etc.) FixGroups makes the comp available as a Data Broker object (a.k.a. LDB plugin).