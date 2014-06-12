# encoding: utf-8

require 'oj'
require 'multi_json'

Script :dota_match, uses: %w{http}, includes: [Commands] do
  Author "Ole Bergmann <ole@ole.im>"
  Version "0.1"
  Description "Provides a method to lookup matches in Dota 2"

  # Script constants.

  # API Key - can be obtained at: http://steamcommunity.com/dev/apikey
  APIKey     = ""

  # Regular expression for matching steam id's
  SteamRe    = /STEAM_\d:(\d):(\d{4,})/

  # Reference: http://dev.dota2.com/showthread.php?t=58317
  BaseURI    = "https://api.steampowered.com/IDOTA2Match_570/"
  HistoryURI = "#{BaseURI}GetMatchHistory/V001/?key=#{APIKey}&matches_requested=1&account_id=%s"
  DetailsURI = "#{BaseURI}GetMatchDetails/V001/?key=#{APIKey}&match_id=%s"

  DotaBuffURI= "http://dotabuff.com/matches/%s"

  # Hero ID -> Name association
  # - found in "npc_heroes.txt"
  # - reference: https://raw.githubusercontent.com/dotabuff/d2vpk/master/dota_pak01/scripts/npc/npc_heroes.txt

  DotaHeroes = {
    1 => "Anti-Mage",
    2 => "Axe",
    3 => "Bane",
    4 => "Bloodseeker",
    5 => "Crystal Maiden",
    6 => "Drow Ranger",
    7 => "Earthshaker",
    8 => "Juggernaut",
    9 => "Mirana",
    11 => "Shadow Fiend",
    10 => "Morphling",
    12 => "Phantom Lancer",
    13 => "Puck",
    14 => "Pudge",
    15 => "Razor",
    16 => "Sand King",
    17 => "Storm Spirit",
    18 => "Sven",
    19 => "Tiny",
    20 => "Vengeful Spirit",
    21 => "Windranger",
    22 => "Zeus",
    23 => "Kunkka",
    25 => "Lina",
    31 => "Lich",
    26 => "Lion",
    27 => "Shadow Shaman",
    28 => "Slardar",
    29 => "Tidehunter",
    30 => "Witch Doctor",
    32 => "Riki",
    33 => "Enigma",
    34 => "Tinker",
    35 => "Sniper",
    36 => "Necrophos",
    37 => "Warlock",
    38 => "Beastmaster",
    39 => "Queen of Pain",
    40 => "Venomancer",
    41 => "Faceless Void",
    42 => "Wraith King",
    43 => "Death Prophet",
    44 => "Phantom Assassin",
    45 => "Pugna",
    46 => "Templar Assassin",
    47 => "Viper",
    48 => "Luna",
    49 => "Dragon Knight",
    50 => "Dazzle",
    51 => "Clockwerk",
    52 => "Leshrac",
    53 => "Natures Prophet",
    54 => "Lifestealer",
    55 => "Dark Seer",
    56 => "Clinkz",
    57 => "Omniknight",
    58 => "Enchantress",
    59 => "Huskar",
    60 => "Night Stalker",
    61 => "Broodmother",
    62 => "Bounty Hunter",
    63 => "Weaver",
    64 => "Jakiro",
    65 => "Batrider",
    66 => "Chen",
    67 => "Spectre",
    69 => "Doom",
    68 => "Ancient Apparition",
    70 => "Ursa",
    71 => "Spirit Breaker",
    72 => "Gyrocopter",
    73 => "Alchemist",
    74 => "Invoker",
    75 => "Silencer",
    76 => "Outworld Devourer",
    77 => "Lycan",
    78 => "Brewmaster",
    79 => "Shadow Demon",
    80 => "Lone Druid",
    81 => "Chaos Knight",
    82 => "Meepo",
    83 => "Treant Protector",
    84 => "Ogre Magi",
    85 => "Undying",
    86 => "Rubick",
    87 => "Disruptor",
    88 => "Nyx Assassin",
    89 => "Naga Siren",
    90 => "Keeper of the Light",
    91 => "Io",
    92 => "Visage",
    93 => "Slark",
    94 => "Medusa",
    95 => "Troll Warlord",
    96 => "Centaur Warrunner",
    97 => "Magnus",
    98 => "Timbersaw",
    99 => "Bristleback",
    100 => "Tusk",
    101 => "Skywrath Mage",
    102 => "Abaddon",
    103 => "Elder Titan",
    104 => "Legion Commander",
    106 => "Ember Spirit",
    107 => "Earth Spirit",
    108 => "Abyssal Underlord",
    109 => "Terrorblade",
    110 => "Phoenix",
    111 => "Oracle",
  }

  # Game mode relations, same as above
  # source: https://github.com/kronusme/dota2-api/blob/master/data/mods.json

  DotaGameModes = {
    0 => {:full => "None",            :short => "-"},
    1 => {:full => "All Pick",        :short => "AP"},
    2 => {:full => "Captain's Mode",  :short => "CM"},
    3 => {:full => "Random Draft",    :short => "RD"},
    4 => {:full => "Single Draft",    :short => "SD"},
    5 => {:full => "All Random",      :short => "AR"},
    7 => {:full => "Diretide",        :short => "DT"},
    8 => {:full => "Reverse Captain's Mode", :short => "RCM"},
    9 => {:full => "The Greeviling",  :short => "TG"},
    10 => {:full => "Tutorial" ,      :short => "Tut"},
    11 => {:full => "Mid Only",       :short => "Mid"},
    12 => {:full => "Least Played",   :short => "LP"},
    13 => {:full => "Limited Heroes", :short => "LH"},
    14 => {:full => "Compendium Matchmaking", :short => "CP"},
    15 => {:full => "Custom",         :short => "CS"},
    16 => {:full => "Captain's Draft",:short => "CD"},
    17 => {:full => "Balanced Draft", :short => "BD"},
    18 => {:full => "Ability Draft",  :short => "AD"},
  }

  # Lobby Type Relations, same as above
  # source: https://github.com/kronusme/dota2-api/blob/master/data/lobbies.json
  DotaLobbyTypes = {
    -1 => "Invalid",
    0 => "Public matchmaking",
    1 => "Practice",
    2 => "Tournament",
    3 => "Tutorial",
    4 => "Co-op with bots",
    5 => "Team match",
    6 => "Solo Queue",
    7 => "Ranked",
  }

  def loaded
    # Initialize the HTML entities decoder
    #@decoder = HTMLEntities.new
    cache[:users] ||= {}
  end

  command %w{dota dota2 d2} do |user, channel, args|
    unless args
      # do actual lookup here
      if exists? user.nick
        account_id = account user.nick

        lookup account_id do |result|

          if result
            channel.say format_match result
          else
            channel.say format "Error occured in lookup"
          end
        end
      else
        channel.say format "Unknown User:\x0F use .dota set <steam_id> to set your Steam ID"
      end

    else
      arguments = args.split

      case arguments.first
      when "set"
        if arguments.length < 2
          channel.say format "Usage:\x0F .dota set <steam id>"
        else
          steam_id = arguments[1]

          if valid? steam_id
            cache[:users][user.nick] = steam_to_account_id steam_id
            channel.say format "Your Steam ID has been set to \x02#{steam_id}\x02"
          else
            channel.say format "Invalid Steam ID, format should be: STEAM_0:X:XXXX}"
          end
        end
      when "me"
        if exists? user.nick

          account_id = account user.nick

          channel.say format "Your Account ID is set to \x02#{account_id}\x02"
        end
      else
        nick = arguments.first

        if exists? nick
          account_id = account nick

          lookup account_id do |result|

            if result
              channel.say format_match result
            else
              channel.say format "Error occured in lookup"
            end
          end
        else
          channel.say format "Unknown User:\x0F #{nick}"
        end
      end
    end
  end

  def user_rename channel, user, old_nick, new_nick
    rename old_nick, new_nick if exists? old_nick
  end

  def details account_id, match_id
    details_uri = DetailsURI % match_id

    context = http.get details_uri, format: :json

    context.success do
      begin
        match = context.response['result']

        unless match.has_key? 'error'

          player = match['players'].find {|x| x['account_id'] == account_id }

          response = {

            :id => match_id,

            :hero => DotaHeroes[player['hero_id']],

            :game_mode => DotaGameModes[match['game_mode']],
            :lobby_type => match['lobby_type'],

            :duration => match['duration'],
            :time => match['start_time'] + match['duration'],

            :level => player['level'],
            :gold => player['gold'],
            :xpm => player['xp_per_min'],
            :gpm => player['gold_per_min'],

            :kills => player['kills'],
            :deaths => player['deaths'],
            :assists => player['assists'],

            :last_hits => player['last_hits'],
            :denies => player['denies'],
            :damage => player['hero_damage'],
            :tower_damage => player['tower_damage'],
            :healing => player['hero_healing'],

            :radiant => player['player_slot'] < 5,

            # Todo: add "real" networth (item cost + current gold)
            # for now just leave it at gold_spent (buybacks count aswell)
            :networth => player['gold_spent'],
          }

          response[:team_name] = response[:radiant] ? 'Radiant' : 'Dire'
          response[:won] = response[:radiant] == match['radiant_win']

          yield response
        else
          yield nil
        end

      rescue Exception => e
        p "#{e.message} - #{e.class.to_s}"
        p e.backtrace

        yield nil
      end
    end

    context.error do
      yield nil
    end
  end
  
  def lookup account_id
    lookup_uri = HistoryURI % account_id

    context = http.get lookup_uri, format: :json

    context.success do
      begin
        result = context.response['result']

        unless result['status'] == 1
          yield nil
        else

          matches = result['matches']

          if matches.any?
            details account_id, matches.first['match_id'] do |result|
              yield result
            end
          else
            yield nil
          end
        end

      rescue Exception => e
        p "#{e.message} - #{e.class.to_s}"
        p e.backtrace

        yield nil
      end
    end

    context.error do
      yield nil
    end
  end

  def rename nick, new_nick
    cache[:users][new_nick] = cache[:users].delete(nick)
  end

  def exists? nick
    cache[:users].has_key? nick
  end

  def account nick
    cache[:users][nick]
  end

  def steam_to_account_id steam_id
    groups = SteamRe.match(steam_id)
    return unless groups

    groups[1].to_i + (groups[2].to_i * 2)
  end

  def valid? steam_id
    SteamRe.match(steam_id)
  end

  def human_duration total_seconds
    format = (total_seconds / (60 * 60)) == 0 ? "%M:%S" : "%H:%M:%S"

    Time.at(total_seconds).utc.strftime(format)
  end

  def format_match m
    status = m[:won] ? "\x0303Won\x0F" : "\x0304Lost\x0F"

    duration = human_duration m[:duration]

    details_uri = DotaBuffURI % m[:id]

    # ranked game mode
    game_mode = m[:lobby_type] == 7 ? "Ranked #{m[:game_mode][:short]}" : m[:game_mode][:full]

    format %{#{m[:hero]} (\x0F#{game_mode}\x0310) Status:\x0F #{status} \x0310Score:\x0F #{m[:kills]} / #{m[:deaths]} / #{m[:assists]} \x0310Damage:\x0F #{m[:damage]} \x0310GPM:\x0F #{m[:gpm]} \x0310XPM:\x0F #{m[:xpm]} \x0310LDH:\x0F #{m[:last_hits]} / #{m[:denies]} / #{m[:healing]} \x0310Level:\x0F #{m[:level]} \x0310Networth:\x0F #{m[:networth]} \x0310Duration:\x0F #{duration} \x0310URL:\x0F #{details_uri} }
  end
  
  def format message
    %{\x0310>\x0F \x02Dota2:\x02\x0310 #{message}}
  end
end