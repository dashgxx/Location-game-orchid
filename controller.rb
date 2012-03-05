class Controller < Sinatra::Base
    
  get '/games/list' do
    games=[]
    Game.all.each do |g|
        games << {"layer_id"=> g.layer_id , "name"=> g.name, "description"=> "", "is_active"=>g.is_active}

    end
    
    {"games"=> games}.to_json
  end 

    
  post '/game/:layer_id/dropCargo' do
    game=Game.first :layer_id=>params[:layer_id]
    if game.is_active<0
          return {:error=>"game not active"}.to_json
    end 

    @truck= get_truck params[:layer_id]
    if @truck.points_cache<0
        return {status: "no points available"}
    end

    #-modification send to socket io

    
    cargo=@truck.cargos.create :latitude=>params[:latitude], :longitude=>params[:longitude], :radius=>100, :exposed=>false
    

    #notifications to all users
    @truck.add_points -10
   
    socketIO.broadcast( 
      { 
        :channel=> params[:layer_id],             
        :data=>{
            :cargo=>{
                :id => cargo.id,
                :longitude => cargo.longitude.to_s('F'),
                :latitude => cargo.latitude.to_s('F'),
                :player_id => cargo.player_id,
                :radius => cargo.radius,
                :exposed => cargo.exposed
            }
        }
    }.to_json)

    #updatescore
    socketIO.broadcast( 
        { 
            :channel=> params[:layer_id],             
            :data=>{
                       :player=>{
                            :id=> @truck.id,
                            :name=> @truck.name,
                            :points_cache => @truck.points_cache,
                            :team => @truck.team.name
                       }
                   }
        }.to_json)
        

   return {status: "ok"}

  end     
  
 
    
  #update truck locaiton save to database #para latitude longitude.  
       #post '/game/:layer_id/moveTruck' 

  get '/game/:layer_id/logout' do
    
    #delete user from database
    game=Game.first :layer_id=>params[:layer_id]
    player=game.players.first :id => params[:user_id]
      
        
   
     
    socketIO.broadcast( 
                         { 
                            :channel=> params[:layer_id],             
                            :data=>{
                                :textMassage=>{:content=>"#{player.name} quitted game"},
                                :player=>{:id=>player.id,:action=>"cleanup"}
                            }
                         }.to_json)
    player.destroy
    session.clear
    redirect "/game/#{params[:layer_id]}/"
   
      
  end



  #post handler is for mobile device
  post '/game/:layer_id/logout' do
    
    #delete user from database
    game=Game.first :layer_id=>params[:layer_id]
    player=game.players.first :id => params[:id]
    
   
    
    socketIO.broadcast( 
                       { 
                       :channel=> params[:layer_id],             
                         :data=>{
                            :cleanup=>{
                                :player=>[player.id]
                            }
                         }
                       }.to_json)
    player.destroy
    session.clear
    
   
    {:status=> "ok"}.to_json
              
    
  end


  get '/game/:layer_id/webjoin' do
    content_type :json
    id=session[:id]
      
    game = Game.first :layer_id => params[:layer_id]
    team = params[:team]  
    puts game.is_active
    if game.is_active>=0
          
          return {:error=>"game has already began"}.to_json
    end 
    
    
    if team=="admin" 
        return {:error => "Not implemented yet"}.to_json 
    elsif id
        game.players.each do |existing_player|
            if existing_player.id == id
                return {:error => "Already in a team"}.to_json 
            end
        end
    end
    
    #ensure only one user is joined for each team
    team_game=game.teams.first :name=>team
    current_player=game.players.first :team_id=>team_game.id
    
   
    if  current_player
       return {:error => "only one player allowed in that team"}.to_json 
    else
        #create a player
        if team=="controller" 
            player = game.players.create  :email =>params[:emails], :name => team.upcase, :team => game.pick_team(team)
        elsif team=="truck"
            player = game.players.create  :email =>params[:emails], :name => team.upcase, :team => game.pick_team(team), :latitude=>game.latitude , :longitude=>game.longitude
        end
        player.points_cache=1000
        player.save
       
        session[:id]=player.id
        
        socketIO.broadcast( 
                           { 
                            :channel=> params[:layer_id],             
                            :data=>{
                                    :textMassage=>{:content=>"#{player.name} join the game"},
                                    :player=>{
                                        :id=> player.id,
                                        :name=> player.name,
                                        :points_cache => player.points_cache,
                                        :team => player.team.name
                                }
                            }
                           }.to_json)
        return {:status=> "ok"}.to_json
       
    end
    
    
