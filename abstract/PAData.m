classdef PAData < PABase
    
    properties(SetAccess=protected)
        %> @brief Folder where exported files are saved to .
        exportPathname;
    end
    methods(Abstract)
       didExport = exportToDisk(this); 
    end
    methods
        % --------------------------------------------------------------------
        % Helper functions for setting the export paths to be used when
        % saving data about clusters and covariates to disk.
        % --------------------------------------------------------------------
        function didUpdate = updateExportPath(this)
            displayMessage = 'Select a directory to place the exported files.';
            initPath = this.getExportPath();
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            if(isempty(tmpOutputDirectory))
                didUpdate = false;
            else
                didUpdate = this.setExportPath(tmpOutputDirectory);
            end
        end
        
        % --------------------------------------------------------------------
        function exportPath = getExportPath(this)
            exportPath = this.exportPathname;
        end
        
        % --------------------------------------------------------------------
        function didSet = setExportPath(this, newPath)
            try
                this.exportPathname = newPath;
                didSet = true;
            catch me
                showME(me);
                didSet = false;
            end
        end
        
        function exportRequestCb(this, varargin)
            % If this is not true, then we can just leave this
            % function since the user would have cancelled.
            if(this.updateExportPath())
                try
                    [didExport, msg] = this.exportToDisk();
                catch me
                    msg = 'An error occurred while trying to save the data to disk.  A thousand apologies.  I''m very sorry.';
                    showME(me);
                end
                
                % Give the option to look at the files in their saved folder.
                if(didExport)
                    dlgName = 'Export complete';
                    closeStr = 'Close';
                    showOutputFolderStr = 'Open output folder';
                    options.Default = closeStr;
                    options.Interpreter = 'none';
                    buttonName = questdlg(msg,dlgName,closeStr,showOutputFolderStr,options);
                    if(strcmpi(buttonName,showOutputFolderStr))
                        openDirectory(this.getExportPath())
                    end
                else
                    makeModal = true;
                    pa_msgbox(msg,'Export',[],makeModal);
                end
            end
        end
    end
    methods(Static)
        function settings = getDefaultParameters()
            settings = struct();
            if(ispc)
                homePath = getenv('USERPROFILE');                
                settings.exportPathname = fullfile(homePath,'My Documents');  
            else
                homePath = getenv('HOME');                
                if(isempty(homePath))
                    homePath = '~/';
                end
                settings.exportPathname = fullfile(homePath,'Documents/');  
            end
        end
    end
end
    
    
    
   