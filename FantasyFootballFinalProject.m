%% Initialize variables
clear,clc
% Gets data from myfantasyleague. Download this data as a backup!
allPlayers=webread( 'http://www03.myfantasyleague.com/2016/export?TYPE=players&L=&W=&JSON=1');
roster=webread('http://www60.myfantasyleague.com/2016/export?TYPE=rosters&L=76845&W=&JSON=1');
franchise=webread('http://www60.myfantasyleague.com/2016/export?TYPE=league&L=76845&W=&JSON=1');
weekTot=16;
for n=1:weekTot % Get scoring data for every week
    url='http://www59.myfantasyleague.com/2015/export?TYPE=playerScores&JSON=1&L=35465&W=';
    url=strcat(url,num2str(n));
    week(n,:)=webread(url);
end
positions = struct('QB',1,'RB',2,'WR',3,'TE',1,'PK',1,'Def',1,'FLEX',1);
regSeason=13;
%% Create better players array
for g=1:length(allPlayers.players.player)
    players(g).id=allPlayers.players.player{g,1}.id;
    players(g).info.name=allPlayers.players.player{g,1}.name;
    players(g).info.position=allPlayers.players.player{g,1}.position;
    players(g).info.team=allPlayers.players.player{g,1}.team;
end
%% Create raw roster data and player scores
teams=length(roster.rosters.franchise);
for k=1:teams % Gets players and franchise name
    for l=1:length(roster.rosters.franchise(k).player)
        rawData(k).franchise = roster.rosters.franchise(k);
        rawData(k).franchise.name = franchise.league.franchises.franchise{k,1}.name;
        rawData(k).franchise.idnum = str2double(roster.rosters.franchise(k).id);  
        rawData(k).franchise.wins = 0;
    end   
end
for k=1:teams % Adds player data to rawData
    allTeams(k)=str2double(rawData(k).franchise.id);
    for l=1:length(roster.rosters.franchise(k).player)
        index = find(strcmp({rawData(k).franchise.player(l).id}, {players.id})==1);
        if (index ~= 0)
            rawData(k).franchise.player(l).position=players(index).info.position;
            rawData(k).franchise.player(l).name=players(index).info.name;
            rawData(k).franchise.player(l).team=players(index).info.team;
        end 
    end   
end
for h=1:weekTot % Adds weekly player scores to rawData structure
    for t=1:teams
        for r=1:length(rawData(t).franchise.player)
            scores = find(strcmp({rawData(t).franchise.player(r).id},...
                {week(h).playerScores.playerScore.id})==1);
            if (scores ~= 0)
                rawData(t).franchise.player(r).score(h).week=...
                    week(h).playerScores.playerScore(scores).score;
            end 
        end
    end
end
%% Randomize matchups
for w=1:regSeason
    % This does not play each team once, it currently randomizes each week
    % independent of each other week. This is hopefully temporary, and I
    % will be making each team play each other team 1-2 times
    schedule.week(w).matchup(6,2) = 0;
    schedule.week(w).matchup(:) = allTeams(randperm(numel(allTeams)));
end
%% Get scores for each week for each franchise
for w=1:weekTot % Create structure with weekly scores 
    for t=1:teams
        for r=1:length(rawData(t).franchise.player)
            totScore = length(rawData(t).franchise.player(r).score);
            if (totScore <= 15)
                for b=totScore+1:16
                    rawData(t).franchise.player(r).score(b).week = '0';
                end
            end
            if (~isempty(rawData(t).franchise.player(r).score)...
                    & isempty(rawData(t).franchise.player(r).score(w).week))
                rawData(t).franchise.player(r).score(w).week='0';
            end
            scoreCheck = cellfun(@length, {rawData(t).franchise.player.score});
            if (scoreCheck(r) ~= 0)
                wkscore(r,w,t) = str2double(rawData(t).franchise.player(r).score(w).week);
                weekScore(w).team(t).player(r).id=rawData(t).franchise.player(r).id;
                weekScore(w).team(t).player(r).position=rawData(t).franchise.player(r).position;
                weekScore(w).team(t).player(r).score=rawData(t).franchise.player(r).score(w).week;
                weekScore(w).team(t).player(r).scoreInt=...
                    str2double(rawData(t).franchise.player(r).score(w).week);
            end
        end
        weekScore(w).team(t).score = 0;
    end
