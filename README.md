# rudiments

an 8 voice lofi percussion synthesizer...

## Installation

[Download latest release](https://github.com/cfdrake/rudiments/archive/master.zip) and copy files into `~/dust/code/rudiments`.

Or use Git:

```
<ssh into your Norns>
$ cd ~/dust/code
$ git clone https://github.com/cfdrake/rudiments.git
```

Note that after installing you must `SYSTEM => RESET` your Norns before running this script, as it includes a new SuperCollider engine.

## Norns Script

Each voice may be configured and MIDI mapped under `PARAMS`. Playing notes C-G in any octave will trigger the matching voice.

- C: voice 1
- C#: voice 2
- D: voice 3
- D#: voice 4
- E: voice 5
- F: voice 6
- F#: voice 7
- G: voice 8

At the moment there is built-in no sequencer, so the engine must be triggered by external gear.

Pressing `KEY3` on Norns will randomize the drumkit sounds.

## SuperCollider Engine

This script makes a new SuperCollider engine available, `Rudiments`. Please see `lib/engine_rudiments.sc` for the latest parameter definitions.
