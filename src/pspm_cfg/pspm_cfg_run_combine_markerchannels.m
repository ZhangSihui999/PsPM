function pspm_cfg_run_combine_markerchannels(job)
fn = job.datafile{1};
channel_action = job.channel_action;
options = struct('channel_action', channel_action);
pspm_combine_markerchannels(fn, options);
