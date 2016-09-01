require "sqlite3"
require "json"
require "#{File.dirname(__FILE__)}/AnalyzerBase.rb"
require "#{File.dirname(__FILE__)}/../Config.rb"
require "#{File.dirname(__FILE__)}/../RecordUnzipper/Replay.rb"
require "#{File.dirname(__FILE__)}/../RecordUnzipper/Deck.rb"
require "#{File.dirname(__FILE__)}/../RecordUnzipper/Card.rb"

class SQLSingleCardAnalyzer < AnalyzerBase
    CreateTableCommand = <<-COMMAND
        create table if not exists %s 
        (
            cardID primary key, 
            frequency int default 0,
            numbers int default 0,
            putOne int default 0,
            putTwo int default 0,
            putThree int default 0
        );
        COMMAND
    
    MoveTableCommand = "alter table %s rename to %s;"

    CheckAddTableCommand = <<-COMMAND
        insert or ignore into %s 
        select cardID, 0, 0, 0, 0, 0 from %s
    COMMAND

    AddTableCommand = <<-COMMAND
         update %1$s set
            frequency = (select frequency from %2$s where %1$s.cardID == %2$s.cardID),
            numbers = numbers + (select numbers from %2$s where %1$s.cardID == %2$s.cardID),
            putOne = putOne + (select putOne from %2$s where %1$s.cardID == %2$s.cardID),
            putTwo = putTwo + (select putTwo from %2$s where %1$s.cardID == %2$s.cardID),
            putThree = putThree + (select putThree from %2$s where %1$s.cardID == %2$s.cardID)
        where exists(select * from %2$s where %1$s.cardID == %2$s.cardID)
    COMMAND

    RemoveTableCommand = "drop table if exists %s"

=begin
    # Fuck sqlite
    AddTableCommand = <-COMMAND
        update %1$s, %2$s set
            %1$s.frequency = %1$s.frequency + %2$s.frequency,
            %1$s.numbers = %1$s.numbers + %2$s.numbers,
            %1$s.putOne = %1$s.putOne + %2$s.putOne,
            %1$s.putTwo = %1$s.putTwo + %2$s.putTwo,
            %1$s.putThree = %1$s.putThree + %2$s.putThree,
        where %1$s.id == %2$s.id
    COMMAND
