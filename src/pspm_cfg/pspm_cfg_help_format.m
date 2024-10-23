function helptext = pspm_cfg_help_format(funcname, argname)
% pspm_cfg_help_format collects help text elements generated by
% pspm_help_init and combines them into a text block for the matlabbatch
% GUI
% Format: helptext = pspm_cfg_help_format(funcname, [argname])
%         helptext = pspm_cfg_help_format('import', helptext)
%         helptext = pspm_cfg_help_format('pspm_pupil_pp_options', outputname)
%                funcname: PsPM function name (char)
%                argname: function argument (potentially a chain of nested
%                struct fields, e.g. 'options.overwrite')
%                outputname: output argument (potentially a chain of nested
%                struct fields)

global settings

if nargin < 2
    helptext = {
        '------------------------------------------------------------------------------------------------', ...
        sprintf(...
        ['This GUI item calls the function %s. You can also call this function ', ...
         'directly. Type ''help %s'' in the command window for more information.'], funcname, funcname), ...
        '------------------------------------------------------------------------------------------------'};

    if isfield(settings.help, funcname)
        if isfield(settings.help.(funcname), 'Description')
            A = settings.help.(funcname).Description;
            A = strrep(A, newline, [newline, newline]);
            A = splitlines(A);
            helptext = [helptext(:); ''; A];
        end
        if isfield(settings.help.(funcname), 'References')
            helptext = [ helptext(:); ''; ...
            '------------------------------------------------------------------------------------------------';...
            'References:'; ...
            settings.help.(funcname).References(:)];
        end
    end
elseif strcmpi(funcname, 'import')
    A = strrep(argname, newline, [newline, newline]);
    helptext = splitlines(A);
else
    if strcmpi(funcname, 'pspm_pupil_pp_options')
        fieldtype = 'Outputs';
    else
        fieldtype = 'Arguments';
    end
    % this syntax allows chaining several nested structs into one argname
    evalc(sprintf('helptext = settings.help.%s.%s.%s;', funcname, fieldtype, argname));
    % remove entries in square brackets
    [startindx, endindx] = regexp(helptext, '\[\s*([^\[\]]*)\s*\]'); % thanks ChatGPT for finding the regexp
    for k = numel(startindx):-1:1
        helptext(startindx(k):endindx(k)) = [];
    end
    % remove trailing space
    if strcmpi(helptext(1), ' ')
        helptext = helptext(2:end);
    end
    helptext = {helptext};
end