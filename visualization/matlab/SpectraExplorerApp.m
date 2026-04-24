classdef SpectraExplorerApp < handle
    % SpectraExplorerApp
    % Browse Profile*.mat files and interactively view temperature gradient
    % spectra (t1, t2) and chi at selectable depths.
    %
    % Usage:
    %   app = SpectraExplorerApp();               % opens folder chooser
    %   app = SpectraExplorerApp('/path/to/profiles');
    %
    % Layout (right panel, 2 rows × 3 cols):
    %   Row 1: t1_volt timeseries | t1 Tg spectrum | chi1 profile
    %   Row 2: t2_volt timeseries | t2 Tg spectrum | chi2 profile
    %
    % Requires on MATLAB path:
    %   get_scan_spectra, batchelor, epsiSetup_set_plot_properties,
    %   get_filters_SOM (optional, for noise lines)

    properties
        Fig       matlab.ui.Figure

        % Sidebar
        FolderBtn   matlab.ui.control.Button
        FolderLbl   matlab.ui.control.Label
        FileList    matlab.ui.control.ListBox
        PrevBtn     matlab.ui.control.Button
        NextBtn     matlab.ui.control.Button
        DepthField  matlab.ui.control.NumericEditField
        DepthLbl    matlab.ui.control.Label
        ScanInfoBox matlab.ui.control.TextArea

        % 6 plot axes (matched to epsiPlot numbering)
        %   Ax(1) = chi1 profile   (row1, col3)
        %   Ax(2) = t1_volt        (row1, col1)
        %   Ax(3) = t1 Tg spectrum (row1, col2)
        %   Ax(4) = chi2 profile   (row2, col3)
        %   Ax(5) = t2_volt        (row2, col1)
        %   Ax(6) = t2 Tg spectrum (row2, col2)
        Ax

        % Data state
        Folder      string  = ""
        Files       string  = strings(0,1)
        Profile     struct  = struct()
        CurrentFile string  = ""
        ValidK      double  = []   % valid indices into Profile.pr
        CurrentKIdx double  = 1    % index into ValidK

        % Colors
        Colors struct

        % Handles to depth-marker ylines. Order: [chi1, chi2, t1prof, t2prof]
        DepthLineHandles
        % Handles to scan-region patch objects on the full-profile axes
        ScanPatchHandles
    end

    methods
        %% ----------------------------------------------------------------
        function app = SpectraExplorerApp(folder)
            try
                pp = epsiSetup_set_plot_properties();
                app.Colors = pp.Colors;
            catch
                app.Colors = struct( ...
                    't1',          [29  78  140]./255, ...
                    't2',          [78  173 173]./255, ...
                    'batch_s1t1',  [0.4902 0.1647 0.4706], ...
                    'batch_s1t2',  [0.6784 0.1529 0.6431], ...
                    'batch_s2t1',  [0.8353 0.1059 0.7922], ...
                    'batch_s2t2',  [0.9679 0.4079 0.6317]);
            end

            app.buildUI();

            if nargin >= 1 && ~isempty(folder)
                app.loadFolder(string(folder));
            end
        end

        %% ----------------------------------------------------------------
        function buildUI(app)
            app.Fig = uifigure('Name', 'Spectra Explorer', ...
                'Position', [50 50 1900 900]);

            % Top-level grid: sidebar | plots
            mainGL = uigridlayout(app.Fig, [1 2]);
            mainGL.ColumnWidth  = {260, '1x'};
            mainGL.RowHeight    = {'1x'};
            mainGL.Padding      = [8 8 8 8];
            mainGL.ColumnSpacing = 8;

            %% Left sidebar -----------------------------------------------
            sidePanel = uipanel(mainGL, 'BorderType', 'none');
            sidePanel.Layout.Row    = 1;
            sidePanel.Layout.Column = 1;

            % 11 rows: btn | lbl | list | sep | hdr | navBtns | depthField
            %          | depthInfo | infoBox | spacer
            sideGL = uigridlayout(sidePanel, [10 1]);
            sideGL.RowHeight = {32, 36, '2x', 18, 24, 32, 32, 22, '1x', 10};
            sideGL.Padding      = [4 4 4 4];
            sideGL.RowSpacing   = 4;

            % Folder button
            app.FolderBtn = uibutton(sideGL, 'Text', 'Choose Folder...', ...
                'ButtonPushedFcn', @(~,~) app.chooseFolder());
            app.FolderBtn.Layout.Row = 1;  app.FolderBtn.Layout.Column = 1;

            % Folder path label
            app.FolderLbl = uilabel(sideGL, 'Text', '(no folder)', ...
                'WordWrap', 'on', 'HorizontalAlignment', 'left', ...
                'FontSize', 10, 'FontColor', [0.4 0.4 0.4]);
            app.FolderLbl.Layout.Row = 2;  app.FolderLbl.Layout.Column = 1;

            % Profile file listbox
            app.FileList = uilistbox(sideGL, 'Items', {}, ...
                'ValueChangedFcn', @(~,~) app.onFileSelected());
            app.FileList.Layout.Row = 3;  app.FileList.Layout.Column = 1;

            % Section separator
            sepLbl = uilabel(sideGL, 'Text', '─── Depth Navigation ───', ...
                'HorizontalAlignment', 'center', 'FontSize', 10, ...
                'FontColor', [0.5 0.5 0.5]);
            sepLbl.Layout.Row = 4;  sepLbl.Layout.Column = 1;

            % "Depth (m):" header
            hdrLbl = uilabel(sideGL, 'Text', 'Depth (m):', 'FontWeight', 'bold');
            hdrLbl.Layout.Row = 5;  hdrLbl.Layout.Column = 1;

            % Prev / Next button row
            navGL = uigridlayout(sideGL, [1 2]);
            navGL.Layout.Row = 6;  navGL.Layout.Column = 1;
            navGL.ColumnWidth = {'1x', '1x'};
            navGL.RowHeight   = {'1x'};
            navGL.Padding     = [0 0 0 0];
            navGL.ColumnSpacing = 6;

            app.PrevBtn = uibutton(navGL, 'Text', '◄ Prev', ...
                'ButtonPushedFcn', @(~,~) app.onPrev(), 'Enable', 'off');
            app.PrevBtn.Layout.Row = 1;  app.PrevBtn.Layout.Column = 1;

            app.NextBtn = uibutton(navGL, 'Text', 'Next ►', ...
                'ButtonPushedFcn', @(~,~) app.onNext(), 'Enable', 'off');
            app.NextBtn.Layout.Row = 1;  app.NextBtn.Layout.Column = 2;

            % Numeric depth input
            app.DepthField = uieditfield(sideGL, 'numeric', ...
                'Value', 0, 'Limits', [0 Inf], ...
                'ValueChangedFcn', @(~,~) app.onDepthEntered(), ...
                'Enable', 'off');
            app.DepthField.Layout.Row = 7;  app.DepthField.Layout.Column = 1;

            % "Scan k / N" display
            app.DepthLbl = uilabel(sideGL, 'Text', '', ...
                'HorizontalAlignment', 'center', 'FontSize', 10);
            app.DepthLbl.Layout.Row = 8;  app.DepthLbl.Layout.Column = 1;

            % Scan statistics text box
            app.ScanInfoBox = uitextarea(sideGL, 'Value', '', ...
                'Editable', 'off', 'FontSize', 10, ...
                'BackgroundColor', [0.95 0.95 0.95]);
            app.ScanInfoBox.Layout.Row = 9;  app.ScanInfoBox.Layout.Column = 1;

            %% Right plot panel -------------------------------------------
            plotPanel = uipanel(mainGL, 'BorderType', 'none');
            plotPanel.Layout.Row    = 1;
            plotPanel.Layout.Column = 2;

            % 2 rows × 4 cols: [full profile | scan volt | spectrum | chi]
            plotGL = uigridlayout(plotPanel, [2 4]);
            plotGL.ColumnWidth   = {'1x', '1x', '2x', '1x'};
            plotGL.RowHeight     = {'1x', '1x'};
            plotGL.Padding       = [4 4 4 4];
            plotGL.ColumnSpacing = 8;
            plotGL.RowSpacing    = 8;

            % Axis index → {row, col}
            %   Ax(1)=chi1       Ax(2)=t1volt(scan)  Ax(3)=t1spec
            %   Ax(4)=chi2       Ax(5)=t2volt(scan)  Ax(6)=t2spec
            %   Ax(7)=t1profile  Ax(8)=t2profile
            axPositions = {[1,4],[1,2],[1,3],[2,4],[2,2],[2,3],[1,1],[2,1]};
            app.Ax = gobjects(1,8);
            for i = 1:8
                ax = uiaxes(plotGL);
                ax.Layout.Row    = axPositions{i}(1);
                ax.Layout.Column = axPositions{i}(2);
                ax.FontSize = 12;
                grid(ax, 'on');
                app.Ax(i) = ax;
            end
            app.DepthLineHandles = gobjects(1,4);  % [chi1, chi2, t1prof, t2prof]
            app.ScanPatchHandles = gobjects(1,2);  % [t1prof, t2prof]
        end

        %% ----------------------------------------------------------------
        function chooseFolder(app)
            startDir = app.Folder;
            if startDir == "" || ~isfolder(startDir)
                startDir = pwd;
            end
            folder = uigetdir(startDir, 'Select Profiles Folder');
            if folder ~= 0
                app.loadFolder(string(folder));
            end
        end

        %% ----------------------------------------------------------------
        function loadFolder(app, folder)
            app.Folder = folder;

            % Shorten label
            parts = strsplit(folder, filesep);
            if numel(parts) > 3
                displayPath = ['...' filesep strjoin(parts(end-2:end), filesep)];
            else
                displayPath = folder;
            end
            app.FolderLbl.Text = displayPath;

            d = dir(fullfile(folder, 'Profile*.mat'));
            if isempty(d)
                app.FileList.Items = {};
                app.Files = strings(0,1);
                app.ScanInfoBox.Value = {'No Profile*.mat files found.'};
                return
            end

            app.Files = string({d.name}');
            app.FileList.Items = cellstr(app.Files);
            app.FileList.Value = app.FileList.Items{1};
            app.onFileSelected();
        end

        %% ----------------------------------------------------------------
        function onFileSelected(app)
            if isempty(app.FileList.Items), return; end
            fname = app.FileList.Value;
            if isempty(fname), return; end

            filepath = fullfile(app.Folder, fname);
            app.ScanInfoBox.Value = {'Loading...'};
            drawnow;

            try
                S = load(filepath);
                app.Profile = S.Profile;
                app.CurrentFile = fname;
            catch ME
                app.ScanInfoBox.Value = {['Error loading: ' ME.message]};
                return
            end

            app.patchCalibrationPaths();
            app.computeValidK();

            if isempty(app.ValidK)
                app.ScanInfoBox.Value = {'No valid scans found.'};
                app.PrevBtn.Enable  = 'off';
                app.NextBtn.Enable  = 'off';
                app.DepthField.Enable = 'off';
                return
            end

            app.PrevBtn.Enable    = 'on';
            app.NextBtn.Enable    = 'on';
            app.DepthField.Enable = 'on';

            validDepths = app.Profile.pr(app.ValidK);
            app.DepthField.Limits = [min(validDepths), max(validDepths)];

            % Start near the middle of the valid depth range
            app.CurrentKIdx = round(numel(app.ValidK) / 2);
            app.goToScan(app.ValidK(app.CurrentKIdx));
        end

        %% ----------------------------------------------------------------
        function patchCalibrationPaths(app)
            % 1. Inject hardcoded FPO7 noise so get_scan_spectra never
            %    needs to load from a file path (paths differ per machine).
            FPO7noise_Tdiff   = struct('n0',-11.7035,'n1', 0.2758,'n2', 1.4272,'n3',-0.8244);
            FPO7noise_notdiff = struct('n0',-12.2172,'n1',-0.9104,'n2', 1.3882,'n3',-0.5674);

            try
                tempChoice = app.Profile.Meta_Data.MAP.temperature;
            catch
                try
                    tempChoice = app.Profile.Meta_Data.AFE.temp_circuit;
                catch
                    tempChoice = 'Tdiff';
                end
            end

            if strcmp(tempChoice, 'Tdiff')
                app.Profile.Meta_Data.MAP.Tnoise1 = FPO7noise_Tdiff;
            else
                app.Profile.Meta_Data.MAP.Tnoise1 = FPO7noise_notdiff;
            end
            app.Profile.Meta_Data.PROCESS.adjustTemp = true;

            % 3. Ensure epsi.P exists — needed for full-profile depth plots.
            if ~isfield(app.Profile.epsi, 'P') || ...
               numel(app.Profile.epsi.P) ~= numel(app.Profile.epsi.time_s)
                app.Profile.epsi.P = interp1(app.Profile.ctd.time_s, ...
                    app.Profile.ctd.P, app.Profile.epsi.time_s, 'linear', 'extrap');
            end

            % 2. Ensure volts_to_C exists — mod_efe_scan_chi needs it.
            %    Older profiles only have AFE.t1.cal (dTdV scalar). If the
            %    field is missing, compute it via linear regression of the
            %    FPO7 voltage against CTD temperature (same as processing).
            needsCal = ~isfield(app.Profile.Meta_Data.AFE.t1, 'volts_to_C') || ...
                       ~isfield(app.Profile.Meta_Data.AFE.t2, 'volts_to_C');
            if needsCal
                try
                    app.Profile.Meta_Data = mod_epsi_linear_calibration_FP07(app.Profile, 0);
                catch ME
                    % Fallback: build volts_to_C from the scalar cal field.
                    % slope = cal, intercept = 0 (less accurate but functional).
                    warning('SpectraExplorerApp: mod_epsi_linear_calibration_FP07 failed (%s). Using cal field as slope.', ME.message);
                    app.Profile.Meta_Data.AFE.t1.volts_to_C = [app.Profile.Meta_Data.AFE.t1.cal, 0];
                    app.Profile.Meta_Data.AFE.t2.volts_to_C = [app.Profile.Meta_Data.AFE.t2.cal, 0];
                end
            end
        end

        %% ----------------------------------------------------------------
        function computeValidK(app)
            % Determine which scan indices stay within profile bounds,
            % without computing any spectra (fast index arithmetic only).
            Meta_Data = app.Profile.Meta_Data;
            try
                Fs_epsi = Meta_Data.PROCESS.Fs_epsi;
            catch
                Fs_epsi = Meta_Data.AFE.FS;
            end
            dof    = Meta_Data.PROCESS.dof;
            nfft   = Meta_Data.PROCESS.nfft;
            N_epsi = (dof - 1) * nfft;
            Fs_ctd = Meta_Data.PROCESS.Fs_ctd;
            tscan  = N_epsi / Fs_epsi;
            N_ctd  = tscan * Fs_ctd - mod(tscan * Fs_ctd, 2);

            LCTD  = length(app.Profile.ctd.P);
            LEPSI = length(app.Profile.epsi.time_s);
            nScans = length(app.Profile.pr);
            valid  = false(1, nScans);

            for k = 1:nScans
                Pr = app.Profile.pr(k);
                [~, indP] = min(abs(app.Profile.ctd.P - Pr));
                ics = indP - N_ctd/2;
                ice = indP + N_ctd/2 - 1;

                ind_Pr_epsi = find( ...
                    app.Profile.epsi.dnum < app.Profile.ctd.dnum(indP), 1, 'last');
                if isempty(ind_Pr_epsi), continue; end
                iss = ind_Pr_epsi - N_epsi/2;
                ise = ind_Pr_epsi + N_epsi/2 - 1;

                if ics > 0 && ice <= LCTD && iss > 0 && ise <= LEPSI
                    valid(k) = true;
                end
            end
            app.ValidK = find(valid);
        end

        %% ----------------------------------------------------------------
        function goToScan(app, k)
            app.ScanInfoBox.Value = {sprintf('Computing scan at %.1f m…', ...
                app.Profile.pr(k))};
            drawnow;

            try
                scan = get_scan_spectra(app.Profile, k);
            catch ME
                app.ScanInfoBox.Value = {['get_scan_spectra error: ' ME.message]};
                return
            end

            if ~isfield(scan, 'Pt_Tg_k')
                app.ScanInfoBox.Value = {'Scan out of bounds — try a different depth.'};
                return
            end

            try
                app.updatePlots(app.Profile, scan, k);
            catch ME
                % Show the full error so it isn't silently swallowed
                % by the uifigure callback mechanism.
                lines = {'updatePlots error:', ME.message, ''};
                for i = 1:min(5, numel(ME.stack))
                    lines{end+1} = sprintf('  %s  line %d', ...
                        ME.stack(i).name, ME.stack(i).line); %#ok<AGROW>
                end
                app.ScanInfoBox.Value = lines;
                return
            end

            % Update navigation display
            app.DepthField.Value = round(app.Profile.pr(k), 1);
            app.DepthLbl.Text = sprintf('Scan %d / %d  (index %d)', ...
                app.CurrentKIdx, numel(app.ValidK), k);

            % Summary panel
            try
                dTdV1 = app.Profile.Meta_Data.AFE.t1.cal;
                dTdV2 = app.Profile.Meta_Data.AFE.t2.cal;
                info = { ...
                    sprintf('Depth:  %.1f m',       scan.pr), ...
                    sprintf('w:      %.3f m/s',      scan.w), ...
                    '', ...
                    sprintf('chi1:   %.2e K²/s',    scan.chi.t1), ...
                    sprintf('chi2:   %.2e K²/s',    scan.chi.t2), ...
                    '', ...
                    sprintf('eps1:   %.2e W/kg',    scan.epsilon_co.s1), ...
                    sprintf('eps2:   %.2e W/kg',    scan.epsilon_co.s2), ...
                    '', ...
                    sprintf('T:      %.2f °C',      scan.t), ...
                    sprintf('S:      %.2f psu',     scan.s), ...
                    '', ...
                    sprintf('dTdV1:  %.4f °C/V',   dTdV1), ...
                    sprintf('dTdV2:  %.4f °C/V',   dTdV2)};
            catch
                info = {sprintf('Depth: %.1f m', app.Profile.pr(k))};
            end
            app.ScanInfoBox.Value = info;
        end

        %% ----------------------------------------------------------------
        function onPrev(app)
            if isempty(app.ValidK), return; end
            newIdx = max(1, app.CurrentKIdx - 1);
            if newIdx == app.CurrentKIdx, return; end
            app.CurrentKIdx = newIdx;
            app.goToScan(app.ValidK(app.CurrentKIdx));
        end

        function onNext(app)
            if isempty(app.ValidK), return; end
            newIdx = min(numel(app.ValidK), app.CurrentKIdx + 1);
            if newIdx == app.CurrentKIdx, return; end
            app.CurrentKIdx = newIdx;
            app.goToScan(app.ValidK(app.CurrentKIdx));
        end

        function onDepthEntered(app)
            if isempty(app.ValidK), return; end
            targetDepth = app.DepthField.Value;
            validDepths = app.Profile.pr(app.ValidK);
            [~, idx] = min(abs(validDepths - targetDepth));
            if idx == app.CurrentKIdx, return; end
            app.CurrentKIdx = idx;
            app.goToScan(app.ValidK(app.CurrentKIdx));
        end

        %% ----------------------------------------------------------------
        function updatePlots(app, Profile, scan, ~)
            cols = app.Colors;
            Meta_Data = Profile.Meta_Data;

            %% Noise floor ------------------------------------------------
            dTdV = [Meta_Data.AFE.t1.cal, Meta_Data.AFE.t2.cal];

            % FPO7 noise polynomial coefficients (hardcoded fallbacks)
            FPO7noise_Tdiff    = struct('n0',-11.7035,'n1', 0.2758,'n2', 1.4272,'n3',-0.8244);
            FPO7noise_notdiff  = struct('n0',-12.2172,'n1',-0.9104,'n2', 1.3882,'n3',-0.5674);

            try
                tempChoice = Meta_Data.MAP.temperature;
            catch
                try
                    tempChoice = Meta_Data.AFE.temp_circuit;
                catch
                    tempChoice = 'Tdiff';
                end
            end
            isTdiff = strcmp(tempChoice, 'Tdiff');

            % Try loading from stored calibration path; fall back to hardcoded values
            try
                if Meta_Data.PROCESS.adjustTemp
                    FPO7noise = Meta_Data.MAP.Tnoise1;
                else
                    noiseFile = 'FPO7_noise.mat';
                    if ~isTdiff, noiseFile = 'FPO7_notdiffnoise.mat'; end
                    FPO7noise = load(fullfile(Meta_Data.paths.calibrations.fpo7, noiseFile), ...
                        'n0','n1','n2','n3');
                end
            catch
                if isTdiff
                    FPO7noise = FPO7noise_Tdiff;
                else
                    FPO7noise = FPO7noise_notdiff;
                end
            end
            hasNoise = true;

            if hasNoise
                logf   = log10(scan.f);
                tnoise = 10.^(FPO7noise.n0 + FPO7noise.n1.*logf + ...
                    FPO7noise.n2.*logf.^2 + FPO7noise.n3.*logf.^3);
                k_noise = scan.f ./ scan.w;

                % FPO7 filter correction via stored h_freq
                try
                    hFPO7 = scan.h_freq.FPO7(scan.w);
                catch
                    hFPO7 = 1;
                end

                tnoise_k_t1 = (2*pi*k_noise).^2 .* (tnoise .* dTdV(1)^2 ./ hFPO7) .* scan.w;
                tnoise_k_t2 = (2*pi*k_noise).^2 .* (tnoise .* dTdV(2)^2 ./ hFPO7) .* scan.w;

                [~, adj_t1] = SpectraExplorerApp.FPO7_cutoff(scan.f, scan.Pt_volt_f.t1, FPO7noise);
                [~, adj_t2] = SpectraExplorerApp.FPO7_cutoff(scan.f, scan.Pt_volt_f.t2, FPO7noise);
            end

            %% Smooth Tg spectra ------------------------------------------
            smTG1 = smoothdata(scan.Pt_Tg_k.t1, 'movmean', 15);
            smTG2 = smoothdata(scan.Pt_Tg_k.t2, 'movmean', 15);

            %% Batchelor spectra ------------------------------------------
            try
                [kb_s1t1, Pb_s1t1] = batchelor(scan.epsilon_co.s1, scan.chi.t1, scan.kvis, scan.ktemp);
                [kb_s2t1, Pb_s2t1] = batchelor(scan.epsilon_co.s2, scan.chi.t1, scan.kvis, scan.ktemp);
                [kb_s1t2, Pb_s1t2] = batchelor(scan.epsilon_co.s1, scan.chi.t2, scan.kvis, scan.ktemp);
                [kb_s2t2, Pb_s2t2] = batchelor(scan.epsilon_co.s2, scan.chi.t2, scan.kvis, scan.ktemp);
                hasBatch = true;
            catch
                hasBatch = false;
            end

            freqHz = scan.k .* scan.w;   % wavenumber → Hz

            %% ---- Ax(7) & Ax(8): full-profile t1/t2 volt vs depth ----------
            voltCols   = {cols.t1, cols.t2};
            voltNames  = {'t1', 't2'};
            voltFields = {'t1_volt', 't2_volt'};

            % Pressure range covered by this scan
            prInScan = Profile.epsi.P(scan.ind_scan);
            scanPrMin = nanmin(prInScan);
            scanPrMax = nanmax(prInScan);

            for iT = 1:2
                ax    = app.Ax(6 + iT);   % Ax(7) or Ax(8)
                dlIdx = 2 + iT;            % DepthLineHandles index 3 or 4
                if isvalid(app.DepthLineHandles(dlIdx))
                    delete(app.DepthLineHandles(dlIdx));
                end
                if isvalid(app.ScanPatchHandles(iT))
                    delete(app.ScanPatchHandles(iT));
                end
                cla(ax);
                hold(ax, 'on');

                % Full profile timeseries
                vFull = Profile.epsi.(voltFields{iT});
                pFull = Profile.epsi.P;

                % Determine x range for the patch before plotting
                vFinite = vFull(isfinite(vFull));
                if isempty(vFinite), vFinite = [0 1]; end
                xPad = (max(vFinite) - min(vFinite)) * 0.05;
                patchX = [min(vFinite)-xPad, max(vFinite)+xPad];

                % Shaded scan region (drawn first so it sits behind the data)
                app.ScanPatchHandles(iT) = patch(ax, ...
                    'XData', [patchX(1) patchX(2) patchX(2) patchX(1)], ...
                    'YData', [scanPrMin scanPrMin scanPrMax scanPrMax], ...
                    'FaceColor', [0.85 0.85 0.85], 'FaceAlpha', 0.5, ...
                    'EdgeColor', 'none', 'HandleVisibility', 'off');

                plot(ax, vFull, pFull, 'Color', voltCols{iT}, ...
                    'DisplayName', voltNames{iT});

                % Dashed line at scan centre depth
                app.DepthLineHandles(dlIdx) = yline(ax, scan.pr, ...
                    'LineWidth', 2, 'LineStyle', '--', 'HandleVisibility', 'off');
                hold(ax, 'off');
                ax.YDir = 'reverse';
                ylabel(ax, 'Depth (m)');
                xlabel(ax, 'V');
                legend(ax, voltNames{iT}, 'Location', 'northwest', 'FontSize', 11);
                grid(ax, 'on');
            end

            %% ---- Ax(1) & Ax(4): chi depth profiles ---------------------
            chiCols  = {cols.t1, cols.t2};
            chiNames = {'chi1', 'chi2'};
            for iT = 1:2
                ax    = app.Ax(1 + 3*(iT-1));   % Ax(1) or Ax(4)
                dlIdx = iT;                       % DepthLineHandles index 1 or 2
                if isvalid(app.DepthLineHandles(dlIdx))
                    delete(app.DepthLineHandles(dlIdx));
                end
                cla(ax);
                hold(ax, 'on');
                plot(ax, Profile.chi(:,iT), Profile.pr, ...
                    'Color', chiCols{iT}, 'DisplayName', chiNames{iT});
                app.DepthLineHandles(dlIdx) = yline(ax, scan.pr, ...
                    'LineWidth', 2, 'LineStyle', '--', 'HandleVisibility', 'off');
                hold(ax, 'off');
                ax.XScale = 'log';
                ax.YDir   = 'reverse';
                ax.XLim   = 10.^[-11, -2];
                ax.XTick  = logspace(-11, -2, 10);
                ylabel(ax, 'Depth (m)');
                xlabel(ax, 'K^2 s^{-1}');
                legend(ax, chiNames{iT}, 'Location', 'northwest', 'FontSize', 11);
                grid(ax, 'on');
            end

            %% ---- Ax(2) & Ax(5): scan-window voltage timeseries ---------
            dnumScan = Profile.epsi.dnum(scan.ind_scan);
            for iT = 1:2
                ax = app.Ax(2 + 3*(iT-1));  % Ax(2) or Ax(5)
                cla(ax);
                hold(ax, 'on');
                plot(ax, scan.(voltFields{iT}), dnumScan, ...
                    'Color', voltCols{iT}, 'DisplayName', voltNames{iT});
                hold(ax, 'off');
                ax.YDir = 'reverse';
                try
                    datetick(ax, 'y', 'MM:SS');
                catch
                    % datetick may not work on all uiaxes versions
                end
                xlabel(ax, 'V');
                legend(ax, voltNames{iT}, 'Location', 'northwest', 'FontSize', 11);
                grid(ax, 'on');
            end

            %% ---- Ax(3) & Ax(6): Tg spectra -----------------------------
            specData = { ...
                scan.Pt_Tg_k.t1, smTG1, cols.t1, scan.kc.t1; ...
                scan.Pt_Tg_k.t2, smTG2, cols.t2, scan.kc.t2};

            batchData = {};
            if hasBatch
                batchData = { ...
                    kb_s1t1, Pb_s1t1, cols.batch_s1t1, 'Batch s1t1'; ...
                    kb_s2t1, Pb_s2t1, cols.batch_s2t1, 'Batch s2t1'; ...
                    kb_s1t2, Pb_s1t2, cols.batch_s1t2, 'Batch s1t2'; ...
                    kb_s2t2, Pb_s2t2, cols.batch_s2t2, 'Batch s2t2'};
            end

            for iT = 1:2
                ax = app.Ax(3 + 3*(iT-1));  % Ax(3) for t1, Ax(6) for t2
                rawSpec = specData{iT,1};
                smSpec  = specData{iT,2};
                col     = specData{iT,3};
                kc_val  = specData{iT,4};

                cla(ax);
                hold(ax, 'on');

                % Raw spectrum (dotted)
                loglog(ax, freqHz, rawSpec, ':', 'Color', col, 'LineWidth', 2, ...
                    'DisplayName', sprintf('t%d', iT));
                % Smoothed spectrum
                loglog(ax, freqHz, smSpec, '-', 'Color', col, 'LineWidth', 3, ...
                    'DisplayName', sprintf('t%d smooth', iT));

                % Batchelor curves (rows 1-2 for t1, rows 3-4 for t2)
                if hasBatch
                    bRows = (iT-1)*2 + (1:2);
                    for ib = bRows
                        loglog(ax, batchData{ib,1}.*scan.w, batchData{ib,2}, ...
                            'Color', batchData{ib,3}, 'DisplayName', batchData{ib,4});
                    end
                end

                % Noise floor
                if hasNoise
                    if iT == 1
                        nk = tnoise_k_t1;  adj = adj_t1;
                    else
                        nk = tnoise_k_t2;  adj = adj_t2;
                    end
                    loglog(ax, k_noise.*scan.w, nk, 'k:', 'LineWidth', 2, ...
                        'DisplayName', 'noise');
                    loglog(ax, k_noise.*scan.w, 3.*adj.*nk, ':', ...
                        'Color', [0.7 0.7 0.7], 'LineWidth', 2, ...
                        'DisplayName', '3× adj. noise');
                end

                % Wavenumber cutoff marker (yellow pentagon)
                indkc = find(scan.k > kc_val, 1, 'first');
                if ~isempty(indkc) && indkc <= numel(smSpec)
                    scatter(ax, scan.k(indkc).*scan.w, smSpec(indkc), 450, 'p', ...
                        'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'y', ...
                        'LineWidth', 2, 'DisplayName', sprintf('t%d cutoff', iT));
                end

                hold(ax, 'off');
                ax.XScale = 'log';
                ax.YScale = 'log';
                xlim(ax, [0.3, 200]);

                % Y limits: top anchored to smoothed spectrum (excluding 60 Hz
                % electrical noise), bottom anchored to noise floor so both
                % the signal and noise line are always in view.
                useMask = freqHz >= 0.3 & freqHz <= 200 & ~(freqHz > 50 & freqHz < 70);
                smValid = smSpec(useMask & isfinite(smSpec) & smSpec > 0);
                yTop = max(smValid, [], 'omitnan');

                % Also include the peaks of both Batchelor curves
                if hasBatch
                    for ib = bRows
                        bFreq = batchData{ib,1} .* scan.w;
                        bVal  = batchData{ib,2};
                        inRange = bFreq >= 0.3 & bFreq <= 200 & isfinite(bVal) & bVal > 0;
                        if any(inRange)
                            yTop = max(yTop, max(bVal(inRange)));
                        end
                    end
                end

                if hasNoise
                    % Anchor bottom to noise value at 3 Hz so sub-3 Hz
                    % roll-off doesn't push the view down.
                    [~, idx3] = min(abs(k_noise .* scan.w - 3));
                    yBot = nk(idx3);
                    if ~isfinite(yBot) || yBot <= 0
                        yBot = min(nk(useMask & isfinite(nk) & nk > 0), [], 'omitnan');
                    end
                else
                    yBot = min(smValid, [], 'omitnan');
                end

                if ~isempty(yTop) && ~isempty(yBot) && yTop > 0 && yBot > 0
                    ylim(ax, [yBot/5, yTop*5]);
                end

                xlabel(ax, 'Hz');
                ylabel(ax, 'K^2 s^{-1} cpm^{-1}');
                legend(ax, 'Location', 'northwest', 'FontSize', 11);
                grid(ax, 'on');
            end

            app.Fig.Name = sprintf('Spectra Explorer — %s   depth %.1f m', ...
                app.CurrentFile, scan.pr);
        end
    end

    %% --------------------------------------------------------------------
    methods (Static, Access = private)
        function [fc_index, adjust_spec] = FPO7_cutoff(f, spec, FPO7noise)
            % Replicated from epsiPlot_chi_and_Tg_spectrum local function.
            f    = f(:);
            spec = spec(:);
            spec = spec(f > 0);
            f    = f(f > 0);

            logf  = log10(f);
            noise = FPO7noise.n0 + FPO7noise.n1.*logf + ...
                FPO7noise.n2.*logf.^2 + FPO7noise.n3.*logf.^3;

            medspec     = smoothdata(spec, 'movmean', 15);
            indhighfreq = f>0.7.*f(end);
            adjust_spec = mean(medspec(indhighfreq) ./ 10.^(noise(indhighfreq)), 'omitnan');

            SN_min = 3;
            noisy  = find(medspec(3:end) ./ adjust_spec < SN_min .* 10.^(noise(3:end)));
            if isempty(noisy)
                fc_index = length(f);
            else
                fc_index = noisy(1);
            end
            if fc_index > 1
                fc_index = fc_index - 1;
            end
        end
    end
end