=end

    CreateCardCommand = "insert or ignore into %s (cardID, frequency, numbers, putOne, putTwo, putThree) values (%s, 0, 0, 0, 0, 0);"
    UpdateCardCommand = <<-COMMAND
        update %s set
            frequency = frequency + %s,
            numbers = numbers + %s,
            putOne = putOne + %s,
            putTwo = putTwo + %s,
            putThree = putThree + %s
        where cardID == %s;
    COMMAND

    ResultCommand = "select * from %s order by frequency limit %s"
    SelectIDCommand = "select cardID from %s"
    
    DailyTableName = "Day_%s_%s_%s" # 年 月 日
    WeeklyTableName = "Week_%s_%s" # 年 周
    MonthlyTableName = "Month_%s_%s" # 年 月
    SeasonTableName = "Season_%s_%s" # 年 季（按表分割）
    CurrentDailyTableName = "Day"
    CurrentWeekTableName = "Week"
    CurrentMonthTableName = "Month"
    CurrentSeasonTableName = "Season"

    attr_reader :database

    def initialize
        @database = SQLite3::Database.new $config["SingleCardAnalyzer"]["DatabaseName"]
        @temp_stats = {}
        create
    end

    # Dangerous!!!
    def self.remove_database
        databse = $config["SingleCardAnalyzer"]["DatabaseName"]
        File.unlink databse
    end

    def execute_commands(commands)
        begin
            # puts commands
            commands.each { |command| @database.execute command }
        rescue => exception
            puts exception
        end
    end

    def execute_command(command)
        begin
            # puts command
            @database.execute command
        rescue => exception
            puts exception
        end
    end

    def create
        commands = [
            sprintf(CreateTableCommand, CurrentDailyTableName),
            sprintf(CreateTableCommand, CurrentWeekTableName),
            sprintf(CreateTableCommand, CurrentMonthTableName),
            sprintf(CreateTableCommand, CurrentSeasonTableName)
        ]
        execute_commands commands
    end

    def analyze(obj)
        if obj.is_a?(Replay)
            analyze_record obj
        elsif obj.is_a?(Deck)
            analyze_deck obj
        end
    end

    def analyze_record(record)
        for deck in record.decks
            analyze_deck deck
        end
    end

    def analyze_deck(deck)
        if $config["SingleCardAnalyzer"]["Manual"]
            add_deck_to_temp deck
        else
            commands = create_deck_command CurrentDailyTableName, deck
            execute_commands commands
        end
    end

    def create_deck_stats(deck)
        deck.classify if deck.cards_classified == nil
        create_pack_stats deck.cards_classified
    end

    def create_pack_stats(classifiedPack)
        ans = {}
        for cardID in classifiedPack.keys
            nums = [1, 0, 0, 0, 0]
            nums[1] += classifiedPack[cardID]
            nums[[classifiedPack[cardID], 3].min + 1] += 1
            ans[cardID] = nums
        end
        ans
    end
    
    def clear(*args)
        # 思维回路：
        # 今日统计加入本周统计
        # 今日统计加入本月统计
        # 清除今日统计
        # 今天是本周最后一天？ 清除本周统计
        # 今天是本月最后一天？ 清除本月统计
        #   本月统计加入本季统计
        #   今天是本季最后一月？ 清除本季统计
        time = draw_time_arg *args
        add_day_to_week
        add_day_to_month
        clear_day time
        clear_week time if is_week_last_day? time
        if is_month_last_day? time
            add_month_to_season
            clear_season time if is_season_last_month? time
        end
    end

    def result(table_name = "Day")
        res = execute_command create_result_command(table_name)
    end

    def output(*args)
        time = draw_time_arg *args
        f = File.open($config["SingleCardAnalyzer"]["OutputJsonName"], "w")
        day = result CurrentDailyTableName
        week = result CurrentWeekTableName
        month = result CurrentMonthTableName
        season = result CurrentSeasonTableName
        key_names = $config["SingleCardAnalyzer"]["OutputNames"]
        day_key = search_key_name key_names, "Day"
        week_key = search_key_name key_names, "Week"
        month_key = search_key_name key_names, "Month"
        season_key = search_key_name key_names, "Season"
        time_key = search_key_name key_names, "Time"
        hash = 
        {
            day_key => day,
            week_key => week,
            month_key => month,
            season_key => season,
            time_key => time.to_i
        }
        f.write hash.to_json
        f.close
    end

    def finish
        push_temp_to_sql
    end

    def search_key_name(names, name)
        names = {} if names == nil
        key = names[name]
        key = name if key == nil
        key
    end

    def draw_time_arg(*args)
        time = args[0]
        time = Time.now if time == nil
        time = Time.at time if time.is_a? Fixnum
        time = Time.gm *time.split("-") if time.is_a? String
        time
    end

    def clear_day(time)
        commands = create_clear_day_commands(time)
        execute_commands commands
    end

    def clear_week(time)
        commands = create_clear_week_commands(time)
        execute_commands commands
    end

    def clear_month(time)
        commands = create_clear_month_commands(time)
        execute_commands commands
    end

    def clear_season(time)
        commands = create_clear_season_commands(time)
        execute_commands commands
    end

    def is_week_last_day?(time)
        time.wday == 6
    end

    def is_month_last_day?(time)
        (time + 86400).mday == 1 # 脏
    end

    def is_season_last_month?(time)
        time.month % 3 == 0
    end

    def add_day_to_week
        execute_commands create_add_day_to_week_commands
    end

    def add_day_to_month
        execute_commands create_add_day_to_month_commands
    end

    def add_day_to_season
        execute_commands create_add_day_to_season_commands
    end 
    
    def add_month_to_season
        execute_commands create_add_month_to_season_commands
    end

    def add_deck_to_temp(deck)
        stats = create_deck_stats deck
        stats.keys.each {|cardID| add_stat_to_temp(cardID, stats[cardID])}
    end

    def add_stat_to_temp(cardID, stat)
        if @temp_stats[cardID] == nil
            @temp_stats[cardID] = [0, 0, 0, 0, 0]
        end
        (0..4).each {|i| @temp_stats[cardID][i] += stat[i]}
    end
    
    def push_temp_to_sql(table_name = "Day")
        return if @temp_stats == nil
        process_alias_temp
        commands = ['begin;']
        @temp_stats.keys.each do |cardID|
            commands += create_card_command table_name, cardID, @temp_stats[cardID]
        end
        commands += ['commit;']
        execute_commands commands
        clear_temp
    end

    def clear_temp
        @temp_stats = {}
    end

    def process_alias_temp
        SQLSingleCardAnalyzer.load_alias
        @@alias_list.keys.each do |id|
            next if @temp_stats[id] == nil
            add_stat_to_temp id, @@alias_list[id]
            @temp_stats.delete id
        end
    end

    def self.load_alias
        return if class_variable_defined?("@@alias_list")
        @@alias_list = Card.alias_list
    end

    def create_deck_command(table_name, deck)
        SQLSingleCardAnalyzer.load_alias
        stats = create_deck_stats deck
        commands = ["begin;"]
        for cardID in stats.keys do
            cardID = @@alias_list[cardID] if @@alias_list[cardID] != nil
            commands += create_card_command(table_name, cardID, stats[cardID])
        end
        commands += ["commit;"]
        commands
    end

    def create_clear_day_commands(time)
        new_table_name = sprintf DailyTableName, time.year, time.month, time.day
        create_move_table_commands CurrentDailyTableName, new_table_name
    end

    def create_clear_week_commands(time)
        new_table_name = sprintf WeeklyTableName, time.year, time.strftime("%U")
        create_move_table_commands CurrentWeekTableName, new_table_name
    end

    def create_clear_month_commands(time)
        new_table_name = sprintf MonthlyTableName, time.year, time.month
        create_move_table_commands CurrentMonthTableName, new_table_name
    end

    def create_clear_season_commands(time)
        # 1.1-4 第一季
        # 4.1-7 第二季
        # 7.1-10 第三季
        # 10.1-1 第四季
        new_table_name = sprintf SeasonTableName, time.year, (time.month + 2) / 3
        create_move_table_commands CurrentSeasonTableName, new_table_name
    end

    def create_add_day_to_week_commands
        create_add_table_commands CurrentDailyTableName, CurrentWeekTableName
    end

    def create_add_day_to_month_commands
        create_add_table_commands CurrentDailyTableName, CurrentMonthTableName
    end

    def create_add_day_to_season_commands
        create_add_table_commands CurrentDailyTableName, CurrentSeasonTableName
    end

    def create_add_month_to_season_commands
        create_add_table_commands CurrentMonthTableName, CurrentSeasonTableName
    end

    def create_add_table_commands(from_table_name, to_table_name)
        [
            sprintf(CheckAddTableCommand, to_table_name, from_table_name),
            sprintf(AddTableCommand, to_table_name, from_table_name)
        ]
    end

    def create_move_table_commands(old_table_name, new_table_name)
        [
            sprintf(RemoveTableCommand, new_table_name),
            sprintf(MoveTableCommand, old_table_name, new_table_name),
            sprintf(CreateTableCommand, old_table_name)
        ]
    end

    def create_card_command(table_name, cardID, stats)
        [
            sprintf(CreateCardCommand, table_name, cardID),
            sprintf(UpdateCardCommand, table_name, stats[0], stats[1], stats[2], stats[3], stats[4], cardID)
        ]
    end

    def create_result_command(table_name)
        num = $config["SingleCardAnalyzer"]["TopNumbers"]
        "select * from #{table_name} order by frequency desc, numbers desc limit #{num}"
    end
    
    def execute_deck_command(table_name, deck)
        stats = create_deck_stats deck
        for cardID in stats.keys do
            execute_commands create_card_command(table_name, cardID, stats[cardID])
        end
    end

end

require "#{File.dirname __FILE__}/Analyzer.rb"
Analyzer.push SQLSingleCardAnalyzer.new