end
  
                    
  
                


  post '/game/:layer_id/investigate' do
      latitude=params[:latitude]
      longitude=params[:longitude]
      user_id=params[:id]
      
      game = Game.first :layer_id => params[:layer_id]
      if game.is_active<0
          return {:error=>"game not active"}.to_json
      end 
      
      
      player = game.players.first :id=> user_id
      @truck=get_truck params[:layer_id]
      
      
      if !player 
           puts "player do not exist"
          
          {:error=>:error}.to_json
      else
         
          location = Geokit::LatLng.new latitude, longitude
          threshold = 10
          finding=false
          @truck.cargos.each do |cargo|
              if !cargo.exposed
                  cargoLocation=Geokit::LatLng.new cargo.latitude, cargo.longitude
                  temp_distance=location.distance_to cargoLocation, {:units=>:kms}
              
                 
              
                  if (temp_distance*1000)<threshold
                      puts "cargo exposed and cleared"
                      player.points_cache += 20
                      cargo.update(:exposed=>true)
                      finding=true;
                 
                  
                      socketIO.broadcast( 
                                     { 
                                        :channel=> params[:layer_id],             
                                            :data=>{
                                                    :textMassage=>{:content=>"cargo exposed and cleared"},
                                                    :cargo=>{
                                                        :id => cargo.id,
                                                        :longitude => cargo.longitude.to_s('F'),
                                                        :latitude => cargo.latitude.to_s('F'),
                                                        :player_id => cargo.player_id,
                                                        :radius => cargo.radius,
                                                        :exposed => cargo.exposed
                                                    },
                                         #update score
                                                    :player=>{
                                                        :id=> player.id,
                                                        :name=> player.name,
                                                        :points_cache => player.points_cache,
                                                        :team => player.team.name
                                                    }
                                        }
                                     }.to_json)
                   end
              end
          end
          
          truckLocation= Geokit::LatLng.new @truck.latitude, @truck.longitude
          temp_distance=location.distance_to truckLocation, {:units=>:kms}
            
          if (temp_distance*1000)<threshold
              puts "truck exposed"
              player.points_cache += 100
              finding=true;
              socketIO.broadcast( 
                                 { 
                                    :channel=> params[:layer_id],             
                                    :data=>{
                                        :textMassage=>{:content=>"truck captured"},
                                    }
                                 }.to_json)
              endGame(game)

          end
          player.save
          
          if !finding
              {:status=>"ok"}
          end
         
      end
  end 
      

post '/game/:layer_id/getReading' do
    latitude=params[:latitude]
    longitude=params[:longitude]
    user_id=params[:id]
    
    game = Game.first :layer_id => params[:layer_id]
    
    if game.is_active<0
        return {:error=>"game not active"}.to_json
    end 
    
    player = game.players.first :id=> user_id
	location= Geokit::LatLng.new(latitude, longitude)
	distance=-1;
	game.radiations.each do |r|
            
                rLocation=Geokit::LatLng.new r.latitude, r.longitude
                temp_distance=location.distance_to rLocation, {:units=>:kms}
				if distance<0
					distance=temp_distance
                elsif temp_distance<distance
                    distance=temp_distance
                end
                
                puts temp_distance*1000
	end
	distance=distance*1000
	reading=0
	if distance> 120 #120 
		reading=0
	else
		reading=(120-distance)/120 * 100	
	end
	
	
	currentReading=player.readings.create :latitude=>latitude, :longitude=>longitude, :value=>reading
	
	socketIO.broadcast( 
                           { 
                           :channel=> params[:layer_id],             
                           :data=>{
                           
                           :reading=>{
                           :id => currentReading.id,
                           :longitude => currentReading.longitude.to_s('F'),
                           :latitude => currentReading.latitude.to_s('F'),
                           :player_id => currentReading.player_id,
                           :value => currentReading.value
                           }
                           }
                           }.to_json)

    
	
               
	{:distance=>distance, :reading=>reading}.to_json
