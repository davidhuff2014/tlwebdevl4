# encoding: UTF-8
require 'rubygems'
require 'sinatra'
# require 'sinatra/reloader'
# require 'pry'

set :sessions, true

BLACKJACK_AMT = 21
DEALER_MIN_HIT = 17

helpers do
  def calc_total(cards)
    arr = cards.map { |e| e[1] }

    total = 0
    arr.each do |value|
      if value == 'A'
        total += 11
      elsif value.to_i == 0
        total += 10
      else
        total += value.to_i
      end
    end

    arr.select { |e| e == 'A' }.count.times do
      total -= 10 if total > BLACKJACK_AMT
    end
    session[:total] = total
  end

  def card_image(card)
    suit =  case card[0]
            when 'H' then 'hearts'
            when 'D' then 'diamonds'
            when 'S' then 'spades'
            when 'C' then 'clubs'
    end

    value = card[1]
    if %w(J Q K A).include?(value)
      value = case card[1]
              when 'J' then 'jack'
              when 'Q' then 'queen'
              when 'K' then 'king'
              when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    @how_hit_or_stay_buttons = false
    session[:player_bankroll] += session[:bet_amount].to_i
    @winner = "<strong>#{session[:player_name]} has won!</strong> #{msg}"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_bankroll] -= session[:bet_amount].to_i
    @loser = "<strong>#{session[:player_name]} loses.</strong> #{msg}"
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @winner = "<strong>It's a tie!</strong> #{msg}"
  end

  def stay!(msg)
    @winner = "<strong>#{session[:player_name]} is staying!</strong> #{msg}"
  end

  def init_session_variables
    session[:player_bankroll] = 500
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    erb :bet
  else
    init_session_variables
    erb :new_player
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = 'Name is required'
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/game' do
  session[:turn] = session[:player_name]
  suits = %w(H D C S)
  values = %w(2 3 4 5 6 7 8 9 10 J Q K A)
  session[:deck] = suits.product(values).shuffle!

  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop

  # player_total = calc_total(session[:player_cards])
  player_total = BLACKJACK_AMT
  
  @success = "#{session[:player_name]} hit blackjack." if player_total == BLACKJACK_AMT

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop
  player_total = calc_total(session[:player_cards])
  if player_total == BLACKJACK_AMT
    winner!("#{session[:player_name]} hit blackjack.")
    redirect '/game/dealer'
  elsif player_total > BLACKJACK_AMT
    loser!("It looks like #{session[:player_name]} has busted at #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  player_total = calc_total(session[:player_cards])
  stay!("#{session[:player_name]} has chosen to stay at #{player_total}!")
  # @success = "#{session[:player_name]} has chosen to stay."
  # no longer caught with layout: false

  session[:turn] = 'dealer'
  @show_hit_or_stay_buttons = false

  dealer_total = calc_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMT
    loser!('Dealer hit blackjack.')
    @winner = nil
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/game/compare'
  else
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false

  player_total = calc_total(session[:player_cards])
  dealer_total = calc_total(session[:dealer_cards])

  if dealer_total > BLACKJACK_AMT
    winner!("#{session[:player_name]} stayed at #{player_total} and the dealer busted at #{dealer_total}.")
  elsif player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total} and the dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total} and the dealer stayed at #{dealer_total}.")

  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total} ")
  end

  erb :game, layout: false
end

get '/bet' do
  if session[:player_bankroll].to_i <= 0
    redirect '/game_over'
  else
    erb :bet
  end
end

post '/bet' do
  redirect '/game_over' if session[:player_bankroll].to_i <= 0

  if params[:bet_amount].to_i > session[:player_bankroll].to_i
    @error = 'You are trying to bet more money than you have'
    halt erb(:bet)
  elsif params[:bet_amount].to_i == 0 || params[:bet_amount] == '' # could use .nil here
    @error = 'You must bet something!'
    halt erb(:bet)
  else
    session[:bet_amount] = params[:bet_amount]
  end

  redirect '/game'
end

get '/game_over' do
  session[:player_bankroll].to_i == 0 ? session[:end_message] = 'You are out of money'  : ''
  session[:player_bankroll].to_i >= 0 ? session[:end_message] = 'Quitting so soon?'     : ''

  erb :game_over
end
