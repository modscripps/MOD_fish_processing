# MOD_fish_processing visualizers

Standalone MATLAB GUIs for browsing fish data - `MODvis_timeseries.m`,
`MODvis_spectra.m` and `MODvis_spectra_L0.m` - plus the raw-to-L0 conversion
(`MODprocess_all_modraw_to_L0.m`), so raw files can be converted and viewed
from this branch alone. Everything here only depends on the other files
included in this branch - no other part of the repo is required.

Needs MATLAB with the Signal Processing Toolbox; raw-to-L0 conversion also
needs the Statistics and Machine Learning Toolbox.

## Raw to L0

```matlab
L0_files = MODprocess_all_modraw_to_L0('/path/to/raw');
```

Converts every raw file in the folder to a `.mat` file in a sibling `L0`
folder (created if missing). No setup.yml needed - EFE data is converted to
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
