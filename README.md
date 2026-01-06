# EXPT_LangLoc_audio
This repository contains the auditory version of EvLab's language localizer programmed using Psychtoolbox-3 in MATLAB.

https://github.mit.edu/EvLab/LangLoc_audio


### Example run recording

https://www.dropbox.com/scl/fi/d1jyoposu8go30rwsrn29/langloc_audio.mov

### Prerequisites

Do **_not_** run this experiment in the same session as LanglocVideo.

If the same participant is doing standard (reading) Langloc and you're either a) running LanglocAudio in the same session or b) running LanglocAudio within the same multi-session experiment, make sure to **use a DIFFERENT order** of stim for LanglocAudio. For example, if you use Order 1 in LangLoc, use Order 2 in LanglocAudio. These experiments share stim so it's important the participant isn't hearing the intact versions of the LangLoc sentences they read.

To run this experiment, make sure you have the following installed:
- `Matlab`
- `Psychtoolbox-3 (3.0.17.10)` 
(to verify, open Matlab and type `PsychtoolboxVersion`; it should print out a version number)

If you do not, please [install Matlab](https://ist.mit.edu/matlab/all).
Then follow the [instructions to install PTB-3 from a zip/tar.gz file](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/3.0.17.10).

### Usage

The IPS for a run of LanglocAudio is `179`. Each run takes 5 minutes 58 seconds.

1. Open `matlab`
2. `cd` to the directory containing the experiment *
3. Run the matlab script `LanglocAudio('SUBJECT_ID', RUN, ORDER)`

\* It is recommended to play a sample of the stim audio (open the stim folder and play a clip) to ensure the audio is coming through to the participant. 

Perform two runs of this task during the scan session. Note that RUN and ORDER are **flipped** from the standard LangLoc. LanglocAudio is `(RUN, ORDER)` as opposed to `(ORDER, RUN)`. 

Example of a first run call: `LanglocAudio('FED_20190724a_3T2',1,1)`

Example of a second run call: `LanglocAudio('FED_20190724a_3T2',2,1)`

### Task instructions

> _In this task, you will be listening to some audio clips. Some audio clips you will be able to understand. Others will sound like sounds obscured by heavy radio static. There is_ no _button pressing during this task. All you need to do is listen to all of the audio clips._
>
> _If the volume is too QUIET during the task, push Button 1 repeatedly and we will turn up the volume until you stop._ (Have them push 1 after this to confirm finger is on correct button).
> 
> _If the volume is too LOUD during the task, push Button 2 repeatedly and we will turn down the volume until you stop._ 
> 
> _Do you have any questions before we start this task?_


\* It is recommended to play a sample of the stim audio (open the stim folder and play a clip) to ensure the audio is coming through to the participant.

### Tips for scanning with audio (applicable to most audio experiments)

- Make sure your computer volume is turned on.
- Always double check audio is coming from both earbuds when setting up, before the participant arrives (hold both up to your ear without the buds on).
- Double check the earbud sound for the participant once they lay down in the HEP part of the head coil! Have the seconder talk to them from the console room. The head coil check is necessary, as sometimes the buds get pushed too far in the participant's ear canal when they're lying down with cushions. This can lead to them not hearing one or both ears' audio. Better to check this before they roll into the tube!
- Communicate how they can adjust the volume if for some reason it is unbearable during a run. Say:
> _If it's too quiet, push Button 1 repeatedly and we will turn up the volume until you stop._ (Have them push 1 after this to confirm finger is on correct button).
  > _If it's too loud, push Button 2 repeatedly and we will turn down the volume until you stop._ 

### Backing up

This experiment uses `git` to backup experiment code as well
as data across evlab computers and openmind. The backups are
hosted at [`github.mit.edu/EvLab/EXPT_LangLoc_audio`](https://github.mit.edu/EvLab/EXPT_LangLoc_audio.git)
and require MIT login to access. The following section will
guide you about how to backup the files.

1. make sure there are no loose ends: 
    - `git status` should print out *nothing to commit*
    - if it prints *Changes to be committed: ...*, it means someone did not commit files from a prior session.
     You should carefully look at what files are "staged", and write a commit message if the files should be
     backed up. If they should not be backed up, simply do `git reset` (this only "unstages" files, it does
     not delete anything).
1. identify the data files generated from current session
    - check the `data/` subdirectory.
    - identify the filename (e.g., `TEST_1_data.txt`)
1. "stage" the file for backup: `git add data/TEST_1_data.txt`
1. "commit" the file (be **sure** you have the correct file/s) with a helpful descriptor
    - `git commit --author="Your Name <youremail@mit.edu>" -m "Added data file from scanning session on 1970-01-01 at 2:43pm, session ID FED19700101 blah blah"`
1. `git push` to transmit your changes to the remote copy at `mit.github.edu`
    - if git complains about changes on the remote, you may have to pull first before you push
    `git pull`
