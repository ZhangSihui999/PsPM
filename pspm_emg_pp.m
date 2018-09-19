function [sts, output] = pspm_emg_pp(fn, options)
% pspm_emg_pp reduces noise in emg data in 3 steps. Following
% from the literature[1] it does the following steps:
%   - Initial filtering:        4th order Butterworth with 50 Hz and 470 Hz 
%                               cutoff frequencies
%   - Remove mains noise:       50 Hz (variable) notch filter
%   - Smoothing and rectifying: 4th order Butterworth low-pass filter with 
%                               a time constant of 3 ms (=> cutoff of 53.05
%                               Hz)
%  
% Once the data is preprocessed, according to the option 'channel_action',
% it will either replace the existing channel or add it as new channel to
% the provided file.
%
%   FORMAT:  [sts, output] = pspm_emg_pp(fn, options)
%       fn:                 [string] Path to the PsPM file which contains 
%                           the EMG data
%       options.
%           mains_freq:     [integer] Frequency of mains noise to remove 
%                           with notch filter (default: 50Hz).
%
%           channel:        [numeric/string] Channel to be preprocessed.
%                           Can be a channel ID or a channel name.
%                           Default is 'emg'.
%
%           channel_action: ['add'/'replace'] Defines whether data should be added ('add') or
%                           last existing channel should be replaced ('replace').
%                           Default is 'replace'.
%
% [1] Khemka S, Tzovara A, Gerster S, Quednow BB, Bach DR (2016).
%     Modeling Startle Eyeblink Electromyogram to Assess Fear Learning. 
%     Psychophysiology
%__________________________________________________________________________
% PsPM 3.1
% (C) 2009-2016 Tobias Moser (University of Zurich)

% $Id$   
% $Rev$

% initialise
% -------------------------------------------------------------------------
global settings;
if isempty(settings), pspm_init; end
sts =-1;
output = struct();

% set default values
% -------------------------------------------------------------------------
if nargin < 2
    options = struct();
end

if ~isfield(options, 'mains_freq')
    options.mains_freq = 50;
end

if ~isfield(options, 'channel') 
    options.channel = 'emg';
end

if ~isfield(options, 'channel_action')
    options.channel_action = 'replace';
end

% check values
% -------------------------------------------------------------------------
if ~isnumeric(options.mains_freq)
    warning('ID:invalid_input', 'Option mains_freq must be numeric.');
    return;
elseif ~ismember(options.channel_action, {'add', 'replace'})
    warning('ID:invalid_input', 'Option channel_action must be either ''add'' or ''repalce''');
    return;
elseif ~isnumeric(options.channel) && ~ischar(options.channel)
    warning('ID:invalid_input', 'Option channel must be a string or numeric');
end

% load data
% -------------------------------------------------------------------------
[lsts, infos, data] = pspm_load_data(fn, options.channel);
if lsts ~= 1, return, end

% do the job
% -------------------------------------------------------------------------

% (1) 4th order Butterworth band-pass filter with cutoff frequency of 50 Hz and 470 Hz
filt.sr = data{1}.header.sr;
filt.lpfreq = 470;
filt.lporder = 4;
filt.hpfreq = 50;
filt.hporder = 4;
filt.down = 'none';
filt.direction = 'uni';

[lsts, data{1}.data, data{1}.header.sr] = pspm_prepdata(data{1}.data, filt);
if lsts == -1, return; end

% (2) remove mains noise with notch filter
% design from
% http://dsp.stackexchange.com/questions/1088/filtering-50hz-using-a-
% notch-filter-in-matlab
nfr = filt.sr/2;                         % Nyquist frequency
freqRatio = options.mains_freq/nfr;      % ratio of notch freq. to Nyquist freq.
nWidth = 0.1;                            % width of the notch filter

% Compute zeros
nZeros = [exp( sqrt(-1)*pi*freqRatio ), exp( -sqrt(-1)*pi*freqRatio )];
% Compute poles
nPoles = (1-nWidth) * nZeros;

b = poly( nZeros ); % Get moving average filter coefficients
a = poly( nPoles ); % Get autoregressive filter coefficients

% filter signal x
data{1}.data = filter(b,a,data{1}.data);

% (3) smoothed using 4th order Butterworth low-pass filter with
% a time constant of 3 ms corresponding to a cutoff frequency of 53.05 Hz
filt.sr = data{1}.header.sr;
filt.lpfreq = 1/(2*pi*0.003);
filt.lporder = 4;
filt.hpfreq = 'none';
filt.hporder = 0;
filt.down = 'none';
filt.direction = 'uni';

% rectify before with abs()
[lsts, data{1}.data, data{1}.header.sr] = pspm_prepdata(abs(data{1}.data), filt);
if lsts == -1, return; end

% change channel type to emg_pp to match sebr modality
data{1}.header.chantype = 'emg_pp';

% save data
% -------------------------------------------------------------------------
[lsts, outinfos] = pspm_write_channel(fn, data{1}, options.channel_action);
if lsts ~= 1, return; end

output.channel = outinfos.channel;
sts = 1;

end
