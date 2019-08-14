%> function htmlBrowser = htmldlg('url',validURL)
%> function htmlBrowser = htmldlg('html',html formated string)

% Testing
% htmldlg('html','<html><body><h1>Welcome</h1><h6>... to your doom!</h6></body></html>')
%> Thank you to Yair Altman and his blog post at http://undocumentedmatlab.com/blog/customizing-help-popup-contents
%> which inspired this function.
function htmldlg(varargin)
    %names = {'url','html','title'};
    %defaults = {[],[],'Padaco Help'};
    %[url, html,titleStr] = parsepvpairs(names,defaults,varargin{:});

    args.url = '';
    args.html = '';
    args.title = 'Padaco Help';
    args = mergepvpairs(args,varargin{:});
    url = args.url;
    html = args.html;
    titleStr = args.title;
    %> The following is taken from Yair Altman's blog post at http://undocumentedmatlab.com/blog/customizing-help-popup-contents
    % Find the Help popup window
    
    %     jDesktop = com.mathworks.mde.desk.MLDesktop.getInstance;
    %     jMainFrame = jDesktop.getMainFrame;
    %     jTextArea = jDesktop.getMainFrame.getFocusOwner;
    jTextArea= com.mathworks.mde.cmdwin.XCmdWndView.getInstance;
    jClassName = 'com.mathworks.mlwidgets.help.HelpPopup';
    
    % hint:  methods(jClassName)
    %        methodsview(jClassName)
    jPosition = java.awt.Rectangle(0,0,900,600);
    helpTopic = [];
    javaMethodEDT('setShowHelpBrowserPreference',jClassName,false);
    javaMethodEDT('showHelp',jClassName,jTextArea,[],jPosition,helpTopic);
    
    
    jWindows = com.mathworks.mwswing.MJDialog.getWindows;
    jPopup = [];
    for idx=length(jWindows):-1:1
        if strcmpi(get(jWindows(idx),'Name'),'HelpPopup')

            if jWindows(idx).isVisible
                jPopup = jWindows(idx);
                %%fprintf('We have a visible frame at %i\n',idx);
                %%break;
            else
                % %jWindows(idx).show;
                %fprintf('We have a non visible frame at %i\n',idx);
                
            end
        end
    end
    
    % Update the popup with selected HTML
    if ~isempty(jPopup) && (~isempty(url)||~isempty(html))
        jPopup.setTitle(titleStr);
      
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
        contentPanel.repaint();
    end
    
end