end

      
  

  get '/game/:layer_id/request' do
      content_type :json
      controller=get_controller params[:layer_id]
      if controller.points_cache<0
          return {status: "no points available"}
      end
          
          
      game = Game.first :layer_id => params[:layer_id]
      if game.is_active<0
          return {:error=>"game not active"}.to_json
      end 
      
      
      #-modify create request here
      request=controller.requests.create :value=>10, :latitude=>params[:latitude], :longitude=>params[:longitude], :radius=>10          
      
      controller.add_points  -10
      #-modify broadcast to socket io 
     
      socketIO.broadcast( 
                         { 
                            :channel=> params[:layer_id],             
                            :data=>{
                                :request=>{
                                    :id => request.id,
                                    :longitude => request.longitude.to_s('F'),
                                    :latitude => request.latitude.to_s('F'),
                                    :player_id => request.player_id,
                                    :radius => request.radius,
                                    :value => request.value
                                }
                            }
                         }.to_json)
      
      #updatescore
      socketIO.broadcast( 
                         { 
                            :channel=> params[:layer_id],             
                                :data=>{
                                    :player=>{
                                        :id=> controller.id,
                                        :name=> controller.name,
                                        :points_cache => controller.points_cache,
                                        :team => controller.team.name
                                    }
                                }
                         }.to_json)

 
      
      {status:"ok"}
      
      
  end
    
  
  #for development 
  get '/migrate' do
        DataMapper.auto_migrate!
  end 
  
  def default_headers
     headers = {'Content-Type' => 'application/json', 'User-Agent' => "ruby", 'Accept' => 'application/json'}
     headers
  end

  get '/test' do
     
  end 


  before do
  	@current_page = request.path[/(\w|-)+/]
    response.headers['Access-Control-Allow-Origin'] = '*'
      #if request.path =~ /^\/admin\//
      #require_login
      #geoloqi.get_auth(params[:code], request.url) if params[:code] && !geoloqi.access_token?
      #admins_only
      #end
  end

  after do
      #session[:geoloqi_auth] = geoloqi.auth
  end

  get '/?' do
    erb :'splash', :layout => false
  end

  get '/admin/games' do
    @games = Game.all
    erb :'admin/games/index', :layout => :'admin/layout'
  end

  get '/admin/games/new' do
    @game = Game.new
    erb :'admin/games/new', :layout => :'admin/layout'
  end

  get '/admin/games/:id/mapeditor' do
    @game = Game.get params[:id]
    erb :'admin/games/mapeditor', :layout => false
  end

  post '/admin/games' do
    game = Game.new params[:game]
    game.save
    redirect "/admin/games/#{game.layer_id}/mapeditor"
  end


  get '/admin/games/:layer_id/setup.json' do
    content_type :json
    @game = Game.get params[:layer_id]
    boxes =[]
	radiation = []
	@game.radiations.each do |p|
		radiation<<{
			:id=>p.id,
			:lat=>p.latitude.to_s('F'),
			:lng=>p.longitude.to_s('F'),
			:radius=>p.radius.to_s()
		}
	end
    @game.boundings.each do |p|
        boxes<<{
            :id=>p.id,
            :neLatitude => p.neLatitude.to_s('F'),
            :neLongitude => p.neLongitude.to_s('F'),
            :swLatitude => p.swLatitude.to_s('F'),
            :swLongitude => p.swLongitude.to_s('F')
        }
    end
      
    {:boundingBoxes=>boxes,:radiationBits=>radiation}.to_json
      
  end
  
  put '/admin/games/:layer_id/reset' do
    game = Game.get params[:layer_id]
      game.update(:is_active=>-1)
    #result = geoloqi_app.get 'place/list', :layer_id => game.layer_id, :limit => 0
      game.players.each do |p|
          p.destroy
      end 
      #clear log
      #I know I should not hard code file name here, but... 
      oldFile="logs/log-#{params[:layer_id]}"
      newFile="logs/log-#{params[:layer_id]}-#{Time.now.to_f}"
      if FileTest.exist?(oldFile)
          File.rename(oldFile,newFile)
      end
      
      socketIO.broadcast( 
                         { 
                         :channel=> params[:layer_id],             
                         :data=>{
                         :system=>"reset"
                         }
                         }.to_json)
    
    redirect '/admin/games'
  end


