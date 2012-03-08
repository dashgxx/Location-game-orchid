//modified:

var socket;

$(document).ready(function() {
	updateGame(true);
    
    socket = io.connect(SOCKET_IO_ADDRESS, {
            transports: ['websocket', 'flashsocket', 'htmlfile']
    });
    
    socket.on('game', function(data) {
        //debug
        //alert("join " + $("#group_token").val());
		socket.emit('game-join', $("#group_token").val());
	});
    
	socket.on('data', function(data) {
        data=filter(data);
        saveLog(data);
        
        
        if(typeof data.system != "undefined"){
            system(data.system);
        }
              
        if(typeof data.heatmap != "undefined"){
              receiveHeatmapData(data.heatmap);
        }
        
        if(typeof data.player != "undefined"){
            receivePlayerData(data.player);
        }
        
        if(typeof data.textMassage != "undefined"){
            receiveTextMassage(data.textMassage);
        }
        
        if(typeof data.location != "undefined"){
            receiveLocationData(data.location);
        }
        
        if(typeof data.request != "undefined"){
            receiveRequestData(data.request);
        }
        
        if(typeof data.reading != "undefined"){
                receiveReadingData(data.reading);
        }
            
        if(typeof data.cargo != "undefined"){
                receiveCargoData(data.cargo);
        }
        
        if(typeof data.cleanup != "undefined"){
                cleanup(data.cleanup);
        }
        
        if(typeof data.radiation != "undefined"){
                receiveRadiationBit(data.radiation);
        }
			
		       
        
	});

});


function joinGame(team) {
    $.ajax({ 
		url: "/game/"+$("#layer_id").val()+"/webjoin",
		type: "GET",
		data: {"team": team},
		dataType: "json", 
		success: function(data) {
            if (typeof data.error != 'undefined'){
                alert(data.error);
            }
            else{
                location.reload();
            }
                   
        }
        
    });
}

////////////////player actions//////////////////

function sendRequest(event){
    $.ajax({ 
		url: "/game/"+$("#layer_id").val()+"/request",
		type: "GET",
		data: {"latitude": event.latLng.lat(), "longitude":event.latLng.lng()},
		dataType: "json", 
		success: function(data) {
            alert("request made");
            //receiveCoinData(data);
        }
    });
}

function dropCargo(){
	$.ajax({ 
		url: "/game/"+$("#layer_id").val()+"/dropCargo",
		type: "POST",
		data: {"latitude":truckMarker.position.lat(),"longitude":truckMarker.position.lng() },
		dataType: "json", 
		success: function(data) {
           //alert("request made");
        }
    });
}


/////////////////////////////
//this is a for animated movement of truck
//

var previousMoveId=0;
var count=0;
var lngPerStep;
var latPerStep;
var steps;
var radiation;
//seems to be invoked twice
function moveTruck(event){
    var speed = 3; //10 m/s
    var distance = google.maps.geometry.spherical.computeDistanceBetween(event.latLng, truckMarker.position);
    //alert(distance);
    steps = (distance*10)/speed;//10 times more smooth
    lngPerStep = (event.latLng.lng()-truckMarker.position.lng())/steps;
    latPerStep = (event.latLng.lat()-truckMarker.position.lat())/steps;
    count=0;
    
    
    clearInterval(previousMoveId);
    previousMoveId = setInterval("moveOneStep()",100);
    

}

function moveOneStep() {
        if(count<steps){
            var p=new google.maps.LatLng(truckMarker.position.lat()+latPerStep,truckMarker.position.lng()+lngPerStep);
            truckMarker.setPosition(p);
            radiation.setCenter(p)
            count++;
        
        }
        else{
            clearInterval(previousMoveId);
        }
}

function system(data){
    
    if (data=="start"){
        location.reload();
    }
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

//////////////////////////////////
//
//game server request
//
//
function getTruck(){
    index=-1;
    $(players).each(function(i, p){
        if(typeof p != "undefined"){
            if(p.team == "truck"){
                return index=i;
            }
        }
    });
    if (index >= 0) { return players[index]; }
}

function updateTruckLocation(){
    var truck= getTruck();
    socket.emit('location-push',{ player_id:truck.id,latitude:truckMarker.position.lat(),longitude:truckMarker.position.lng()});
}