

var pollutantImageURL = "/img/skull.png";
var playerIconSize = new google.maps.Size(32, 32);
var playerIconOrigin = new google.maps.Point(0,0);
var playerIconAnchor = new google.maps.Point(16, 32);	

var setup = false;
//duplication in game-common
/*var GameMap = {
	fitToRadius: function(radius) {
	  var center = map.getCenter();
	  var topMiddle = google.maps.geometry.spherical.computeOffset(center, radius, 0);
	  var bottomMiddle = google.maps.geometry.spherical.computeOffset(center, radius, 180);
	  var bounds = new google.maps.LatLngBounds();
	  bounds.extend(topMiddle);
	  bounds.extend(bottomMiddle);
	  map.fitBounds(bounds);
	}
}*/

var lastRequestTime = 0;

var cg = {
	s: function(w,h) {
		return new google.maps.Size(w,h);
	},
	p: function(w,h) {
		return new google.maps.Point(w,h);
	},
	playerImage: function(name, team) {
//		if(typeof name == "undefined") name = "AA";
//		if(typeof team == "undefined") team = "red";
		return new google.maps.MarkerImage("/player/"+name[0]+"/"+name[1]+"/"+team+"/map_icon.png", new google.maps.Size(38, 31), new google.maps.Point(0,0), new google.maps.Point(10, 30));
	}
}



var playerIconSize = new google.maps.Size(32, 32);
var playerIconOrigin = new google.maps.Point(0,0);
var playerIconAnchor = new google.maps.Point(16, 32);
var playerIcons = {
	blue: new google.maps.MarkerImage("http://www.google.com/intl/en_us/mapfiles/ms/icons/blue-dot.png", playerIconSize, playerIconOrigin, playerIconAnchor),
	red: new google.maps.MarkerImage("http://www.google.com/intl/en_us/mapfiles/ms/icons/red-dot.png", playerIconSize, playerIconOrigin, playerIconAnchor)
}

var taskIcon = playerIcons['blue']; 
var personSkillA = playerIcons['red'];



var players = [];
var boxes = [];
var tasks = [];

var lastGeigerPlayTime = 0;




var truckMarker;


var people = [];
var player_profiles = [];
// player icon: '/player/' + player.geoloqi_id + "/" + player.team + '/map_icon.png'


//////heatmap drawing//////
var backGroundRec;
var heat_map=[];


function receiveHeatmapData(data){
    //$(data.player).each(function(i,id)
    //var
    if (backGroundRec == null){
        var bound=new google.maps.LatLngBounds(
                                           new google.maps.LatLng(data[0][data[0].length-1].lat,data[0][data[0].length-1].lng),
                                           new google.maps.LatLng(data[data.length-1][0].lat,data[data.length-1][0].lng)
                                           
                                           );
    
        var options= {
            strokeColor: "#FF0000",
            strokeOpacity: 0.8,
            strokeWeight: 3,
            clickable: false,
            fillColor: "#FF0000",
            fillOpacity: 0,
            map: map,
            bounds:bound
        
        }
        backGroundRec=new google.maps.Rectangle();
        backGroundRec.setOptions(options);
    }
    
    $(heat_map).each(function(i,cell){
        cell.setMap(null);
        delete cell;
    });
    heat_map=[];
    
    var y=0;
    var x=0;
    for (y=0; y<data.length; y++){
        for (x=0; x<data[y].length; x++){
            
            var test=data[y][x];
            if (data[y][x].value>5.0){
                var point=new google.maps.LatLng(data[y][x].lat, data[y][x].lng);
                heat_map.push(new google.maps.Circle(pick_overlay( data[y][x].value, point)));
            }
        }
    }
    
}

function pick_overlay(reading_value, point){

    if (reading_value==100.0) {
        reading_value=99.9;
    } 
        
    var heat_map_colors = ["#202020","#3B3B3B","#3B3D64","#3F3CAD","#4B85F3","#3CBDC3","#56D355","#FFFB3D","#FF9F48","#FD3B3B"];
    
    var temp=heat_map_colors[Math.floor(reading_value/10)];

    var circleOptions = {
        		strokeColor: heat_map_colors[Math.floor(reading_value/10)],
        		strokeOpacity: 0.8,
        		strokeWeight: 0,
        		fillColor: heat_map_colors[Math.floor(reading_value/10)],
        		fillOpacity: 0.35,
        		map: map,
        		center: point,
                clickable:false,
        		radius: 5//0.5*5.71
        };
    return circleOptions;

}

var log="";
function saveLog(data){
    log=log+JSON.stringify(data)+"\n";
    
}

function receiveRequestData(data) {
    
    
	markerIcon = coins[10].grey;
	if(typeof requests[data.id] == "undefined") {
		requests[data.id] = {
			id: data.id,
            radius: data.radius,
			marker: new google.maps.Marker({
				position: new google.maps.LatLng(data.latitude, data.longitude),
				map: map,
				icon: markerIcon
			})
		};
	} else {
		// Coin is already on the screen, decide whether we should update it
		var p = requests[data.id];
		if(true) {
			p.marker.setMap(null);
			p.marker = new google.maps.Marker({
				position: new google.maps.LatLng(data.latitude, data.longitude),
				map: map,
				icon: markerIcon
			});
		} else {
			console.debug("coin already claimed");
		}
	}
}


