%> function htmlBrowser = htmldlg('url',validURL)
%> function htmlBrowser = htmldlg('html',html formated string)

% Testing
% htmldlg('html','<html><body><h1>Welcome</h1><h6>... to your doom!</h6></body></html>')
%> Thank you to Yair Altman and his blog post at http://undocumentedmatlab.com/blog/customizing-help-popup-contents
%> which inspired this function.
function htmldlg(varargin)
    names = {'url','html'};
    defaults = {[],[]};
    [url, html] = parsepvpairs(names,defaults,varargin{:});
    
    %> The following is taken from Yair Altman's blog post at http://undocumentedmatlab.com/blog/customizing-help-popup-contents
    % Find the Help popup window
    
    %     jDesktop = com.mathworks.mde.desk.MLDesktop.getInstance;
    %     jMainFrame = jDesktop.getMainFrame;
    %     jTextArea = jDesktop.getMainFrame.getFocusOwner;
    jTextArea= com.mathworks.mde.cmdwin.XCmdWndView.getInstance;
    jClassName = 'com.mathworks.mlwidgets.help.HelpPopup';
    jPosition = java.awt.Rectangle(0,0,900,600);
    helpTopic = [];
    javaMethodEDT('showHelp',jClassName,jTextArea,[],jPosition,helpTopic);
    
    
    jWindows = com.mathworks.mwswing.MJDialog.getWindows;
    jPopup = [];
    for idx=length(jWindows):-1:1
        if strcmpi(get(jWindows(idx),'Name'),'HelpPopup')

            if jWindows(idx).isVisible
                jPopup = jWindows(idx);
                break;
            end
        end
    end
    
    % Update the popup with selected HTML
    if (~isempty(jPopup) && (~isempty(url) || ~isempty(html)))
        jPopup.setTitle('Padaco Help');
        contentPanel = jPopup.getContentPane.getComponent(0).getComponent(1);
        statusBar = jPopup.getContentPane.getComponent(1).getComponent(0);
        toolbar = jPopup.getContentPane.getComponent(0).getComponent(0);
        unwantedHyperLink = jPopup.getComponent(0).getComponent(1).getComponent(0).getComponent(1).getComponent(1).getComponent(1);
        unwantedHyperLink.hide;
        % Default to the input html over a location.  
        if(~isempty(html))
            contentPanel.setHtmlText(html);
        else
            contentPanel.setCurrentLocation(url); 
        end
    end
    
end
