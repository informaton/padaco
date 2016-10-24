function latexText = makeLatexFigureText(figureNames,pathname)
    if(nargin<2)
        pathname = 'batch';
        if(nargin<1)
            figureNames = {'classificationOptions.png';
                'fileSelectionOfGoalsData.png';
                'finalSettings.png';
                'initialBatchScreen.png';
                'inputOutputForSampleData.png';
                'menu_feature_intervalMinutes.png';
                'menu_featureSelections.png';
                'openSamplePath.png';
                'outputDirectoryForSampleData.png';
                'saveImageOptions.png';
                'sourceDirectoryForSampleData.png';
                'sourceDirectoryOfGoalsData.png';
                'switch2batch.png'};
            figureNames = {'complete_with_all_errors_selected.png'
                'complete_with_errors.png'
                'waitbar_1minute.png'
                'waitbar_50pct.png'
                'waitbar_finished.png'
                };
            
            figureNames = {'sampleDataResultsDialog.png'
                'contextmenu_openPath_2.png'
                'contextmenu_openPath.png'
                };
        end
    end
    if(~iscell(figureNames))
        figureNames = {figureNames};
    end;
    
    latexText = cell(size(figureNames));
    for f=1:numel(figureNames)
        filename = fullfile(pathname,figureNames{f});
        [~,label,~] = fileparts(filename);
        label = strcat(pathname,'_',label);
        latexText{f} = sprintf(['\\begin{figure}[!ht]',...
            '\n\t\\centering',...
            '\n\t\\includegraphics{%s}',...
            '\n\t\\caption{<caption>}',...
            '\n\t\\label{fig:%s}',...
            '\n\\end{figure}'],filename,label);
        
        if(nargout==0)
            fprintf(1,'\nFigure~\\ref{fig:%s}\n',label);
            fprintf(1,'\n%s\n',latexText{f});
        end
        
    end
    
    
    if(nargout==0)
        fprintf(1,'\n');
        clear latexText;
    end

end