/*
function receiveRadiationBit(bit){

	var pollutantIcon= new google.maps.MarkerImage(pollutantImageURL, playerIconSize, playerIconOrigin, playerIconAnchor);                    
    var point = new google.maps.LatLng(bit.latitude,bit.longitude);
                
    	var marker = new google.maps.Marker({
                position: point,
                map: map,
                icon: pollutantIcon
        });
        
        var circleOptions = {
        		strokeColor: "#FFFFB3",
        		strokeOpacity: 0.8,
        		strokeWeight: 2,
        		fillColor: "#FFFFb3",
        		fillOpacity: 0.35,
        		map: map,
        		center: point,
                clickable:false,
        		radius: 120
        };
        new google.maps.Circle(circleOptions);
            	
        var circleOptions = {
        		strokeColor: "#00FF00",
        		strokeOpacity: 0.8,
        		strokeWeight: 2,
        		fillColor: "#00FF00",
        		fillOpacity: 0.35,
        		map: map,
        		center: point,
                clickable:false,
        		radius: 60
        };
        new google.maps.Circle(circleOptions);
                
        var circleOptions = {
        		strokeColor: "#FF0000",
        		strokeOpacity: 0.8,
        		strokeWeight: 2,
        		fillColor: "#FF0000",
        		fillOpacity: 0.35,
        		map: map,
        		center: point,
                clickable:false,
        		radius: 50
        };
        new google.maps.Circle(circleOptions);
             	
        //radiationBits.push(point);     

}*/





function errorCheck(data){
    if (typeof data.error != 'undefined'){
        alert(data.error);
    }
}

function receiveTextMassage(data){
    alert(data.content);
}





function receiveExposureData(data){
    document.getElementById("exposure_"+data.player_id).innerHTML=data.value;
    
    var level = document.getElementById("level_"+data.player_id);
    if (data.value <= 50) {
    	level.innerHTML = "Low"; 
    }
    else if (data.value > 50 && data.level <=100)   {
    	level.innerHTML = "Increased"; 
    }
    else if (data.value > 100 && data.level <=150)   {
    	level.innerHTML = "Critical"; 
    }
    else if (data.value > 150)   {
    	level.innerHTML = "Extreme"; 
    }
}

////legacy but probably useful
function filter(data){

    if($("#user_team").val()=="truck"){
        if(typeof data.request != "undefined"){
            delete data.request
        }
         if(typeof data.reading != "undefined"){
            delete data.reading
        }
        
    }
    
    if($("#user_team").val()=="runner"){
         if(typeof data.location != "undefined"){
            if(players[data.location.player_id].team == "truck"){
                delete data.location
            }
        }
    }
    
    if($("#user_team").val()=="controller"){
         if(typeof data.location != "undefined"){
            if(players[data.location.player_id].team == "truck"){
                delete data.location
            }
        }
    }
    
    if($("#user_team").val()=="controller"){                
        delete data.radiation
    }
    
    
    return data

}

function system(data){
    
    if (data=="start"){
        location.reload();
    }
    //legacy for iOS, this part will try to communicate with iphone native code
    else if(data=="end"){
        var results = "";
        
        $(players).each(function(i, player){
            if(typeof player != "undefined"){
                results=results+ player.name+ ":" + player.points_cache + "\n";
            }
        });
        alert(log);
        //push it back to server
         $.ajax({ 
            url: NODE_JS_ADDRESS+"/push_log",
            type: "POST",
            data: JSON.stringify({player_id:$("#user_id").val(),game_id:$("#layer_id").val(),data:log}),
            dataType:"json",
            success: function(data) {
                           
            }
        });    
        alert("Game ended\n Results: \n"+results);
        
        
        location.reload();
    }
    else if(data=="reset"){
        location.reload();
    }
    else if(data=="ready_check"){
        var ready=confirm("Ready check");
         $.ajax({ 
            url: "/player/ready_check",
            type: "GET",
            data: {"ready":ready, "id": $("#user_id").val()},
            dataType:"json",
            success: function(data) {
                           
            }
        });    
    }

}



function pushToTaskHistory(message, identifier) {
	//pushes the string message to the task list (including the date time added)
	//(called when new tasks and messages are received)
		
	var line = $("<li id='" + identifier + "'>" + message + "</li>"); //TODO: add date, intended recipients
	var taskList = $('#task_list');
	taskList.append(line);
	taskList.listview( "refresh" );  
}

// Load the initial game state and place the pins on the map. Sample data in pellets.json
// This function polls the game server for data.
function updateGame(oneTime) {
	$.ajax({ 
		url: "/game/"+$("#layer_id").val()+"/status.json",
		type: "GET",
		data: {after: lastRequestTime},
		dataType: "json", 
		success: function(data) {
			$("#num-players").html(data.player.length + " Players");
			
            $(data.task).each(function(i, task){
                var d=filter({"task":task});
                if(typeof d.task != "undefined"){
                    receiveTaskData(d.task);
                }
            });
                        
            $(data.location).each(function(i, location){
                var d=filter({"location":location});
                if(typeof d.location != "undefined"){
                    receivePlayerData(d.location);
                }
            });
            
		
            
            
            
			lastRequestTime = Math.round((new Date()).getTime() / 1000);
			if(!oneTime)
				setTimeout(updateGame, 5000);
			else
				setup = false;
		}
	});
}
