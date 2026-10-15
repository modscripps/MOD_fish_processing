# MOD_fish_processing visualizers

Standalone MATLAB GUIs for browsing fish data - `MODvis_timeseries.m`,
`MODvis_spectra.m` and `MODvis_spectra_L0.m` - plus the raw-to-L0 conversion
(`MODprocess_all_modraw_to_L0.m`), so raw files can be converted and viewed
from this branch alone. Everything here only depends on the other files
included in this branch - no other part of the repo is required.

Needs MATLAB with the Signal Processing Toolbox; raw-to-L0 conversion also
needs the Statistics and Machine Learning Toolbox.

Also here: `acquisition/`, a "Start New Deployment" window (Python) that
writes the `Setup` file `./fctd_epsi` reads, instead of editing it in vi -
see [Acquisition: Start New Deployment](#acquisition-start-new-deployment).

## Raw to L0

```matlab
L0_files = MODprocess_all_modraw_to_L0('/path/to/raw');
```

Converts every raw file in the folder to a `.mat` file in a sibling `L0`
folder (created if missing). No processing yml needed - EFE data is converted to
volts/g using the standard EFE board config. Already-converted files are
skipped, except the newest one, which is always redone in case it's still
being written - so it's safe to rerun during acquisition.

## MODvis_spectra_L0

Quick-look EFE spectra straight from L0 files, compared against ADC bit noise
(the MODSOM_liveplot use case). Timeseries rows on top, with any epsi or ctd
field on a left and optional right axis; click a row to pick the spectrum
window, and the Welch spectrum of every checked channel over that window is
plotted below, with 24/20/16-bit ADC noise lines and the ADXL accelerometer
noise. nfft, window length, overlap, taper and detrend are all editable in the
left panel, and printed above the spectrum. "Newest" re-lists the folder and
jumps to the newest file. "Export this scan" / "Export all scans" save the
spectra (plus f, noise floors, scan indices and settings) to a `.mat` file.

```matlab
MODvis_spectra_L0('/path/to/L0');
```

## MODvis_timeseries

Browse a folder of `*.mat` files (L0, L1, L2, or legacy `Profile*.mat` - any
file whose structures, e.g. `epsi`, `ctd`, `vnav`, `gps`, carry a `dnum`
field). Pick a file from the list, then choose up to 6 rows, each with a
required signal on the left y-axis and an optional second signal on its own
right y-axis. Supports nested fields (`epsi.chan1`, `ctd.P_raw`,
`gps.latitude`, ...). An x-window slider lets you scrub through a profile at a
fixed window length instead of viewing the whole time series at once.

## MODvis_spectra

Browse a folder of `*.mat` files carrying per-scan spectra, in either this
repo's own L2/profile output or a legacy MOD_fish_lib/EPSILOMETER
`Profile*.mat`. Row 1 shows pressure (and other per-scan fields, selectable
from a dropdown) for context; rows 2-3 show up to 2 raw channels each
(t1/t2/s1/s2/a1/a2/a3). Click a point in any of the 3 rows to shade that
scan's time window and plot its raw spectrum (all 7 channels, plus FP07 noise
floors, cutoff lines, and ADC bit-noise and accelerometer noise lines) in the
bottom axes, in both frequency and wavenumber. Does not open L0 files - use
`MODvis_spectra_L0` for those.

## Running them

The apps are plain classes (`classdef ... < handle`), not `.mlapp` files -
run them from the MATLAB command line or a script, not the App Designer.

### From the folder you want to browse

Add this branch's folders to your MATLAB path, optionally `cd` into the
folder of `.mat` files you want to browse, then construct the app with no
arguments - it defaults to `pwd`:

```matlab
addpath(genpath('/path/to/this/branch'))
MODvis_timeseries;
% or
MODvis_spectra;
% or
MODvis_spectra_L0;
```

### Switching folders from the GUI

Once the app is open, click the **Choose folder…** button in the top-left to
open a folder picker and switch to a different directory at any time - you
don't need to restart the app or know the path in advance.

