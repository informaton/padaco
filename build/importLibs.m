function importLibs()
    
    matlab.widgets = {
        'dissolve.m'
        'disableHandles.m'
        'enableHandles.m'
        'fitTable.m'
        'fitTableHeight.m'
        'fitTableWidth.m'
        'getMenuParameter.m'
        'getMenuString.m'
        'getMenuUserData.m'
        'getSelectedMenuString.m'
        'getSelectedMenuUserData.m'
        'openDirectory.m'
        'resizePanelAndFigureForUIControls.m'
        'resizePanelWithScrollbarOption.m'
        'showPathContextmenuCallback.m'
        'viewTextFileCallback.m'
        };
    
    matlab.figures = {
        'helpViewer.m'
        'htmldlg.m'
        'pair_value_dlg.fig'
        'pair_value_dlg.m'
        'resetDlg.m'
        'restartDlg.m'
        'textFileViewer.m'
        'uigetfulldir.m'
        'uigetfullfile.m'
        };
    
    srcPath = '~/git/matlab';
    destPath = '~/git/padaco';
    fields = fieldnames(matlab);
    for f=1:numel(fields)
        curField = fields{f};
        curStruct = matlab.(curField);
        curDestPath = fullfile(destPath,curField);
        for c=1:numel(curStruct)
            filename = curStruct{c};
            fullSrcFile = fullfile(srcPath,curField,filename);
            if(exist(fullSrcFile,'file'))
                copyfile(fullSrcFile,curDestPath);
                curDestFile = fullfile(curDestPath,filename);
                [status, result] = system(strcat('chmod -w ',curDestFile)); % make sure we can't write to these files.  Want to update them in their own repositories (and I don't want to use git submodules)
                if(~status)
                    fprintf('Could not make %s read only.\n\t%s\n',result);
                end
            else
                fprintf('%s: file not found!\n',fullSrcFile);
            end
        end
    end
end