function [sts, snd_markers, delays] = scr_find_sounds(file, options)
%SCR_FIND_SOUNDS finds and evtl. analyzes sound events in a pspm file.
% A sound is accepted as event if it is longer than 10ms and events are
% recognized as different if they are at least 50 ms appart.
% sts = scr_find_sounds(file,options)
%   Arguments
%       file : path and filename of the pspm file holding the sound
%       options : struct with following possible values
%           addChannel : [true/FALSE] adds a marker channel to the original
%               file with the onset time of the detected sound events and
%               the duration of the sound event (in markerinfo)
%           diagnostics : [TRUE/false] computes the delay between trigger
%               and displays the mean delay and standard deviation.
%           maxdelay : [integer] Size of the window in seconds in wich 
%               scr_find_sounds will accept sounds to belong to a marker.
%               default is 3s.
%           plot : [true/FALSE] displays a histogramm of the 
%               delays found and a plot with the detected sound, the
%               trigger and the onset of the sound events. These are color
%               coded for delay, from green (smallest delay) to red
%               (longest). Forces the 'diagnostics' option to true.
%           resample : [integer] spline interpolates the sound by the 
%               factor specified. (1 for no interpolation, by default). 
%               Caution must be used when using this option. It should only
%               be used when following conditions are met :
%                   1. all frequencies are well below the Nyquist frequency
%                   2. the signal is sinusoidal or composed of multiple sin
%                   waves all respecting condition 1
%               Resampling will restore more or less the original signal
%               and lead to more accurate timings.
%           sndchannel : [integer] number of the channel holding the sound.
%               By default first 'custom' channel.
%           threshold : [0...1] percent of the max of the power in the
%               signal that will be accepted as a sound event. Default is
%               0.1.
%           trigchannel : [integer] number of the channel holding the 
%               triggers. By default first 'marker' channel.
%   Outputs
%       sts : 1 on successfull completion, -1 otherwise
%       snd_markers : vector of begining of sound sound events
%       delays : vector of delays between markers and detected sounds. Only
%           available with option 'diagnostics' turned on.
%__________________________________________________________________________
% PsPM 3.0
% (C) 2015 Samuel Gerster (University of Zurich)

% $Id$
% $Rev$

% Check argument
if ~exist(file,'file')
    warning('ID:file_not_found', 'File %s was not found. Aborted.',file); sts=-1; return;
end

fprintf('Processing sound in file %s\n',file);

% Process options
try options.addChannel; catch, options.addChannel = false; end;
try options.diagnostics; catch, options.diagnostics = true; end;
try options.maxdelay; catch, options.maxdelay = 3; end;
try options.plot; catch, options.plot = false; end;
try options.resample; catch, options.resample = 1; end;
try options.sndchannel; catch, options.sndchannel = 0; end;
try options.threshold; catch, options.threshold = 0.1; end;
try options.trigchannel; catch, options.trigchannel = 0; end;

if options.plot
    options.diagnostics = true;
end

if ~isnumeric(options.resample) || mod(options.resample,1) || options.resample<1
    options.resample = 1;
    warning('Option interpolate is not an integer or negative. Option set to default (%d)',options.resample)
end

if ~isnumeric(options.maxdelay) || options.maxdelay < 0
    options.maxdelay = 3;
    warning('Option maxdelay is not a number or negative. Option set to default (%4.2f s)',options.maxdelay)
end

if mod(options.sndchannel,1)
    options.sndchannel = 0;
    warning('Option channel is not an integer. Option set to default.')
end


% Load Data
data = load(file);

%% Sound
% Check for existence of sound channel
if ~options.sndchannel
    % TODO: since no channel type 'snd' exist for now, 'custom' is used as a
    % placeholder
    sndi = find(strcmpi(cellfun(@(x) x.header.chantype,[data.data],'un',0),'custom'),1);
    if ~any(sndi)
        warning('ID:no_sound_chan', 'No sound channel found. Aborted'); sts=-1; return;
    end
    snd = data.data{sndi};
else
    snd = data.data{options.sndchannel};
end

% Process Sound
snd.data = snd.data-mean(snd.data);
snd.data = snd.data/(max(snd.data));
tsnd = (0:length(snd.data)-1)'/snd.header.sr;

