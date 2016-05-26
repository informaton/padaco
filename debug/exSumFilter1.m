% plot a semi-nice looking summing filter
close all;
short = ones(300,1);
long = ones(900,1);
xVec=1:numel(vec);
xshort = 1:numel(short);
xlong = 1:numel(long);

figure;
int = 1:5:numel(xshort);stem(xshort(int),short(int));xlim([-50,350]);ylim([-0.5,1.5])
title('h_{short}')
xlabel('n')
ylabel('h_{short}[n]')
set(gcf,'color',[1 1 1],'inverthardcopy','off')

figure;
subplot(2,1,1);
int = 1:5:numel(xshort);stem(xshort(int),short(int));xlim([-50,numel(xlong)+50]);ylim([-0.5,1.5])
title('h_{short}')
xlabel('n')
ylabel('h_{short}[n]')

subplot(2,1,2);
int = 1:5:numel(xlong);stem(xlong(int),long(int));xlim([-50,numel(xlong)+50]);ylim([-0.5,1.5])
title('h_{long}')
xlabel('n')
ylabel('h_{long}[n]')


set(gcf,'color',[1 1 1],'inverthardcopy','off')


y_long = filter(long,1,vec);

% y_long = y_long/numel(long);  % make it a moving averager

%% Figure 3

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
plot(filter(short,1,vec));
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{short}','fontsize',12);
xlabel('n');
title('Results with short summing filter','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)

subplot(3,1,3);
plot(y_long);
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{long}','fontsize',12);
title('Results with long summing filter','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

set(gcf,'color',[1 1 1],'inverthardcopy','off')


%% Figure of short and long sum filter output only


figure;
subplot(2,1,1)


plot(filter(short,1,vec));
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{short}','fontsize',13);
xlabel('n');
title('Short sum (5 minute) result','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)

subplot(2,1,2);
plot(y_long);
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
title('Long sum (15 minute) result','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

set(gcf,'color',[1 1 1],'inverthardcopy','off')

%% Long sum result only
figure;
plot(y_long);
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
title('Long sum (15 minute) result','fontsize',14);
%title('Long average (15 minute) result','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

set(gcf,'color',[1 1 1],'inverthardcopy','off')

figure;
subplot(3,1,1);
plot(y_long);
xlim(xlimit);
ylim([-5, max(y_long)]);
ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
title('Long averaging using a 15 minute moving window','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

subplot(3,1,2);
plot(y_long);
xlim(xlimit);
ylim([-2 30]);
ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
title('zoom * 1','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

subplot(3,1,3);
plot(y_long);
xlim(xlimit);
ylim([-1 5]);
ylabel('x[n]\otimesh[n]_{long}','fontsize',13);
title('zoom * 2','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

set(gcf,'color',[1 1 1],'inverthardcopy','off')

