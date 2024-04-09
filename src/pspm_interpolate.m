function [sts, outdata] = pspm_interpolate(indata, varargin)
% ● Description
%   pspm_interpolate interpolates NaN values passed with the indata parameter.
%   Indata can be a numeric array, a filename or a PsPM data struct as 
%   accepted by pspm_load_data. If indata is a filename or PsPM data
%   structure, then the function either acts on one selected channel and 
%   writes the result to the same file, or on all channels in the file and 
%   writes a new file if the input is a file name. 
% ● Format
%   [sts, outdata] = pspm_interpolate(numeric_array, options)
%   [sts, outdata] = pspm_interpolate(filename, channel, options)
% ● Arguments
%          indata:  [struct/char/numeric] or [cell array of struct/char/numeric]
%                   contains the data to be interpolated
%          channel: a single channel identifier accepted by pspm_load_channel
%                   (numeric or char), or 'all', which will work on all 
%                   channels. If indata is a file name and channel is 'all' 
%                   then the result is written to a new file called 'i'+<old filename>.
%   ┌─────options:
%   ├─────.method:  Defines the interpolation method, see interp1() for
%   │               possible interpolation methods.
%   │               [optional; default: linear]
%   ├─.extrapolate: Determine should extrapolate for data out of the data
%   │               range.
%   │               [optional; not recommended; accept: 1, 0; default: 0]
%   ├──.overwrite:  Defines if existing datafiles should be overwritten.
%   │               [logical] (0 or 1)
%   │               Define whether to overwrite existing output files or not.
%   │               Default value: do not overwrite. Only used if 'channel'
%   │               is 'all'
%   └.channel_action:
%                   Defines whether the interpolated data should be added
%                   or the corresponding channel should be replaced.
%                   [optional; accept: 'add', 'replace'; default: 'add']
%                   Only used if 'channel' is not 'all'.
% ● Output
%             sts:  Returns the status of the function
%                   -1: function did not work properly
%                    1: the function went through properly
%         outdata:  Has the same format as indata but contains the interpolated
%                   data (or the filename(s) where the interpolated data can be
%                   found).
% ● History
%   Introduced in PsPM 3.0
%   Written in 2015 by Tobias Moser (University of Zurich)
%   Maintained in 2022 by Teddy Chao (UCL)
%   Refactored in 2024 by Dominik Bach (Uni Bonn)

%% 1 Initialise
global settings
if isempty(settings)
  pspm_init;
end
outdata = {}; % will return a cell of the same size as the indata
sts = -1;

% 1.1 check input arguments
if nargin<1
  warning('ID:missing_data', 'Don''t know what to do.\n');
  return;
elseif isempty(indata)
  warning('ID:missing_data', 'Input data is empty, nothing to do.');
  return;
end

if isnumeric(indata) && nargin >= 2
    options = varargin{2};
elseif nargin < 2
    warning('ID:invalid_input', 'Channel undefined - don''t know what to do.');
    return;
elseif nargin >= 3
    options = varargin{3};
else
    options = struct();
end

% 1.2 initialise options
options = pspm_options(options, 'interpolate');
if options.invalid
  return
end

% 1.3 determine the method
if isnumeric(indata)
    method = 1;
elseif isstruct(indata) && strcmpi(indata, 'all')
    method = 2;
elseif isstruct(indata)
    method = 3;
elseif ischar(indata) && strcmpi(indata, 'all')
    method = 4;
elseif ischar(indata)
    method = 5;
else
    warning('ID:invalid_input', 'Wrong input format.');
    return
end

% 1.4 User output
if ischar(indata)
    fprintf('\nInterpolating %s, ', indata); % user output
else
    fprintf('\nInterpolating ... '); % user output
end

%% 2 work on data
% 2.1 load data
if isnumeric(indata)
    data{1}.data = indata;
    method = 1;
elseif ischar(indata) && strcmpi(indata, 'all')
    [lsts, infos, alldata] = pspm_load_data(indata);
    if lsts < 1, return; end
    [lsts, data, pos_of_channel] = pspm_select_channels(data, 'wave');
    if lsts < 1, return; end
    method = 2;