end
%% Calculate scores for each franchise each week
for w=1:weekTot % Find highest scorers each week, sorted list in structure
    for t=1:teams
        scoreMat=[1:length(weekScore(w).team(t).player);weekScore(w).team(t).player.scoreInt];
        [Y,I]=sort(scoreMat(2,:),'descend');
        sortedScores=scoreMat(:,I);
        for m=1:length(weekScore(w).team(t).player)
            weekScore(w).team(t).player(sortedScores(1,m)).sorted=m;
        end
    end
end
for w=1:weekTot % Calculate weekly starters
    for t=1:teams % Find which players would start each week
        tempPos = positions;
        for m=1:length(weekScore(w).team(t).player)
            new(m) = find([weekScore(w).team(t).player.sorted] == m);
            scr = str2double(weekScore(w).team(t).player(new(m)).score);
            pos = char(weekScore(w).team(t).player(new(m)).position);
            if (tempPos.(weekScore(w).team(t).player(new(m)).position) > 0)
                tempPos.(weekScore(w).team(t).player(new(m)).position) =...
                    tempPos.(weekScore(w).team(t).player(new(m)).position)-1;
                weekScore(w).team(t).player(new(m)).starter = 1;
            elseif (tempPos.FLEX) > 0 & ... % Get FLEX starter (RB,WR,TE)
                    (weekScore(w).team(t).player(new(m)).position=='RB' |...
                    weekScore(w).team(t).player(new(m)).position=='WR' |...
                    weekScore(w).team(t).player(new(m)).position=='TE')
                tempPos.FLEX=tempPos.FLEX-1;
                weekScore(w).team(t).player(new(m)).starter = 1;
            else
                weekScore(w).team(t).player(new(m)).starter = 0;
            end
        end
    end
end
for w=1:weekTot % Calculate weekly scores
    for t=1:teams
        for m=1:length(weekScore(w).team(t).player)
            if (weekScore(w).team(t).player(m).starter == 1)
                weekScore(w).team(t).score = weekScore(w).team(t).score+...
                    weekScore(w).team(t).player(m).scoreInt;
            end
        end
    end
end
%% Calculate win totals, standings, and playoff seeding
for w=1:regSeason % Calculate win totals
    for m=1:length(schedule.week(w).matchup)
        team1 = schedule.week(w).matchup(m,1);
        team2 = schedule.week(w).matchup(m,2);
        team1score = weekScore(w).team(team1).score;
        team2score = weekScore(w).team(team2).score;
        winner = max(team1score,team2score);
        if (winner == team1score)
            rawData(team1).franchise.wins = rawData(team1).franchise.wins+1;
        else
            rawData(team2).franchise.wins = rawData(team2).franchise.wins+1;
        end
    end
end
for t=1:teams % Create standings structure
    standings(t).id = rawData(t).franchise.id;
    standings(t).franchise = rawData(t).franchise.name;
    standings(t).wins = rawData(t).franchise.wins;
    standings(t).losses = 13-rawData(t).franchise.wins;
end
[winTot,teamWins] = sort([standings.wins],'Descend');
for t=1:teams % Create standings table
    Wins(t,1) = standings(teamWins(t)).wins;
    Losses(t,1) = standings(teamWins(t)).losses;
    Team{t,1} = char(standings(teamWins(t)).franchise);
    standings(teamWins(t)).place = t;
    Place(t,1) = t;