if options.resample>1
    % Interpolate data to restore sin like wave for more precision
    t = (0:1/options.resample:length(snd.data)-1)'/snd.header.sr;
    snd_pow = interp1(tsnd,snd.data,t,'spline').^2;
else
    t = tsnd;
    snd_pow = snd.data.^2;
end
% Apply simple bidirectional square filter
mask = ones(round(.01*snd.header.sr),1)/round(.01*snd.header.sr);
snd_pow = conv(snd_pow,mask);
snd_pow = sqrt(snd_pow(1:end-length(mask)+1).*snd_pow(length(mask):end));

%% Find sound events
thresh = max(snd_pow)*options.threshold;
snd_pres(snd_pow>thresh) = 1;
snd_pres(snd_pow<=thresh) = 0;
% Convert detected sounds into events. If pulses are separated by less than
% 50ms, combine into one event.
mask = ones(round(0.05*snd.header.sr*options.resample),1);
n_pad = length(mask)-1;
c = conv(snd_pres,mask)>0;
snd_pres = (c(1:end-n_pad) & c(n_pad+1:end));
% Find rising and falling edges
snd_re = t(conv([1,-1],snd_pres(1:end-1)+0)>0);
% Find falling edges
snd_fe = t(conv([1,-1],snd_pres(1:end-1)+0)<0);
% Start with a rising and end with a falling edge
if snd_re(1)>snd_fe(1)
    snd_re = snd_re(2:end);
end
if snd_fe(end) < snd_re(end)
    snd_fe = snd_fe(1:end-1)
end
% Discard sounds shorter than 10ms
noevent_i = find((snd_fe-snd_re)<0.01);
snd_re(noevent_i)=[];
snd_fe(noevent_i)=[];

%% Triggers
if options.diagnostics
    % Check for existence of marker channel
    if ~options.trigchannel
        mkri = find(strcmpi(cellfun(@(x) x.header.chantype,[data.data],'un',0),'marker'),1);
        if ~any(mkri)
            warning('ID:no_marker_chan', 'No marker channel found. Aborted'); sts=-1; return;
        end
    else
        mkri=options.trigchannel;
    end
    mkr = data.data{mkri};

    %% Estimate delays from trigger to sound
    delays = nan(length(mkr.data),1);
    snd_markers = nan(length(mkr.data),1);
    for i=1:length(mkr.data)
        tr = snd_re(find(snd_re>mkr.data(i),1));
        delay = tr-mkr.data(i);
        if delay<options.maxdelay
            delays(i) = delay;
            snd_markers(i)=tr;
        end
    end
    delays(isnan(delays)) = [];
    snd_markers(isnan(snd_markers)) = [];
    % Discard any sound event not related to a trigger
    snd_fe = snd_fe(dsearchn(snd_re,snd_markers));
    snd_re = snd_re(dsearchn(snd_re,snd_markers));
    %% Display some diagnostics
    fprintf('%4d sound events associated with a marker found\nMean Delay : %5.1f ms\nStd dev    : %5.1f ms\n',...
        length(snd_markers),mean(delays)*1000,std(delays)*1000);
end

%% Save as new channel
if options.addChannel
    % Save the new channel
    snd_events.data = snd_re;
    snd_events.markerinfo.value = snd_fe-snd_re;
    snd_events.header.sr = 1;
    snd_events.header.chantype = 'custom';
    snd_events.header.units ='events';
    scr_add_channel(file, snd_events);
end

%% Plot Option
if options.plot
    figure
    histogram(delays*1000,10)
    title('Trigger to sound delays')
    xlabel('t [ms]')
    if options.resample
        % downsample for plot
        t = t(1:options.resample:end);
        snd_pres = snd_pres(1:options.resample:end);
    end
    figure
    plot(t,snd_pres)
    hold on
    scatter(mkr.data,ones(size(mkr.data))*.1,'k')
    for i = 1:length(delays)
        scatter(snd_re(i),.2,500,[(delays(i)-min(delays))/range(delays),1-(delays(i)-min(delays))/range(delays),0],'.')
    end
    xlabel('t [s]')
    legend('Detected sound','Trigger','Sound onset')
    hold off
end

sts=1;

end