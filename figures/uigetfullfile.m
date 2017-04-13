%> @brief Wrapper for matlab's uigetfile.
%> @retval Full filename (string) of selected file or empty if the user cancels or the file does not exist.
%> @note This is different from uigetfile which returns a path and a filename separately.
% @note Use function fullfilename = uigetfullfile(filter_cell,display_message,file,multiselect_option)
%> @note Examples:
%> - fullfilename = uigetfullfile({'*.xml','Cohort structure file (*.xml)'},'Select cohort information structure file');
%> - fullfilename = uigetfullfile({'*.xml','Cohort structure file (*.xml)'},'Select cohort information structure file','off','cohort.xml');
%> - [fullfilename, filterIndex] = uigetfullfile({'*.xml','Cohort structure file (*.xml)'},'Select cohort information structure file','off','cohort.xml');

%> See uigetfile
function [fullfilename, filterIndex] = uigetfullfile(filter_cell,display_message,file,multiselect_option)
    if(nargin<4 || (~strcmpi(multiselect_option,'on') || ~strcmpi(multiselect_option,'off')))
        multiselect_option = 'off';
    end
    if(nargin<3 || isempty(file))
        file = pwd;
    end
    [filename, pathname, filterIndex] = uigetfile(filter_cell,display_message,file,'MultiSelect',multiselect_option);
    
    if(isnumeric(filename) && ~filename)
        fullfilename = [];
    else
        fullfilename = fullfile(pathname,filename);
    end
    if(~exist(fullfilename,'file'))
        fullfilename = [];
    end
    
end
