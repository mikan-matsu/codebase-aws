  require 'sinatra'
  require 'sinatra/reloader'
  require 'sinatra/cookies'
  require 'pg'
  
  set :bind, '0.0.0.0'
  
  conn = PG.connect(
    host: 'localhost',
    dbname: 'board',
    user: 'akimatsu',
    password: '19890211'
  )
  
  enable :sessions
  
  client = PG.connect(
    host: "localhost",
    dbname: "board",
    user: "akimatsu",
    password: "19890211"
  )



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

get '/' do
  erb :signup
end

get '/signup' do
  erb :signup
end

post '/signup' do
  name = params[:name]
  email = params[:email]
  password = params[:password]

  # 既に同じメールアドレスが存在するか確認
  existing_user = client.exec_params(
    "SELECT * FROM users WHERE email = $1 LIMIT 1",
    [email]
  ).to_a.first

  if existing_user
    # ユーザーが既に存在する場合の処理
    return erb :signup, locals: { message: "そのメールアドレスはすでに使用されています。別のメールアドレスを試してください。" }
  end

  # ユーザーが存在しない場合はデータベースに挿入
  client.exec_params(
    "INSERT INTO users (name, email, password) VALUES ($1, $2, $3)",
    [name, email, password]
  )

  redirect '/login'
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

    @boards = client.exec_params(
    "SELECT boards.*, users.name AS user_name FROM boards JOIN users ON boards.user_id = users.id"
  ).to_a

    erb :index
end

get '/boards/new' do
    erb :new_boards
end

post '/boards' do
    name = params[:name]
    user_id = session[:user]['id']
  
     # 既に同じ名前のボードが存在するか確認
    existing_board = client.exec_params(
      "SELECT * FROM boards WHERE name = $1 LIMIT 1",
      [name]
    ).to_a.first

    if existing_board
      # ボードが既に存在する場合、エラーメッセージを表示
      return erb :new_boards, locals: { error_message: "その名前のボードは既に存在します。別の名前を試してください。" }
    end

    # ボードが存在しない場合、新規作成
    client.exec_params(
      "INSERT INTO boards (name, user_id) VALUES ($1, $2)",
      [name, user_id]
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
    "SELECT *, created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo' AS local_created_at FROM posts WHERE board_id = $1 ORDER BY created_at DESC",
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

# 投稿の削除処理
delete '/boards/:board_id/posts/:post_id' do
  board_id = params[:board_id]
  post_id = params[:post_id]

  # 投稿が存在するか確認
  existing_post = client.exec_params(
    "SELECT * FROM posts WHERE id = $1 AND board_id = $2 LIMIT 1",
    [post_id, board_id]
  ).to_a.first

  if existing_post
    # 投稿が存在する場合、削除
    client.exec_params(
      "DELETE FROM posts WHERE id = $1 AND board_id = $2",
      [post_id, board_id]
    )
  end

  redirect "/boards/#{board_id}"
end

# 投稿の削除処理
delete '/boards/:id' do
  board_id = params[:id]
  user_id = params[:user_id] # フォームから送信されたユーザーIDを取得

  # ユーザーがボードを作成したユーザーか確認
  existing_board = client.exec_params(
    "SELECT * FROM boards WHERE id = $1 AND user_id = $2 LIMIT 1",
    [board_id, user_id]
  ).to_a.first

  if existing_board
    # ボードが存在する場合、削除
    client.exec_params(
      "DELETE FROM boards WHERE id = $1",
      [board_id]
    )
  end

  redirect "/boards"
end