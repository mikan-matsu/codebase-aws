require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pg'

enable :sessions

client = PG::connect(
  :host => "localhost",
  :dbname => "board")

get '/posts' do
  if session[:user].nil?
    return redirect '/login'
  end

  @posts = client.exec_params("SELECT * from posts").to_a
  erb :posts
end

post '/posts' do
  name = params[:name]
  content = params[:content]

  client.exec_params(
    "INSERT INTO posts (name, content) VALUES ($1, $2)",
    [name, content]
  )

  redirect '/posts'
end

get '/signup' do
  erb :signup
end

post '/signup' do
  name = params[:name]
  email = params[:email]
  password = params[:password]

  client.exec_params(
    "INSERT INTO users (name, email, password) VALUES ($1, $2, $3)",
    [name, email, password]
  )

  redirect '/posts'
end

get '/login' do
  erb :login
end

post '/login' do
  email = params[:email]
  password = params[:password]

  user = client.exec_params(
    "SELECT * FROM users WHERE email = $1 AND password = $2 LIMIT 1",
    [email, password]
  ).to_a.first

  if user.nil?
    return erb :login
  end

  session[:user] = user
  redirect '/boards'
end

delete '/logout' do
  session[:user] = nil
  redirect '/login'
end

get '/boards' do
    if session[:user].nil?
        return redirect '/login'
    end

    @boards = client.exec_params(
        "SELECT * FROM boards"
    )

    erb :index
end

get '/boards/new' do
    erb :new_boards
end

post '/boards' do
    name = params[:name]
  
    client.exec_params(
      "INSERT INTO boards (name) VALUES ($1)",
      [name]
    )
  
    redirect "/boards"
end

get '/boards/:id' do
  board_id = params[:id]
  @board = client.exec_params(
    "SELECT * from boards WHERE id = $1 LIMIT 1",
    [board_id]
  ).to_a.first

  @posts = client.exec_params(
    "SELECT * from posts WHERE board_id = $1",
    [board_id]
  ).to_a

  erb :board
end

post '/boards/:id/posts' do
  board_id = params[:id]
  name = params[:name]
  content = params[:content]

  image_path = ''
  if !params[:img].nil?
    tempfile = params[:img][:tempfile] 
    save_to = "./public/images/#{params[:img][:filename]}"
    FileUtils.mv(tempfile, save_to)
    image_path = params[:img][:filename]
  end

  client.exec_params(
    "INSERT INTO posts (name, content, image_path, board_id) VALUES ($1, $2, $3, $4)",
    [name, content, image_path, board_id]
  )

  redirect "/boards/#{board_id}"
end