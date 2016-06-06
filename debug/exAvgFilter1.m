% plot a semi-nice looking averaging filter
function exAvgFilter1(vec)
    
    close all;
    short = ones(300,1);
    long = ones(900,1);
    xVec=1:numel(vec);
    xshort = 1:numel(short);
    xlong = 1:numel(long);
    
    y_long = filter(long,1,vec);
    y_long = y_long/numel(long);  % make it a moving averager
    y_short = filter(short,1,vec);
    y_short = y_short/(numel(short));
    
    
    awakeVsAsleepCountsPerSecondCutoff = 1;  % exceeding the cutoff means you are awake
    activeVsInactiveCountsPerSecondCutoff = 10; % exceeding the cutoff indicates active
    onBodyVsOffBodyCountsPerMinuteCutoff = 1; % exceeding the cutoff indicates on body (wear
    candidateNonWear = onBodyVsOffBodyCountsPerMinuteCutoff;
    
    y_candidateNonWear = repmat(candidateNonWear,size(y_long));
    y_activeVsInactive = repmat(activeVsInactiveCountsPerSecondCutoff, size(y_long));
    
    x = 1:numel(y_long);
    
    %% Figure 1
    
    xlimit = [1, numel(vec)];
    xticks = linspace(1,numel(vec),25);
    d=num2str((0:24)');
    figure;
    subplot(3,1,1)
    plot(vec);
    set(gca,'xtick',xticks,'xticklabel',d)
    
    xlim(xlimit);
    ylabel('x[n]','fontsize',12);
    xlabel('n');
    title('Vector magnitude counts','fontsize',14);
    
    subplot(3,1,2);
    plot(y_short);
    xlim(xlimit);
    ylabel('x[n]\otimesh[n]_{short}','fontsize',12);
    xlabel('n');
    title('Results with short averaging filter','fontsize',14);
    set(gca,'xtick',xticks,'xticklabel',d)
    
    subplot(3,1,3);
    plot(y_long);
    xlim(xlimit);
    ylabel('x[n]\otimesh[n]_{long}','fontsize',12);
    title('Results with long averaging filter','fontsize',14);
    set(gca,'xtick',xticks,'xticklabel',d)
    xlabel('n');
    
    set(gcf,'color',[1 1 1],'inverthardcopy','off')
    
    
    %% Figure of short and long average filter output only
    
    
    figure;
    subplot(2,1,1)
    
    
    plot(y_short);
    xlim(xlimit);
    ylabel('x[n]\otimesh[n]_{short}','fontsize',13);
    xlabel('n');
    title('Short average (5 minute) result','fontsize',14);
    set(gca,'xtick',xticks,'xticklabel',d)
    
    subplot(2,1,2);
    plot(y_long);
    xlim(xlimit);
    ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
    title('Long average (15 minute) result','fontsize',14);
    set(gca,'xtick',xticks,'xticklabel',d)
    xlabel('n');
    
    set(gcf,'color',[1 1 1],'inverthardcopy','off')
    
    %% Long average result only
    figure;
    myPlotHelper();
    myLegendHelper();
    set(gcf,'color',[1 1 1],'inverthardcopy','off')
    
    
    %% Long average with zooms 1 and 2
    figure;
    subplot(3,1,1);
    myPlotHelper();
    myLegendHelper();
    ylim([-5, max(y_long)]);
    
    subplot(3,1,2);
    myPlotHelper();
    title('Zoom');
        
    ylim([-2 30]);
    
    subplot(3,1,3);
    myPlotHelper();
    title('Zoom x2','fontsize',14);
        
    ylim([-1 5]);
    
    set(gcf,'color',[1 1 1],'inverthardcopy','off');
    
    function myLegendHelper()
        h=legend('Moving average of counts','Active vs inactive threshold','Wake vs sleep threshold');
        set(h,'fontsize',12,'location','northwest');
        
    end
    
    function myPlotHelper()
        
        plot(x,y_long,'b-',x,y_activeVsInactive,'g-.',x,y_candidateNonWear,'r-.');
        ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
        title('Long average (15 minute) result','fontsize',14);
        set(gca,'xtick',xticks,'xticklabel',d)
        xlabel('n');
        
        xlim(xlimit);
        
    end
end





