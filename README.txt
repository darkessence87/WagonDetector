Addon's behavior in a raid
--------------------------
This addon automatically starts tracking failures after encounter starts, and automatically stops tracking
after encounter ends or maximum deaths tracked or external command used. If there are several RL's or officers
with enabled addon main person should use macro at pull in order to prevent raiders be fined by multiple officers.

Potions are tracked as success events (if points are set < 0), so that raiders who use potions may decrease their penalty points.
Missing flasks, food or runes increase raider's penalty points.


Usefull macro
--------------------------
# start battle
/pull 10
/wd pull
--------------------------
# interrupt battle
/pull 0
/wd interrupt
--------------------------
# wipe, end battle
/rw Stop heal, wipe fast
/wd interrupt
--------------------------
