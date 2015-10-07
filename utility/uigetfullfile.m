%> @brief Wrapper for matlab's uigetfile.  
%> @retval Full filename (string) of selected file or empty if the user cancels or the file does not exist.
%> @note This is different from uigetfile which returns a path and a filename separately.
% @note Use function fullfilename = uigetfullfile(filter_cell,display_message,file,multiselect_option)
%> @note Example:  xmlfilename = uigetfullfile({'*.xml','Cohort structure file (*.xml)'},'Select cohort information structure file');
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
