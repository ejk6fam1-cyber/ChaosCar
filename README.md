# Chaos Car (Godot 4.7)

Top-down retro superspeedway racing on a Talladega-shaped 2.66-mile tri-oval: 64 stock cars, 7 lanes,
pack drafting. You don't steer freely: you tap left or right to jump one lane, only if nobody is in the
way. Your speed comes entirely from the air and the bumpers: who you're drafting, who's pushing you,
and whether you're in the pack.

The track: a 4,000 ft back stretch, two 155-degree banked ends, and a front stretch of two angled
chutes joined by the 50-degree tri-oval curve in front of the grandstands. As at the real track, the
start/finish line is on the chute between the tri-oval and turn 1.

## Menus
- **Single Player:** choose laps (1-20) and the starting grid. **Random spots** puts you somewhere
  random; with **Pick your spot** you choose (1 = pole, odd = inside row, even = outside).
- **Online Race:** **Create a Race** gives you a 4-letter code; friends **Join** with it (up to 4
  players, with computer drivers in the rest of the 64-car field). The host sets laps and the grid;
  with pick-your-spot everyone picks their own. See **SETUP.md** to put the game and its server online.
- After the race: the full finishing order for all 64 cars, with **Race again** (or **Back to lobby**
  online) and **Return to menu**.

## Difficulty
- **Normal:** a lane switch, by you or the AI, only happens if it still fits a split second later at
  everyone's current speeds. Online, your screen only shows the switch straight away when the server will
  surely accept it, so you never get snapped back.
- **Hardcore:** your switches always happen. Moving into a car, or hitting one at more than about 18 mph,
  wrecks both cars: they spin and slide off, and are out of the race (DNF). The computer drivers dodge
  wrecks they see up to about 220 m ahead, after a split-second reaction, swerving up to two lanes. About
  once every 10 laps an AI driver misjudges a move into a car alongside and starts a pile-up.

## Controls
| Key | Action |
|---|---|
| A / D or Left / Right (tap) | Switch one lane left / right (refused if the lane is taken: your radar marker flashes red) |
| R | Restart (single player) |
| Esc | Back to the menu |

## Race screen
Position, lap, speed and gap to the leader in car lengths. The **DRAFT** and **PUSH** lights glow green
when you have them and red when you don't. The track map shows the whole field, and the radar on the
right shows the cars around you. Other human players are marked by name.

## Files
- `scripts/race.gd` runs the race. It works in three modes: local (single player), server (online, no
  screen) and client (online, shows what the server sends).
- `scripts/net.gd` handles online rooms, the lobby and car updates. `scripts/main.gd` handles the menus.
- `scripts/oval.gd` is the track shape. `scripts/track_view.gd` draws it, and `scripts/race_hud.gd`
  draws the race screen.
- `Dockerfile` and `render.yaml` are the server. `.github/workflows/web.yml` builds the browser game.
  `SETUP.md` explains how to put it online.
- `test/` holds headless tests: `sim` (full race), `slingshot`, `chase` and `netbot` (online
  players; run two against a local server).

## How speed works (`scripts/race.gd`)
Everyone has the same engine (within 1%). What changes is drag:
- **Draft**: tucked in behind a car, your drag drops by up to 28%. The tow fades with the gap but reaches a
  long way, and a second car further up the line helps a little too.
- **Push**: a car right behind you cuts your drag by up to 14%. Each extra car in the line behind adds
  more, up to 8 cars. Lines push themselves faster, so a long line beats a short one.
- **Momentum**: changing lanes never costs speed. Speed built up in a draft carries into the new lane, and
  the draft's tow fades over about half a second after you pull out. Follow a car, close in, then switch
  lanes about a car length or two back and you slingshot past.
- **Side draft**: a car alongside your rear quarter steals some of your air.
- **Pack bubble / wake**: the pack drags slow air along and tows dropped cars back up. The leader gets none
  of it, so leading is hard.
- **Bump drafting**: run into the car ahead and you shove it along.
The HUD shows your DRAFT, PUSH and PACK meters, your line length, total aero gain, and your closing
speed on the car ahead in your lane.

## The computer drivers
They use the same 5 lanes and the same rules. They follow the car they're drafting when it moves over, so
lines move together. They lift for a moment to open a gap, then use the run to slingshot past. They also
make moves late in the race and block runs coming up the next lane. Nobody slides into a car alongside.
If a gap closes mid-move, the car goes back to its own lane.

## Collisions
Cars have equal mass and momentum is conserved. Run into the car ahead and it takes on your speed (a hard hit
bounces a little). Stay on its bumper and your engine keeps pushing it: cars in contact move as one body,
so a tandem or a train is faster than a single car. The computer drivers are very reluctant to leave a
bumper-to-bumper train; cars out on their own hunt for a line to join.

## Keeping it lively
- **Push only by contact:** you only get pushed by a car literally on your bumper. In a line, every car
  runs faster the more cars are touching nose to tail behind it (up to 12). A gap breaks the chain.
- **Chasing a train:** a long line punches a big hole in the air. A car chasing it from behind (not yet on
  its bumper) gets a stronger tow that reaches further back, enough to catch even the fastest train.
  In the test, a car 30 m behind a 10-car train catches it in about 10 s and hits its bumper about 15 mph
  faster.
- **Breaking up a runaway line:** when a big line (7+ cars) is out front, the computer cars from 4th place
  back in it know they'll never win from there. A group of 3-5 of them jumps out together to start a new
  line. The hole they leave cuts the big line off from its pushers, so it slows down until the gap closes.
- **Speed randomizer:** every computer car has its own base power (up to 7% either way; yours is exactly
  average), and its form drifts up and down by up to 6% over the race.
- **Catch-up tow:** a group that falls behind the group ahead gets towed back up as a whole.