#be careful for the layer id 
  get '/admin/games/:layer_id/edit' do
    @game = Game.get params[:layer_id]
    erb :'admin/games/edit', :layout => :'admin/layout'
  end

  put '/admin/games/:layer_id/end_game' do
    @game = Game.get params[:layer_id]
    geoloqi_app.post "group/message/#{@game.group_token}", :mapattack => {:gamestate => 'done'}
    redirect '/admin/games'
  end

  put '/admin/games/:layer_id' do
    @game = Game.get params[:layer_id]
    @game.update params[:game]

    redirect '/admin/games'
  end

  get '/admin/games/:layer_id/console' do
      @game = Game.get params[:layer_id]
      erb :'/admin/games/console', :layout => :'admin/layout'
  end 

  post '/admin/games/:layer_id/massage' do
      @game = Game.get params[:layer_id]
      socketIO.broadcast( 
                         { 
                            :channel=> params[:layer_id],             
                            :data=>{
                            :textMassage=>{:content=>params[:content]},
                            }
                         }.to_json)
      {"status"=>:ok}.to_json

  end 

  get '/admin/games/:layer_id/ready_check' do
    @game = Game.get params[:layer_id]
    players=[]
    
    
    socketIO.broadcast( 
                          { 
                           :channel=> params[:layer_id],             
                           :data=>{
                           :system=>"ready_check"
                          }
                       }.to_json)

    @game.players.each{ |p|
        
        p.update(:status=>-1)
        players<<{
            :id=> p.id,
            :name=> p.name
        }
    }
      
      
    {"players"=>players}.to_json
    
  end 

  get '/get_log/:layer_id/' do
    counter = 1
    file = File.new("logs/log-#{params[:layer_id]}", "r")
    log=""
    while (line = file.gets)
        log= "#{log}#{line}"
        counter = counter + 1
    end
    
    file.close
      
    log
    
  end

  get '/admin/games/:layer_id/ready_status' do
    @game = Game.get params[:layer_id]
    players=[]
    
    @game.players.each{ |p|
        players<<{
            :id=> p.id,
            :name=> p.name,
            :status=> p.status
        }
    }
    
    
    {"players"=>players}.to_json
    
  end 

  get '/player/ready_check' do
      player = Player.get params[:id]
  
      
      
      if params[:ready] == "true"
          #puts :bbb
          player.update(:status=>1)
      elsif params[:ready] == "false"
          #puts :aaa
          player.update(:status=>0)
      end
       puts :ccc
  end

  delete '/admin/games/:layer_id' do
    @game = Game.get params[:layer_id]
   
    @game.destroy
    redirect '/admin/games'
  end

  get '/game/:layer_id/complete' do
    @game = Game.first :layer_id => params[:layer_id]
	@winner = (@game.points_for('red') > @game.points_for('blue') ? 'red' : 'blue')
    erb :'complete'
  end

  get '/admin/games/:layer_id/start' do
    game=Game.first :layer_id=>params[:layer_id]
    if game.is_active!= -1
        return {:error=>"game already begin"}.to_json
        else
        game.update(:is_active=>0)
        
        get_mainloops()[Integer(params[:layer_id])]=Thread.new {
            game_id=params[:layer_id]
            
            while(game.is_active==0) do
                game=Game.first :layer_id=>game_id
                puts "game #{game_id} active"
                update_game(game)
                sleep 1
                #update game
            end
        }
                #get_mainloops()[Integer(params[:layer_id])].join
        
        socketIO.broadcast( 
                           { 
                           :channel=> params[:layer_id],             
                           :data=>{
                           :system=>"start"
                           }
                           }.to_json)
        @games = Game.all
        erb :'admin/games/index', :layout => :'admin/layout'
    end
    
    
  end 

  get '/admin/games/:layer_id/end' do
    game=Game.first :layer_id=>params[:layer_id]
    if game.is_active<0
        return {:error=>"game not active"}.to_json
    else
        endGame(game)
        erb :'admin/games/index', :layout => :'admin/layout'
    end
  end

  

   # TODO: bbox

  post '/admin/games/:layer_id/addBoundingBox' do
     game=Game.first :layer_id=>params[:layer_id]
     game.boundings.create :swLatitude=> params[:swLatitude], :swLongitude=> params[:swLongitude], :neLatitude=> params[:neLatitude], :neLongitude=> params[:neLongitude]
     {:status=> "ok"}.to_json
  end 
  
  post '/admin/games/:layer_id/addRadiationBit' do
     game=Game.first :layer_id=>params[:layer_id]
     game.radiations.create :latitude=> params[:latitude], :longitude=> params[:longitude], :radius=>50
     {:status=> "ok"}.to_json
  end 

  get '/admin/games/:layer_id/clearBoundingBox' do
      game=Game.first :layer_id=>params[:layer_id]
      game.boundings.each do |box|
          box.destroy
      end 
      {:status=>"ok"}.to_json
  end 

  get '/admin/games/:layer_id/clearRadiationBit' do
      game=Game.first :layer_id=>params[:layer_id]
      game.radiations.each do |bit|
          bit.destroy
      end 
      {:status=>"ok"}.to_json
  end 

  post '/admin/games/:layer_id/validate_position' do
    game=Game.first :layer_id=>params[:layer_id]
    validate = false
    game.boundings.each do |bbox|
        neLocation = Geokit::LatLng.new bbox.neLatitude, bbox.neLongitude
        swLocation = Geokit::LatLng.new bbox.swLatitude, bbox.swLongitude
        location = Geokit::LatLng.new params[latitude], params[longitude]
        
        bounds=Bounds.new(swLocation,neLocation)
        bounds.contains?(location)
        validate = true
    end 
    {:result => validate}.to_json
  end 





  get '/player/:i1/:i2/:team/map_icon.png' do
    a = params[:i1].upcase
    b = params[:i2].upcase
        
    puts :fdsa
    file_path = File.join Controller.root, "public", "icons", "#{a}#{b}_#{params[:team]}.png"
    file_path_tmp = "#{file_path}tmp"
    marker_path = File.join Controller.root, "public", "img", "player-icon-" + params[:team] + ".png"
    
    if File.exist?(file_path)
        send_file file_path
        else
        file_path_1 = File.join Controller.root, "public", "characters", a+".png"
        file_path_2 = File.join Controller.root, "public", "characters", b+".png"
        
        `convert \\( #{marker_path} \\( -geometry +11+6 -compose Over \\( #{file_path_2} -resize 130% \\) \\) -composite \\) \\( -geometry +2+6 -compose Over \\( #{file_path_1} -resize 130% \\) \\) -composite #{file_path_tmp}`
        FileUtils.mv file_path_tmp, file_path
        send_file file_path
        
    end
 
  end



 #object templates in this fuction
 get '/game/:layer_id/status.json' do
    content_type 'application/json'
    game = Game.first :layer_id => params[:layer_id]
    
    requests = []
    locations = []
    cargos = []
    readings = []
    players = []
	radiations = []
    
    game.players.each do |player|
        players << {
            :id=> player.id,
            :name=> player.name,
            :points_cache => player.points_cache,
            :team => player.team.name
        }
        
        if player.latitude && player.longitude && player.longitude!="" && player.latitude != "" 
        locations << { 
            :player_id=> player.id,
            #get rid of scientic notation of numbers
            
            :latitude=> player.latitude.to_s('F'),
            :longitude=>player.longitude.to_s('F')
        }
        end
        
        player.cargos.each do |cargo| 
            cargos << {
                :id => cargo.id,
                :longitude => cargo.longitude.to_s('F'),
                :latitude => cargo.latitude.to_s('F'),
                :player_id => cargo.player_id,
                :radius => cargo.radius,
                :exposed => cargo.exposed
            }
        end 
        
        player.readings.each do |reading|
            readings << {
                :id => reading.id,
                :longitude => reading.longitude.to_s('F'),
                :latitude => reading.latitude.to_s('F'),
                :player_id => reading.player_id,
                :value => reading.value
            }
        end 
        
        
        player.requests.each do |request| 
            requests << {
                :id => request.id,
                :longitude => request.longitude.to_s('F'),
                :latitude => request.latitude.to_s('F'),
                :player_id => request.player_id,
                :radius => request.radius
            }
        end 
        
    end
	
	game.radiations.each do |bit|
		radiations << {
			:id => bit.id,
			:longitude => bit.longitude.to_s('F'),
			:latitude => bit.latitude.to_s('F'),
#			:radius => bit.radius.to_s()
		}
	end
    
    
    {:request => requests, :location => locations,:reading=>readings,:cargo=>cargos, :player=>players, :radiation=>radiations}.to_json
    
