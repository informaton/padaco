%a wrapper for matlab's uigetfile - this one returns the fullfilename; not
%as a path and a filename, or empty if the user cancels or it does not
%exist.
%> function fullfilename = uigetfullfile(filter_cell,display_message,file,multiselect_option)
%> xmlfilename = uigetfullfile({'*.xml','Cohort structure file (*.xml)'},'Select cohort information structure file');
%> See uigetfile
function fullfilename = uigetfullfile(filter_cell,display_message,multiselect_option,file)
if(nargin<4 || isempty(file))
    file = pwd;
end
if(nargin<3 || (~strcmpi(multiselect_option,'on') || ~strcmpi(multiselect_option,'off')))
    [filename, pathname, ~] = uigetfile(filter_cell,display_message,file);
else
    [filename, pathname, ~] = uigetfile(filter_cell,display_message,file,'MultiSelect',multiselect_option);    
end

if(isnumeric(filename) && ~filename)
    fullfilename = [];
else
    fullfilename = fullfile(pathname,filename);
end
if(~exist(fullfilename,'file'))
    fullfilename = [];
end

end