end
Team = cell(Team);
standingsTable = table(Wins,Losses,Place,'RowNames',Team);
playoffTeams = 6; playoffGames = playoffTeams-1; playoffRounds = 3;
%% Calculate playoff winners
schedule.week(14).matchup(1,1) = find([standings.place] == 3);
schedule.week(14).matchup(1,2) = find([standings.place] == 6);
schedule.week(14).matchup(2,1) = find([standings.place] == 4);
schedule.week(14).matchup(2,2) = find([standings.place] == 5);
schedule.week(15).matchup(1,1) = find([standings.place] == 1);
schedule.week(15).matchup(2,1) = find([standings.place] == 2);
game1team1score = weekScore(14).team(schedule.week(14).matchup(1,1)).score;
game1team2score = weekScore(14).team(schedule.week(14).matchup(1,2)).score;
game1winner = max(game1team1score,game1team2score);
game2team1score = weekScore(14).team(schedule.week(14).matchup(2,1)).score;
game2team2score = weekScore(14).team(schedule.week(14).matchup(2,2)).score;
game2winner = max(game2team1score,game2team2score);
if (game1winner == game1team1score)
    schedule.week(15).matchup(1,2) = schedule.week(14).matchup(1,1);
else
    schedule.week(15).matchup(1,2) = schedule.week(14).matchup(1,2);
end
if (game2winner == game2team1score)
    schedule.week(15).matchup(2,2) = schedule.week(14).matchup(2,1);
else
    schedule.week(15).matchup(2,2) = schedule.week(14).matchup(2,2);
end
game3team1score = weekScore(15).team(schedule.week(15).matchup(1,1)).score;
game3team2score = weekScore(15).team(schedule.week(15).matchup(1,2)).score;
game3winner = max(game3team1score,game3team2score);
game4team1score = weekScore(15).team(schedule.week(15).matchup(2,1)).score;
game4team2score = weekScore(15).team(schedule.week(15).matchup(2,2)).score;
game4winner = max(game4team1score,game4team2score);
if (game3winner == game3team1score)
    schedule.week(16).matchup(1,1) = schedule.week(15).matchup(1,1);
else
    schedule.week(16).matchup(1,1) = schedule.week(15).matchup(1,2);
end
if (game4winner == game4team1score)
    schedule.week(16).matchup(1,2) = schedule.week(15).matchup(2,1);
else
    schedule.week(16).matchup(1,2) = schedule.week(15).matchup(2,2);
end
game5team1score = weekScore(16).team(schedule.week(16).matchup(1,1)).score;
game5team2score = weekScore(16).team(schedule.week(16).matchup(1,2)).score;
game5winner = max(game5team1score,game5team2score);
if (game3winner == game3team1score)
    schedule.week(17).matchup(1,1) = schedule.week(16).matchup(1,1);
else
    schedule.week(17).matchup(1,1) = schedule.week(16).matchup(1,2);
end
%% Display standings and playoff matchups
standingsTable
fprintf('Game 1, Round 1: %s vs %s\n',rawData(schedule.week(14).matchup(1,1)).franchise.name,...
    rawData(schedule.week(14).matchup(1,2)).franchise.name);
fprintf('Game 2, Round 1: %s vs %s\n',rawData(schedule.week(14).matchup(2,1)).franchise.name,...
    rawData(schedule.week(14).matchup(2,2)).franchise.name);
fprintf('Game 3, Semifinal: %s vs %s\n',rawData(schedule.week(15).matchup(1,1)).franchise.name,...
    rawData(schedule.week(15).matchup(1,2)).franchise.name);
fprintf('Game 4, Semifinal: %s vs %s\n',rawData(schedule.week(15).matchup(2,1)).franchise.name,...
    rawData(schedule.week(15).matchup(2,2)).franchise.name);
fprintf('Game 5, Championship: %s vs %s\n',rawData(schedule.week(16).matchup(1,1)).franchise.name,...
    rawData(schedule.week(16).matchup(1,2)).franchise.name);
fprintf('Champion: %s\n',rawData(schedule.week(17).matchup(1,1)).franchise.name);