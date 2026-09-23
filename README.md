# MOD_fish_processing visualizers

Two standalone MATLAB App Designer-style GUIs for browsing processed fish
data: `MODvis_timeseries.m` and `MODvis_spectra.m`. Both live in
`visualization/` and only depend on the handful of `processing/scans/*.m`
functions included in this branch - no other part of the repo is required to
run them.

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
floors and cutoff lines) in the bottom axes, in both frequency and wavenumber.

## Running them

Both apps are plain classes (`classdef ... < handle`), not `.mlapp` files -
run them from the MATLAB command line or a script, not the App Designer.

### From the folder you want to browse

Add `visualization/` and `processing/scans/` to your MATLAB path, optionally
`cd` into the folder of `.mat` files you want to browse, then construct the
app with no arguments - it defaults to `pwd`:

```matlab
addpath('visualization', 'processing/scans')
MODvis_timeseries;
% or
MODvis_spectra;
```

### Switching folders from the GUI

Once the app is open, click the **Choose folder…** button in the top-left to
open a folder picker and switch to a different directory at any time - you
don't need to restart the app or know the path in advance.

### Pointing at a folder directly

Pass the folder path as an argument instead:

```matlab
MODvis_timeseries('/path/to/L1_or_L2_folder');
% or
MODvis_spectra('/path/to/L2_or_profiles_folder');
```


