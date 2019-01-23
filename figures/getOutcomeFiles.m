function outcomeFileStruct = getOutcomeFiles(outcomeFileStruct)
    % figFile = 'importOutcomesDlg.fig';
    % x = load(figFile,'-mat');
    figFcn = @importOutcomesDlg;
    f = figFcn('visible','off');
    handles = getchildren(f);
    initHandles(handles);
    
    set(f,'visible','on');
    
    uiwaitfor(f,'visible','off');
    if(ishandle(f))
        outcomeFileStruct = getOutcomeFileStruct(handles,outcomeFileStruct);
        delete(f)
    else
        outcomeFileStruct = [];
    end
end

function canIt = canImport(handles)
    outStruct = getOutcomeFileStruct(handles);
    canIt = exist(outStruct.outcomes,'file') && exist(outStruct.subjects,'file');
end

function sOut = getOutcomeFileStruct(handles)
    sOut.outcomes = get(handles.edit_outcomesFilename,'string');
    sOut.subjects = get(handles.edit_subjectsFilename,'string');
    sOut.dictionary = get(handles.edit_dictionaryFilename,'string');
end

function initHandles(handles,outStruct)
    % text handles
    fields = {'outcomes','subjects','dictionary'};
    for f=1:numel(fields)
        tag = fields{f};
        hTag = sprintf('edit_%sFilename',tag);
        editH = handles.(hTag);
        set(editH,'enable','inactive','string','');
        
        hTag = sprintf('push_%s',tag);
        pushH = handles.(hTag);
        set(pushH,'callback',{@getFileCallback,tag,editH});
        if(isfield(outStruct,tag))
            filename = outStruct.tag;
            if(exist(filename,'file') && ~isdir(filename))                
                set(editH,'string',filename);
            end
        end
    end   
    set(handles.push_import,'callback', @hideFigureCb);
    set(handles.push_cancel,'callback', 'closereq');
end

function hideFigureCb(varargin)
    set(gcf,'visible','off');
end

function getFileCallback(hObject, ~, category, editH)
    handles = guidata(hObject);
    if(canImport(handles))
        set(handles.push_import,'enable','on');
    else
        set(handles.push_import,'enable','off');
    end
end