end
  # TODO: mobile game join 

  post '/game/:layer_id/join' do
    content_type :json
    game = Game.first :layer_id => params[:layer_id]
    
    if game.is_active>=0
          return {:error=>"game already begin"}.to_json
    end
      
    if params[:team]==nil
        player = game.players.create  :email =>params[:email], :name => params[:name], :team => game.pick_team('runner')
    else
        player = game.players.create  :email =>params[:email], :name => params[:name], :team => game.pick_team(params[:team])
    end
    
    if player
      
        #update player info, add game information.
        #player.update(:game_layer_id=>game.layer_id,:team => game.pick_team('runner'))
        #broadcast to socket.io
        #session[:id]=player.id
        
        socketIO.broadcast( 
                           { 
                            :channel=> params[:layer_id],             
                            :data=>{
                                    :textMassage=>{:content=>"#{player.name} join the game"},
                                    :player=>{
                                        :id=> player.id,
                                        :name=> player.name,
                                        :points_cache => player.points_cache,
                                        :team => player.team.name
                                    }
                            }
                           }.to_json)
    end
    {'team_name' => player.team.name, 'user_id' => player.id}.to_json
      
  end
    
  post '/create/player/runner' do
      player = Player.create :email => params[:email], :name => params[:name].upcase, :game_layer_id => 0, :team_id => 0
      #player.save
     
      {:player_id=>player.id}.to_json
    
  end


  get '/game/:layer_id/?' do
    @game = Game.first :layer_id => params[:layer_id]
      
      #if game ended, clear them
    if @game.is_active==1
        session.clear
        params[:id]=nil
    end
   
    player = Player.first :id => session[:id], :game => @game
    puts session[:id]
    if !player 
        #mobile users store id information in params 
        player = Player.first :id => params[:id], :game => @game
        puts "find player #{params[:id]}"
        
    end
    
    @user_id=""
    if player
        @user_id = player.id
        @user_team = player.team.name
    end
    
      
      @truck= get_truck params[:layer_id]
      if @truck
          @truck_latitude=@truck.latitude
          @truck_longitude=@truck.longitude
          
      else
          @truck_latitude=@game.latitude
          @truck_longitude=@game.longitude
      end

    @user_initials = player ? player.name : ''
    erb :'index'
  end



  get '/replay/:layer_id/?' do
    @game = Game.first :layer_id => params[:layer_id]
    @user_id = nil
    @user_team = 'replay'
    @user_initials = ''
    
    erb :'index'
  end

  def update_score(game)
      
      scores = {}
      game.players.each do |player|
          scores[player.id] = player.points_cache
      end
  end

  def get_truck(layer_id)
      game=Game.first :layer_id=>layer_id
      team = game.teams :name=>"truck"
      
      #only one truck player shoud be in the team 
      truck= team.players.first
      return truck
  end

  def get_controller(layer_id)
      game=Game.first :layer_id=>layer_id
      team = game.teams :name=>"controller"
      
      #only one truck player shoud be in the team 
      controller= team.players.first
      return controller 

  end 

  def endGame(game)
    game.update(:is_active=>1)
    socketIO.broadcast( 
                       { 
                       :channel=> params[:layer_id],             
                       :data=>{
                       :system=>"end"
                       }
                       }.to_json)
    @games = Game.all
    session.clear
  end 
            
  def get_mainloops()
        if !@mainloops
            @mainloops=[]
            
        end
        
        return @mainloops
  end
            
  def update_game(game)
        puts "game update"
         game.players.each do |p|
             p.broadcast(socketIO)#test
             game.radiations.each do |r|
                  if get_distance(p.latitude,p.longitude,r.latitude,r.longitude)<50 #dangerous radius
                      
                      #reduce player score
                      p.add_points -10
                      #p.broadcast(socketIO)
                      break
                  end 
             end 
             
         end 
  end
            
  def get_distance(lat1,lng1,lat2,lng2)
        location1 = Geokit::LatLng.new lat1, lng1
        location2 = Geokit::LatLng.new lat2, lng2
        distance = location1.distance_to location2
        return distance
  end

end

#-modification discarded function 
#post '/trigger'
#post '/admin/games/:layer_id/new_pellet.json' do
#post '/admin/games/:layer_id/move_pellet.json' do
#post '/admin/games/:layer_id/delete_pellet.json' do
#post '/admin/games/:layer_id/batch_create_pellets.json' do
#post '/admin/games/:layer_id/set_pellet_value.json' do
#post '/admin/games/:layer_id/set_pellet_text.json' do
#post '/contact_submit' do 
#get '/game/:layer_id/player/:geoloqi_user_id' do
#get '/authorize' do
#def require_login
#def geoloqi