### Pointing at a folder directly

Pass the folder path as an argument instead:

```matlab
MODvis_timeseries('/path/to/L0_L1_or_L2_folder');
% or
MODvis_spectra('/path/to/L2_or_profiles_folder');
% or
MODvis_spectra_L0('/path/to/L0_folder');
```

## Acquisition: Start New Deployment

`acquisition/start_new_deployment.py` opens a window for starting a
deployment: pick the vehicle (most fields fill in from its preset), set what
is on each AFE slot and its serial number, and build the survey name. **Create
Setup** shows the changes, then:

- backs up the current `Setup` as `Setup_replaced_YYYYMMDDHHMMSS` and writes
  the new one next to `fctd_epsi`, then reads it back the way `fctd_epsi`
  does to check every value,
- writes `<processed_root>/<survey>/meta/dev1_setup.yml` for MOD_fish_processing
  (all 7 AFE slots with names, types and serial numbers; an existing one is
  kept as `dev1_setup.yml.replaced_*`),
- appends a row to the cruise `deployment_log.csv`.

`fctd_epsi` only reads `Setup` when it starts, so restart it afterwards.

The window warns if the vehicle name and fish type disagree (MAKO or EPSI
in the name with FCTD selected, or FCTD in the name with EPSI selected).

**Winch spool** names the spool on the winch. There's one winch with one
spool on it at a time, and every vehicle uses it, so this isn't per vehicle:
the window fills in the spool used at the last Create Setup, whatever the
vehicle was. Change it only when the spool is changed - the window then warns
that the twist count restarts from 0 at this deployment. It's written to
`dev1_setup.yml` (`winch_spool:`) and the deployment log (not to `Setup` -
`fctd_epsi` doesn't use it), and the window warns if it's empty.

When the spool differs from the last row of the cruise
`<processed root>/spool_swap_log.csv` (or that file doesn't exist yet), Create
Setup appends a row to it: the UTC time, the spool, and a note. That log, not
the window's memory, is what the next Create Setup compares against. Add a row
by hand for a spool changed in the middle of a deployment (columns
`datetime_utc` as `yyyy-MM-ddTHH:mm:ssZ`, `spool_id`, `spool_length_m`,
`notes`). Processing checks the log against the `dev1_setup.yml` files
(`MODprocess_find_spool_swaps.m`), so losing either one doesn't lose a change.

If `deployment_log.csv` already exists with different columns (e.g. one
written before the winch_spool column), it's set aside as
`deployment_log_old_columns.csv` and a new log is started, so rows never end
up under the wrong headers. The Create Setup message says when this happens.

**Advanced settings** (ports, network, CTD data, raw files, calibration
paths, and where `dev1_setup.yml` and the deployment log go) default to
`config.yml`. Changes there apply to that window only - edit `config.yml`
to change them for good.

Raw file names start with the fish type - `EPSI...` for a Mako, `FCTD...`
for an FCTD - so the prefix can't be left on the wrong one.

**Create Setup** also saves what you entered for that vehicle, so picking
the vehicle next time fills in the same probes, CTD and pressure case. Every
serial number used is also added to that sensor type's dropdown.
The window opens filled in from the current `Setup` (or the first vehicle
preset if there isn't one), and warns if the survey date isn't today or the
survey name is the same as in the current `Setup`, so an old survey name
doesn't get reused by accident. Missing shear probe calibrations get a
warning; missing FP07 ones don't (they aren't normally used). **Load current Setup** fills
the window from the `Setup` again - it doesn't write or save anything.

### Setting it up on the acquisition Mac

1. Needs `python3` with tkinter (python.org or miniconda; nothing to pip
   install).
2. Edit `acquisition/config.yml` once per cruise: where `fctd_epsi`/`Setup`
   live, the calibrations folder, where processed data and the deployment log
   go, and the deck hardware shared by every vehicle (serial ports, baud
   rates, raw data folder). Use network paths (`/Volumes/DEV1_HD/...`,
   `/Volumes/DEV3_HD/...`) so they're the same from every computer.
3. Set up the **calibrations folder**: a clone of the MOD_fish_calibrations
   repo next to the software on DEV1,
   `/Volumes/DEV1_HD/Users/Shared/Software_current_cruise/MOD_fish_calibrations`
   (`calibrations_root` in `config.yml`). Cal files are kept up to date there
   with `git pull`, separately from the code. `fctd_epsi` (DEV1) and processing
   (DEV3, over the network at the same path) read the same files:
   - `SBE/<SN>.CAL` - CTD
   - `SHEAR_PROBES/<SN>/Calibration_<SN>.txt` - shear probes
   - `FPO7/<SN>/Calibration_<SN>.txt` - FP07 probes
   - `SHEAR/cap1nFres200Meg_5KohmInput.mat` - shear charge-amp response
     (processing only; without it epsilon has no electronics correction)

   `Setup` gets `<folder>/SBE`, `<folder>/SHEAR_PROBES` and `<folder>/FPO7`
   (`fctd_epsi` looks up slots 1-2 in FPO7 and 3-4 in SHEAR_PROBES, and
   records N/A for any probe file it can't find); `dev1_setup.yml` gets
   `calibrations_root: <folder>`. The same subfolders fill the serial number
   lists. The CTD path in `Setup` used to be `MOD_fish_lib/Acquisition/SBECAL`;
   MOD_fish_calibrations' `SBE/` has the same ten `.CAL` files with the same
   coefficients (checked 2026-10-15: only letter case, line endings and number
   formatting differ, plus one more digit on 0536's PTEMPA0), so moving to it
   changes no CTD calibration.
4. Check `acquisition/presets/*.yml` - one per vehicle (MAKO1-3, FCTD1-3:
   fish type, pressure case, CTD, default AFE slot layout). MAKO2 and MAKO3
   have no serial numbers yet - the window asks for them the first time. A
   vehicle can also be typed into the Vehicle box; it's remembered (and added
   to the list) after its first Create Setup. To give it defaults from the
   start, copy a preset file. The
   window remembers the last-used probes per vehicle in
   `acquisition/last_used.json`.
5. Make an alias of `acquisition/Start New Deployment.command` on the
   Desktop and double-click it.

### AFE slots

Slots 1-4 each take FP07, shear, fluorometer, microconductivity or none;
slots 5-7 are always the accelerometers a1-a3. Names follow slot order (t1/t2,
s1/s2, f1, c1). An empty slot is written as serial number `000` in `Setup`
and keeps its standard name with `type: none` in dev1_setup.yml, so slot positions
never shift. `Setup` also records each slot's type (`CTD.chN_type`), which
`fctd_epsi` ignores but copies into every `.modraw` header.

### Rules `Setup` has to follow

From `fctd_epsi`'s source (`main.c` ReadSetupFile, `file_utils.c`,
`ctd.h`, `fctd_epsi.c`); the window enforces all of them:

- No empty value for any key `fctd_epsi` reads (`KEY=''` makes it segfault -
  why the earlier `convert_yaml_to_setup.py` output crashed it).
- Values can't contain spaces, `'`, `,`, `=`, `#` or `//`.
- Names (survey, vehicle, probe serial numbers, ports, ...) are at most 31
  characters - longer ones silently run into the next field.
- The whole file must stay under ~2000 bytes (it is copied into every
  `.modraw` header through a fixed-size buffer). So `Setup` has a single
  comment line - when and how it was written - and no section notes.
- Keys `fctd_epsi` never reads (`CTD.MicroCond`, `CTD.Compass`,
  `CTD.output_format`, `CTD.ch1-4_type`) are still written: they end up in
  every `.modraw` header, so a raw file says what was on each slot.

`dev1_setup.yml` says what is on the vehicle (survey, vehicle, winch spool,
`calibrations_root`, CTD and AFE slot serial numbers). The processing that
reads it (`MODsetup_build_yaml.m`, which merges it with the cruise processing
parameters into `depl_meta_data.yml`, and `MODprocess_find_spool_swaps.m`)
is not on this branch.
