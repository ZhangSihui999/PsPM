function pspm_init

  % DESCRIPTION
  % pspm_init initializes PsPM by determining the path and loading settings
  % into the main workspace
  %
  % INDEX
  % 1 license & user output
  % 2 check
  %   2.1 check pspm version
  %   2.2 check pspm path
  %   2.3 check matlab version
  %   2.4 check signal processing toolbox
  %   2.5 check SPM
  %   2.6 check matlabbatch
  %   2.7 check pspm_cfg
  %   2.8 check VBA
  % 3 channel type (chantype) definitions
  %   3.1 SCR
  %
  % STRUCTURE
  % defaults
  %   ┣ chantypes
  %   ┣ import
  %   ┃   ┣ chantypes
  %   ┗ lateral
  %
  % VERSION
  % PsPM 3.1
  % (C) 2009-2015 Dominik R Bach (WTCN, UZH)
  % Updated 2022 Teddy Chao (UCL)

  clc

  %% 0 load text for help and warnings
  pspm_text;
  load('pspm_text.mat')

  %% 1 license & user output
  fid = fopen('pspm_msg.txt');
  msg = textscan(fid, '%s', 'Delimiter', '$');
  fclose(fid);
  clear fid
  for n = 1:numel(msg{1})
    fprintf('%s\n', msg{1}{n});
  end
  fprintf('PsPM: loading defaults ... \n');

  %% 2 check
  % 2.1 check pspm version
  [~, pspm_vers] = pspm_version('check');

  % check various settings
  global settings
  p = path;
  fs = filesep;

  % 2.2 check if subfolders are already in path
  % get subfolders
  current_path = fileparts(mfilename('fullpath'));
  folder_content = dir(current_path);
  is_folder = [folder_content(:).isdir];
  subfolders = {folder_content(is_folder).name}';
  subfolders(ismember(subfolders, {'.','..'})) = [];

  subfolders = regexprep(subfolders, '(.*)',...
  [regexptranslate('escape', [current_path, filesep]) , '$1']);

  sp = textscan(path,'%s','delimiter',pathsep);
  mem = ~ismember(subfolders, sp{1});
  if numel(subfolders(mem)) == 0
    % loaded subdirs which may cause trouble
    warning(warntext_subfolder);
  end

  % check whether scralyze is on the path
  pth = fileparts(which('pspm'));
  if ~contains(p, pth)
    scrpath=1;
    addpath(pth);
  else
    scrpath=0;
  end
  pth = [pth, fs];

  % 2.3 check matlab version
  v = version;
  if str2double(v(1:3)) < 7.1
    warning(warntext_matlab_old, v);
  end

  % 2.4 check matlab toolbox: signal processing
  tboxes = ver;
  signal = any(strcmp({tboxes.Name}, 'Signal Processing Toolbox'));
  if ~signal
    errmsg = warntext_sigproc_toolbox;
    warning(errmsg);
  end

  % 2.5 Check SPM
  % check if SPM Software is on the current Path
  % Dialog Window open to ask whether to remove program from the path or quit
  % pspm_init.
  % Default is to quit pspm_init
  all_paths = regexpi(p,';','split');
  spm_paths_idx = cell2mat(cellfun(@(x) isempty(regexpi(x,'\<spm')),all_paths,'UniformOutput',0));
  all_paths_spm = all_paths(~spm_paths_idx);
  pspm_paths_idx = cell2mat(cellfun(@(x) isempty(regexpi(x,'pspm')),all_paths_spm,'UniformOutput',0));
  all_paths_spm = all_paths_spm(pspm_paths_idx);
  if ~isempty(all_paths_spm)
    % remove the SPM from path
    if strcmp(questdlg(sprintf(warntext_spm_remove),...
      'Interference with SPM software',...
      'Yes', 'No', 'No'), 'Yes')
      cellfun(@(x) rmpath(x),all_paths_spm,'UniformOutput',0);
    else
      % quit pspm_init
      errmsg = warntext_spm_quit;
      error(errmsg);
    end
  end

  % check whether SPM 8 is already on path
  dummy = which('spm');
  if ~isempty (dummy)
    try
      if strcmpi(spm('Ver'), 'spm8b') || strcmpi(spm('Ver'), 'spm8')
        addspm = 0;
      else
        addspm = 1;
      end
    catch
      addspm = 1;
    end
  else
    addspm = 1;
  end
  if addspm
    addpath(pspm_path('ext','SPM'));
    spmpath = 1;
  else
    spmpath = 0;
  end

  % 2.6 Check matlabbatch
  % check whether matlabbatch is already on path
  dummy=which('cfg_ui');
  if isempty (dummy)
    addpath(pspm_path('ext','matlabbatch'));
    matlabbatchpath=1;
  else
    if strcmp(fs, '/')
      fs_regex = '/';
    else
      fs_regex = '\\';
    end
    m = regexpi(dummy, ['spm[0-9]+' fs_regex 'matlabbatch' fs_regex 'cfg_ui.m']);
    if ~isempty(m)
      if strcmp(questdlg(sprintf(warntext_matlabbatch), 'Matlabbatch', 'Yes', 'No', 'No'), 'Yes')
        [matlabbatch_dir,~,~] = fileparts(dummy);
        rmpath(matlabbatch_dir);
        dummy=which('spm_cfg');
        if ~isempty (dummy)
          [config_dir,~,~] = fileparts(dummy);
          rmpath(config_dir);
        end
        addpath(pspm_path('ext','matlabbatch'));
        matlabbatchpath = 1;
      else
        matlabbatchpath = 0;
      end
    else
      matlabbatchpath = 0;
    end
  end

  % 2.7 Check pspm_cfg
  % check whether pspm_cfg is already on path
  dummy=which('pspm_cfg');
  if isempty (dummy)
    addpath(pspm_path('pspm_cfg'));
    scrcfgpath=1;
  else
    scrcfgpath=0;
  end

  % 2.8 Check VBA
  % add VBA because this is used in various functions
  addpath(pspm_path('ext','VBA'));
  addpath(pspm_path('ext','VBA','subfunctions'));
  addpath(pspm_path('ext','VBA','stats&plots'));


  %% 3 Chennel types
  %
  % 3.1 allowed channel types
  %
  % DEVELOPERS NOTES
  % in order to implement new channel types
  % to defaults.import.channeltypes. If direct import is allowed, create the
  % associated pspm_get_xxx import function. See first channel type (SCR) for
  % explanations.
  % These are the allowed chantypes in a data file (checked by pspm_load_data)
  % chantypes are not ordered.

  s_t = 'type'; % data type
  s_de = 'description';
  s_i = 'import';
  s_da = 'data'; % wave is continuous, events are discrete
  %                                  Variable type            Description                                       Import function           Data type
  % 3.1 SCR
  defaults.chantypes(1) =     struct(s_t, 'scr',              s_de, 'SCR',                                      s_i, @pspm_get_scr,       s_da, 'wave');
  % 3.2 ECG
  defaults.chantypes(end+1) = struct(s_t, 'ecg',              s_de, 'ECG',                                      s_i, @pspm_get_ecg,       s_da, 'wave');
  % 3.3 Heart rate
  defaults.chantypes(end+1) = struct(s_t, 'hr',               s_de, 'Heart rate',                               s_i, @pspm_get_hr,        s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'hp',               s_de, 'Heart period',                             s_i, @pspm_get_hp,        s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'hb',               s_de, 'Heart beat',                               s_i, @pspm_get_hb,        s_da, 'events');
  defaults.chantypes(end+1) = struct(s_t, 'resp',             s_de, 'Respiration',                              s_i, @pspm_get_resp,      s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'rr',               s_de, 'Respiration rate',                         s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'rp',               s_de, 'Respiration period',                       s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'ra',               s_de, 'Respiration amplitude',                    s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'rfr',              s_de, 'Respiratory flow rate',                    s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'rs',               s_de, 'Respiration time stamp',                   s_i, @none,               s_da, 'events');
  defaults.chantypes(end+1) = struct(s_t, 'emg',              s_de, 'EMG',                                      s_i, @pspm_get_emg,       s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'emg_pp',           s_de, 'EMG preprocessed',                         s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'marker',           s_de, 'Marker',                                   s_i, @pspm_get_marker,    s_da, 'events');
  defaults.chantypes(end+1) = struct(s_t, 'snd',              s_de, 'Sound channel',                            s_i, @pspm_get_sound,     s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'ppg',              s_de, 'Photoplethysmography',                     s_i, @pspm_get_ppg,       s_da, 'wave');
  % Gaze preprocessed X
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_x',        s_de, 'Gaze preprocessed x',                      s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_x_c',      s_de, 'Gaze preprocessed x combined',             s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_x_l',      s_de, 'Gaze preprocessed x left',                 s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_x_r',      s_de, 'Gaze preprocessed x right',                s_i, @none,               s_da, 'wave');
  % Gaze preprocessed Y
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_y',        s_de, 'Gaze preprocessed y',                      s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_y_c',      s_de, 'Gaze preprocessed y combined',             s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_y_l',      s_de, 'Gaze preprocessed y left',                 s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_pp_y_r',      s_de, 'Gaze preprocessed y right',                s_i, @none,               s_da, 'wave');
  % Gaze X
  defaults.chantypes(end+1) = struct(s_t, 'gaze_x',           s_de, 'Gaze x',                                   s_i, @pspm_get_gaze_x,    s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_x_l',         s_de, 'Gaze x left',                              s_i, @pspm_get_gaze_x_l,  s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_x_r',         s_de, 'Gaze x right',                             s_i, @pspm_get_gaze_x_r,  s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_x_c',         s_de, 'Gaze x combined',                          s_i, @pspm_get_gaze_x_c,  s_da, 'wave');
  % Gaze Y
  defaults.chantypes(end+1) = struct(s_t, 'gaze_y',           s_de, 'Gaze y',                                   s_i, @pspm_get_gaze_y,    s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_y_l',         s_de, 'Gaze y left',                              s_i, @pspm_get_gaze_y_l,  s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_y_r',         s_de, 'Gaze y right',                             s_i, @pspm_get_gaze_y_r,  s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'gaze_y_c',         s_de, 'Gaze y combined',                          s_i, @pspm_get_gaze_y_c,  s_da, 'wave');
  % Pupil
  defaults.chantypes(end+1) = struct(s_t, 'pupil',            s_de, 'Pupil',                                    s_i, @pspm_get_pupil,     s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_l',          s_de, 'Pupil left',                               s_i, @pspm_get_pupil_l,   s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_r',          s_de, 'Pupil right',                              s_i, @pspm_get_pupil_r,   s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_c',          s_de, 'Pupil combined',                           s_i, @pspm_get_pupil_c,   s_da, 'wave');
  % Pupil missing
  defaults.chantypes(end+1) = struct(s_t, 'pupil_missing',    s_de, 'Pupil data missing/interpolated',          s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_missing_l',  s_de, 'Pupil data missing/interpolated left',     s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_missing_r',  s_de, 'Pupil data missing/interpolated right',    s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_missing_c',  s_de, 'Pupil data missing/interpolated combined', s_i, @none,               s_da, 'wave');
  % Pupil preprocessed
  defaults.chantypes(end+1) = struct(s_t, 'pupil_pp',         s_de, 'Pupil preprocessed',                       s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_pp_c',       s_de, 'Pupil preprocessed combined',              s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_pp_l',       s_de, 'Pupil preprocessed left',                  s_i, @none,               s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'pupil_pp_r',       s_de, 'Pupil preprocessed right',                 s_i, @none,               s_da, 'wave');
  % Blink
  defaults.chantypes(end+1) = struct(s_t, 'blink_l',          s_de, 'Blink left',                               s_i, @pspm_get_blink_l,   s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'blink_r',          s_de, 'Blink right',                              s_i, @pspm_get_blink_r,   s_da, 'wave');
  % Saccade
  defaults.chantypes(end+1) = struct(s_t, 'saccade_l',        s_de, 'Saccade left',                             s_i, @pspm_get_saccade_l, s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'saccade_r',        s_de, 'Saccade right',                            s_i, @pspm_get_saccade_r, s_da, 'wave');
  % Scanpath
  defaults.chantypes(end+1) = struct(s_t, 'sps',              s_de, 'Scanpath speed',                           s_i, @pspm_get_sps,       s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'sps_l',            s_de, 'Scanpath speed left',                      s_i, @pspm_get_sps_l,     s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'sps_r',            s_de, 'Scanpath speed right',                     s_i, @pspm_get_sps_r,     s_da, 'wave');
  defaults.chantypes(end+1) = struct(s_t, 'sps_c',            s_de, 'Scanpath speed combined',                  s_i, @pspm_get_sps_c,     s_da, 'wave');
  % Custom
  defaults.chantypes(end+1) = struct(s_t, 'custom',           s_de, 'Custom',                                   s_i, @pspm_get_custom,    s_da, 'wave');

  defaults.findvalidfixations.chantypes = {'gaze_pp_x',   'gaze_pp_y',   'gaze_x',   'gaze_y',   'pupil',   'pupil_missing',   'pupil_pp'}; % alphabetical order

  for k = 1:numel(defaults.chantypes)
    if strcmpi(func2str(defaults.chantypes(k).import), 'none')
      indx(k) = 0;
    else
      indx(k) = 1;
    end
  end

  defaults.importchantypes = defaults.chantypes(indx==1);

  %% 4 General import settings
  %
  % DEVELOPERS NOTES
  % in order to implement new datatype import, add a field
  % to defaults.import.datatypes and create the associated pspm_get_xxx
  % function. See first datatype (CED spike) for explanations.

  % TEMPLATE
  % defaults.import.datatypes(i) =
  % struct('short', 'XXX',...                            % short name for internal purposes
  % 'long', 'XXX',...                                    % long name for GUI
  % 'ext', 'XXX',...                                     % data file extension
  % 'funct', @pspm_get_XXX,...                           % import function
  % 'chantypes', {{defaults.importchantypes.type}},...   % allowed channel types
  % 'chandescription', 'XXX',...                         % description of channels for GUI
  % 'multioption', X,...                                 % allow import of multiple channels for GUI
  % 'searchoption', X,...                                % allow channel name search for GUI
  % 'automarker', X,...                                  % marker not stored in separate channel
  % 'autosr', X,...                                      % sample rate automatically assigned
  % 'help', '');                                          % helptext from structure gui

  %
  % 4.1 Cambridge Electronic Design (CED) Spike files
  defaults.import.datatypes(1) = struct(...
  'short',            'spike',...
  'long',             'CED Spike (.smr)',...
  'ext',              'smr',...
  'funct',            @pspm_get_spike,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_spike);
  %
  % 4.2 Matlab files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'mat',...
  'long',             'Matlab',...
  'ext',              'mat',...
  'funct',            @pspm_get_mat,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'cell/column',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       0,...
  'autosr',           0,...
  'help',             helptext_import_matlab);
  %
  % 4.3 Text files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'txt',...
  'long',             'Text',...
  'ext',              'txt',...
  'funct',            @pspm_get_txt,...
  'chantypes',        {{defaults.importchantypes(strcmpi('wave',{defaults.importchantypes.data}) | strcmpi('marker', {defaults.importchantypes.type})).type}},...  %all wave channels + marker
  'chandescription',  'column',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           0,...
  'help',             helptext_import_txt);
  %
  % 4.4 Delimiter Separated files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'dsv',...
  'long',             'Delimiter Separated Values',...
  'ext',              'any',...
  'funct',            @pspm_get_txt,...
  'chantypes',        {{defaults.importchantypes(strcmpi('wave',{defaults.importchantypes.data}) | strcmpi('marker', {defaults.importchantypes.type})).type}},...  %all wave channels + marker
  'chandescription',  'column',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           0,...
  'help',             helptext_import_dsv);
  %
  % 4.5 CSV - copy of dsv with partially applied delimiter
  defaults.import.datatypes(end+1) = struct(...
  'short',            'csv',...
  'long',             'Comma Separated Values',...
  'ext',              'csv',...
  'funct',            @pspm_get_csv,...
  'chantypes',        {{defaults.importchantypes(strcmpi('wave',{defaults.importchantypes.data}) | strcmpi('marker', {defaults.importchantypes.type})).type}},...  %all wave channels + marker
  'chandescription',  'column',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           0,...
  'help',             helptext_import_csv);
  %
  % 4.6 Biopac Acknowledge up to version 3.9.0
  defaults.import.datatypes(end+1) = struct(...
  'short',            'acq',...
  'long',             'Biopac Acqknowledge 3.9.0 or lower (.acq)',...
  'ext',              'acq',...
  'funct',            @pspm_get_acq,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_acq);
  %
  % 4.7 exported Biopac Acqknowledge (tested on version 4.2.0)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'acqmat',...
  'long',             'matlab-exported Biopac Acqknowledge 4.0 or higher',...
  'ext',              'mat',...
  'funct',            @pspm_get_acqmat,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_acqmat);
  %
  % 4.8 bioread converted Biopac Acqknowledge (any version)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'acq_bioread',...
  'long',             'bioread-converted Biopac Acqknowledge (any version)',...
  'ext',              'mat',...
  'funct',            @pspm_get_acq_bioread,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_bioread);
  %
  % 4.9 ADInstruments Labchart  (any Version)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'labchartmat',...
  'long',             'ADInstruments LabChart (any Version, Windows only)',...
  'ext',              'adicht',...
  'funct',            @pspm_get_labchart,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...  %all except hb
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_labchartmat);
  %
  % 4.10 exported ADInstruments Labchart up to 7.1
  defaults.import.datatypes(end+1) = struct(...
  'short',            'labchartmat_ext',...
  'long',             'matlab-exported ADInstruments LabChart 7.1 or lower',...
  'ext',              'mat',...
  'funct',            @pspm_get_labchartmat_ext,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...  %all except hb
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_labchartmat_ext);
  %
  % 4.11 exported ADInstruments Labchart 7.2 or higher
  defaults.import.datatypes(end+1) = struct(...
  'short',            'labchartmat_in',...
  'long',             'matlab-exported ADInstruments LabChart 7.2 or higher',...
  'ext',              'mat',...
  'funct',            @pspm_get_labchartmat_in,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_labchartmat_in);
  %
  % 4.12 VarioPort
  defaults.import.datatypes(end+1) = struct(...
  'short',            'vario',...
  'long',             'VarioPort (.vdp)',...
  'ext',              'vpd',...
  'funct',            @pspm_get_vario,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_vario);
  %
  % 4.13 exported Biograph Infiniti
  defaults.import.datatypes(end+1) = struct(...
  'short',            'biograph',...
  'long',             'text-exported Biograph Infiniti',...
  'ext',              'txt',...
  'funct',            @pspm_get_biograph,...
  'chantypes',        {{'scr', 'hb', 'resp'}},...
  'chandescription',  'channel',...
  'multioption',      0,...
  'searchoption',     0,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_biograph);
  %
  % 4.14 exported MindMedia Biotrace
  defaults.import.datatypes(end+1) = struct(...
  'short',            'biotrace',...
  'long',             'text-exported MindMedia Biotrace',...
  'ext',              'txt',...
  'funct',            @pspm_get_biotrace,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      0,...
  'searchoption',     0,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_biotrace);
  %
  % 4.15 Brain Vision
  defaults.import.datatypes(end+1) = struct(...
  'short',            'brainvision',...
  'long',             'BrainVision (.eeg)',...
  'ext',              'eeg',...
  'funct',            @pspm_get_brainvis,...
  'chantypes',        {{defaults.chantypes(~strcmpi('hb',{defaults.chantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_brainvision);
  %
  % 4.16 Dataq Windaq (e. g. provided by Coulbourn Instruments)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'windaq',...
  'long',             'DATAQ Windaq (.wdq) (read with ActiveX-Lib)',...
  'ext',              'wdq',...
  'funct',            @pspm_get_wdq,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_windaq);
  %
  % 4.17 Dataq Windaq (PsPM Version)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'windaq_n',...
  'long',             'DATAQ Windaq (.wdq)',...
  'ext',              'wdq',...
  'funct',            @pspm_get_wdq_n,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_windaq_n);
  %
  % 4.18 Noldus Observer XT compatible .txt files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'observer',...
  'long',             'Noldus Observer XT compatible text file',...
  'ext',              'any',...
  'funct',            @pspm_get_obs,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_observer);
  %
  % 4.19 NeuroScan
  defaults.import.datatypes(end+1) = struct(...
  'short',            'cnt',...
  'long',             'Neuroscan (.cnt)',...
  'ext',              'cnt',...
  'funct',            @pspm_get_cnt,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_cnt);
  %
  % 4.20 BioSemi
  defaults.import.datatypes(end+1) = struct(...
  'short',            'biosemi',...
  'long',             'BioSemi (.bdf)',...
  'ext',              'bdf',...
  'funct',            @pspm_get_biosemi,...
  'chantypes',        {{defaults.importchantypes(~strcmpi('hb',{defaults.importchantypes.type})).type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_biosemi);
  %
  % 4.21 Eyelink 1000 files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'eyelink',...
  'long',             'Eyelink 1000 (.asc)',...
  'ext',              'asc',...
  'funct',            @pspm_get_eyelink,...
  'chantypes',        {{'pupil_l','pupil_r', 'gaze_x_l', 'gaze_y_l',...
  'gaze_x_r', 'gaze_y_r', 'blink_l', 'blink_r',...
  'saccade_l', 'saccade_r', 'marker', 'custom'}},...
  'chandescription',  'data column',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_eyelink);
  %
  % 4.22 European Data Format (EDF)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'edf',...
  'long',             'European Data Format (.edf)',...
  'ext',              'edf',...
  'funct',            @pspm_get_edf,...
  'chantypes',        {{defaults.importchantypes.type}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     1,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_edf);
  %
  % 4.23 Philips Scanphyslog (.log)
  defaults.import.datatypes(end+1) = struct(...
  'short',            'physlog',...
  'long',             'Philips Scanphyslog (.log)',...
  'ext',              'log',...
  'funct',            @pspm_get_physlog,...
  'chantypes',        {{'ecg', 'ppg', 'resp', 'custom', 'marker'}},...
  'chandescription',  'channel',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       0,...
  'autosr',           1,...
  'help',             helptext_import_physlog);
  %
  % 4.24 ViewPoint EyeTracker files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'viewpoint',...
  'long',             'ViewPoint EyeTracker (.txt)',...
  'ext',              'txt',...
  'funct',            @pspm_get_viewpoint,...
  'chantypes',        {{'pupil_l','pupil_r', 'gaze_x_l', 'gaze_y_l', 'gaze_x_r', 'gaze_y_r', 'blink_l', 'blink_r', 'saccade_l', 'saccade_r', 'marker', 'custom'}},...
  'chandescription',  'data column',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_viewpoint);
  %
  % 4.25 SMI EyeTracker files
  defaults.import.datatypes(end+1) = struct(...
  'short',            'smi',...
  'long',             'SensoMotoric Instruments iView X EyeTracker (.txt)',...
  'ext',              'txt',...
  'funct',            @pspm_get_smi,...
  'chantypes', {{'pupil_l', 'pupil_r', 'gaze_x_l', 'gaze_y_l',...
  'gaze_x_r', 'gaze_y_r', 'blink_l', 'blink_r', 'saccade_l', 'saccade_r',...
  'marker', 'custom'}},...
  'chandescription',  'data column',...
  'multioption',      1,...
  'searchoption',     0,...
  'automarker',       1,...
  'autosr',           1,...
  'help',             helptext_import_smi);

  %% 5 Default channel name for channel type search
  defaults.import.channames.scr       = {'scr', 'scl', 'gsr', 'eda'};
  defaults.import.channames.hr        = {'rate', 'hr'};
  defaults.import.channames.hb        = {'beat', 'hb'};
  defaults.import.channames.ecg       = {'ecg', 'ekg'};
  defaults.import.channames.hp        = {'hp'};
  defaults.import.channames.resp      = {'resp', 'breath'};
  defaults.import.channames.pupil     = {'pupil', 'eye', 'track'};
  defaults.import.channames.ppg       = {'ppg'};
  defaults.import.channames.marker    = {'trig', 'mark', 'event', 'scanner'};
  defaults.import.channames.sound     = {'sound'};
  defaults.import.channames.custom    = {'custom'};

  % Various import settings
  defaults.import.fileprefix = 'pspm_';

  defaults.import.rsr = 1000;                % minimum resampling rate for pulse data import
  defaults.import.sr = 100;                  % final sampling rate for pulse data import

  defaults.import.mat.sr_threshold = 1; %maximum value of the field '.sr' to which data is recognized as timestamps

  %% 6 Processing settings
  defaults.split.max_sn = 10; % split sessions: assume maximum 10 sessions
  defaults.split.min_break_ratio = 3; % split sessions: assume inter marker intervals 3 times longer for breaks

  % Lateral setting
  defaults.lateral.char.c = 'c';
  defaults.lateral.char.l = 'l';
  defaults.lateral.char.r = 'r';

  defaults.lateral.cap.c = 'C';
  defaults.lateral.cap.l = 'L';
  defaults.lateral.cap.r = 'R';

  defaults.lateral.full.c = 'combined';
  defaults.lateral.full.l = 'left';
  defaults.lateral.full.r = 'right';

  % other settings
  % resampling rate for automatic transfer function computation
  defaults.get_transfer_sr = 100;

  % default modalities
  defaults.modalities = struct('glm', 'scr', 'sf', 'scr', 'dcm', 'scr', 'pfm', 'pupil');

  %% 7 modality-specific GLM settings
  %
  % DEVELOPERS NOTES
  % In order to implement new modalities, add a field
  % to defaults.glm. See first modality (SCR) for explanations.
  %
  % defaults.glm(1) = ...                                              % GLM for SCR
  % struct('modality', 'scr',...                                  % modality name
  % 'modelspec', 'scr',...                                        % model specification
  % 'cbf', struct('fhandle', @pspm_bf_scrf, 'args', 1),...  % default basis function/set
  % 'filter', struct('lpfreq', 5, 'lporder', 1,  ...        % default filter settings
  % 'hpfreq', 0.05, 'hporder', 1, 'down', 10,...
  % 'direction', 'uni'),...
  % 'default', 1);

  % GLM for SCR
  defaults.glm(1) = struct(...
  'modality',     'scr',...
  'modelspec',    'scr',...
  'cbf',          struct('fhandle', @pspm_bf_scrf, 'args', 1),...
  'filter',       struct('lpfreq', 5,   'lporder', 1, 'hpfreq', 0.05,   'hporder', 1,   'down', 10,   'direction',  'uni'),...
  'default',      1);
  % GLM for HP (evoked)
  defaults.glm(2) = struct(...
  'modality',     'hp',...
  'modelspec',    'hp_e',...
  'cbf',          struct('fhandle', @pspm_bf_hprf_e, 'args', 1),...
  'filter',       struct('lpfreq', 2,   'lporder', 2, 'hpfreq', 0.01,   'hporder', 2,   'down', 10,   'direction',  'uni'),...
  'default',      0);
  % GLM for HP (fear-conditioning)
  defaults.glm(3) = struct(...
  'modality',     'hp',...
  'modelspec',    'hp_fc',...
  'cbf',          struct('fhandle', @pspm_bf_hprf_fc, 'args', 1),...
  'filter',       struct('lpfreq', 0.5, 'lporder', 4, 'hpfreq', 0.015,  'hporder', 4,   'down', 10,   'direction',  'bi'),...
  'default',      0);
  % GLM for PS (fear-conditioning)
  defaults.glm(4) = struct(...
  'modality',     'pupil',...
  'modelspec',    'ps_fc',...
  'cbf',          struct('fhandle', @pspm_bf_psrf_fc, 'args', 1),...
  'filter',       struct('lpfreq', 50,  'lporder', 1, 'hpfreq', NaN,    'hporder', NaN, 'down', 100,  'direction',  'bi'),...
  'default',      0);
  % GLM for RA (evoked)
  defaults.glm(5) = struct(...
  'modality',     'ra',...
  'modelspec',    'ra_e',...
  'cbf',          struct('fhandle', @pspm_bf_rarf_e, 'args', 1),...
  'filter',       struct('lpfreq', 1,   'lporder', 1, 'hpfreq', 0.001,  'hporder', 1,   'down', 10,   'direction',  'uni'),...
  'default',      0);
  % GLM for RA (fear-conditioning)
  defaults.glm(6) = struct(...
  'modality',     'ra',...
  'modelspec',    'ra_fc',...
  'cbf',          struct('fhandle', @pspm_bf_rarf_fc, 'args', 1),...
  'filter',       struct('lpfreq', 2,   'lporder', 6, 'hpfreq', 0.01,   'hporder', 6,   'down', 10,   'direction',  'bi'),...
  'default',      0);
  % GLM for RP (evoked)
  defaults.glm(7) = struct(...
  'modality',     'rp',...
  'modelspec',    'rp_e',...
  'cbf',          struct('fhandle', @pspm_bf_rprf_e, 'args', 0),...
  'filter',       struct('lpfreq', 1,   'lporder', 1, 'hpfreq', 0.01,   'hporder', 1,   'down', 10,   'direction',  'uni'),...
  'default',      0);
  % GLM for RFR (evoked)
  defaults.glm(8) = struct(...
  'modality',     'rfr',...
  'modelspec',    'rfr_e',...
  'cbf',          struct('fhandle', @pspm_bf_rfrrf_e, 'args', 1),...
  'filter',       struct('lpfreq', 1,   'lporder', 1, 'hpfreq', 0.001,  'hporder', 1,   'down', 10,   'direction',  'uni'),...
  'default',      0);
  % GLM for SEBR (fear-conditioning)
  defaults.glm(9) = struct(...
  'modality',     'emg_pp',...
  'modelspec',    'sebr',...
  'cbf',          struct('fhandle', @pspm_bf_sebrf, 'args', 0),...
  'filter',       struct('lpfreq', NaN, 'lporder', NaN,  'hpfreq', NaN, 'hporder', NaN, 'down', 1000, 'direction',  'uni'),...
  'default',      1);
  % GLM for Scanpath-speed
  defaults.glm(10) = struct(...
  'modality',     'sps',...
  'modelspec',    'sps',...
  'cbf',          struct('fhandle', @pspm_bf_spsrf_box, 'args', 1),...
  'filter',       struct('lpfreq', NaN, 'lporder', NaN,  'hpfreq', NaN, 'hporder', NaN, 'down', 1000, 'direction',  'uni'),...
  'default',      1);

  %% 7 DCM settings
  %
  % DEVELOPERS NOTES
  % Currently this is being used for DCM for SCR and SF
  % analysis. Further modalities and models can be implemented.
  %

  % DCM for SCR filter settings
  defaults.dcm{1} = struct('filter', struct('lpfreq', 5,  'lporder',  1,  'hpfreq', 0.0159, 'hporder',  1,  'down', 10, 'direction', 'bi'), 'sigma_offset', 0.3);
  % DCM for SF filter settings
  defaults.dcm{2} = struct('filter', struct('lpfreq', 5,  'lporder',  1,  'hpfreq', 0.0159, 'hporder',  1,  'down', 10, 'direction', 'uni'));


  %% 8 PFM settings
  %
  % DEVELOPERS NOTES
  % Currently this is being used for PFM for pupil data.
  % Further modalities and models can be implemented.
  %
  defaults.pfm(1) = struct( ...
  'modality', 'dilation',...                                                       % modality name
  'cbf', struct('fhandle', @pspm_bf_ldrf_gm, 'args', [0.2, 2.40 , 0.29 , 0.77]),...  % basis function & default parameters
  'cif', struct('fhandle', @pspm_bf_ldrf_gm, 'args', [0, 2.76 , 0.09 , 0.31],...     % input function & default parameters
  'lb', [0,0,0,0], 'ub', [0,Inf,Inf,Inf]),...                          % & the lower/upper bounds
  'filter', struct('lpfreq', 'none', 'lporder', 0,  ...                               % default filter
  'hpfreq', 'none', 'hporder', 0, 'down', 0, 'direction', 'bi'));

  defaults.pfm(2) = struct(...
  'modality', 'constriction',...
  'cbf', struct('fhandle', @pspm_bf_lcrf_gm, 'args', [0.2, 3.24 , 0.18 , 0.43]),...
  'cif', struct('fhandle', @pspm_bf_lcrf_gm, 'args', [0, 2.76 , 0.09 , 0.31], 'lb', [0,0,0,0], 'ub', [0,Inf,Inf,Inf]),...
  'filter', struct('lpfreq', 'none', 'lporder', 0, 'hpfreq', 'none', 'hporder', 0, 'down', 0, 'direction', 'bi'));


  %%   9 FIRST LEVEL settings

  % allowed first level model types
  defaults.first = {'glm', 'sf', 'dcm', 'pfm'};


  % Data/module file helptext settings
  defaults.datafilehelp = ['In case data/model file(s) are chosen via the ',...
  'dependency button, make sure the number of output ',...
  'files of the preceding module corresponds with the ',...
  'allowed number of input files for this module.'];

  %% 10 UI settings
  % Parameters for UI optimisation
  if ispc
    defaults.ui = struct(...
    'DisplayHeight',    250/5,...
    'DisplayUnit',      'points',...
    'DisplayWeight',    250,...
    'FontNameEmph',     'Segoe UI Bold',...
    'FontNameText',     'Segoe UI',...
    'FontSizeAttr',     9,...
    'FontSizeCaption',  9,...
    'FontSizeText',     10,...
    'FontSizeTitle',    11,...
    'MainHeight',       500*0.8,...
    'MainWeight',       500,...
    'OperatingSystem',  'Windows',...
    'SwitchResize',     'off');
  elseif ismac
    defaults.ui = struct('OperatingSystem','Mac',...
    'DisplayHeight',    60,...
    'DisplayUnit',      'points',...
    'DisplayWeight',    190,...
    'FontNameEmph',     'Gill Sans',...
    'FontNameText',     'Helvetica Neue',...
    'FontSizeAttr',     13,...
    'FontSizeCaption',  12,...
    'FontSizeText',     14,...
    'FontSizeTitle',    16,...
    'MainHeight',       750*0.8,...
    'MainWeight',       750,...
    'SwitchResize',     'off');
  else
    defaults.ui = struct('OperatingSystem','Linux',...
    'DisplayHeight',    60,...
    'DisplayUnit',      'points',...
    'DisplayWeight',    190,...
    'FontNameEmph',     'Verdana Bold',...
    'FontNameText',     'Verdana',...
    'FontSizeAttr',     10,...
    'FontSizeCaption',  9,...
    'FontSizeText',     10,...
    'FontSizeTitle',    11,...
    'MainHeight',       650*0.8,...
    'MainWeight',       650,...
    'SwitchResize',     'on');
  end

  % Look for settings, otherwise set defaults
  if exist([pth, 'pspm_settings.mat'], 'file')
    load([pth, 'pspm_settings.mat']);
  else
    settings=defaults;
  end

  %% 11 Finalisation
  settings.path = pth;
  settings.scrpath = scrpath;
  settings.spmpath = spmpath;
  settings.matlabbatchpath = matlabbatchpath;
  settings.scrcfgpath = scrcfgpath;
  settings.signal = signal;
  settings.pspm_version = pspm_vers;
  settings.developmode = 1;

  return
end