else
    [lsts, data, infos, pos_of_channel] = pspm_load_channel(fn, channel);
    if lsts < 1, return; end
    data = {data};
    if ischar(indata)
        method = 3;
    else
        method = 4;
    end
end

% 2.2 work on all channels
for i_channel = 1:numel(data)
    v = data{i_channel}.data;
    if numel(find(~isnan(v))) < 2
      warning('ID:invalid_input',...
        'Need at least two sample points to run interpolation (Channel %i). Skipping.', k);
    else
      x = 1:length(dat);
      v = dat;
      xq = find(isnan(v));
      % throw away data matching 'filt'
      x(xq) = [];
      v(xq) = [];
      % check for overlaps
      if numel(xq) < 1
        e_overlap = 0;
        s_overlap = 0;
      else
        e_overlap = max(xq) > max(x);
        s_overlap = min(xq) < min(x);
      end
      if s_overlap || e_overlap
        if ~options.extrapolate
          warning('ID:option_disabled', ...
            'Extrapolating was forced because interpolate without extrapolating cannot be done');
          vq = interp1(x, v, xq, options.method, 'extrap');
        elseif s_overlap && strcmpi(options.method, 'previous')
          warning('ID:out_of_range', ['Cannot extrapolate with ', ...
            'method ''previous'' and overlap at the beginning.']);
          return;
        elseif e_overlap && strcmpi(options.method, 'next')
          warning('ID:out_of_range', ['Cannot extrapolate with ', ...
            'method ''next'' and overlap at the end.']);
          return;
        else
          % extrapolate because of overlaps
          vq = interp1(x, v, xq, options.method, 'extrap');
        end
      else
          % no overlap
          vq = interp1(x, v, xq, options.method);
      end
      % update data depending on method
      if ismember(method, [2, 4])
          alldata{pos_of_channel(i_channel)}.data(xq) = vq;
      elseif method == 1
          data{i_channel}.data(xq) = vq;
      end
    end
end

% 2.3 update history
if method > 1
    if isfield(infos, 'history')
      nhist = numel(infos.history);
    else
      nhist = 0;
    end
    if method == 2
        channelstr = 'All channels';
    else
        channelstr = sprintf('Channel %i', pos_of_channel);
    end
    infos.history{nhist + 1} = ...
        [channelstr, ' on ', datestr(now, 'dd-mmm-yyyy HH:MM:SS')];
end

% 2.4 write and/or return data
if method == 1 % numeric indata
    outdata =  data{1}.data;
elseif method == 2 % write new file
    % save as a new file preprended with 'i'
    [pth, fn, ext] = fileparts(fn);
    newdatafile    = fullfile(pth, ['i', fn, ext]);
    infos.interpolatefile = newdatafile;
    % pass options
    o.overwrite = pspm_overwrite(newdatafile, options);
    savedata.options = o;
    sts = pspm_load_data(newdatafile, struct('data', {alldata}, ...
        'infos', infos, ...
        'options', struct('overwrite', o.overwrite)));
    if sts == 1
        outdata = newdatafile;
    end
elseif method == 




elseif method == 3


end



  if ~inline_flag
   
    else
      if options.newfile
        % save as a new file preprended with 'i'
        [pth, fn, ext] = fileparts(fn);
        newdatafile    = fullfile(pth, ['i', fn, ext]);
        savedata.infos.interpolatefile = newdatafile;
        % pass options
        o.overwrite = pspm_overwrite(newdatafile, options);
        savedata.options = o;
        sts = pspm_load_data(newdatafile, savedata);
        if sts == 1
          outdata{d} = newdatafile;
        end
      else
        o = struct();
        % add to existing file
        if strcmp(options.channel_action, 'replace')
          o.channel = work_channels;
        end
        o.msg.prefix = 'Interpolated channel';
        [sts, infos] = pspm_write_channel(fn, savedata.data(work_channels), options.channel_action, o);
        % added channel ids are in infos.channel
        outdata{d} = infos.channel;
      end
    end
  else
    outdata{d} = channel{1};
  end
  if ischar(fn)
    fprintf('done.')
  end
end
% format output same as input
if (numel(outdata) == 1) && ~iscell(indata)
  outdata = outdata{1};
end
sts = 1;
return
