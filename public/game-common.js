function receivePlayerData(data) {
   
	    var markerIcon;
		var myLatLng = new google.maps.LatLng(data.latitude, data.longitude);
	    if(data.skill == 'A') {
	    	markerIcon = personSkillA;
	    }
	    if(data.skill == 'B') {
	    	markerIcon = personSkillA; //TODO: change to appropriate skill icon
	    }
	    if(data.skill == 'C') {
	    	markerIcon = personSkillA; //TODO: change to appropriate skill icon
	    }
	    if(data.skill == 'D') {
	    	markerIcon = personSkillA; //TODO: change to appropriate skill icon
	    }
	    	    
	    if(typeof players[data.id] == "undefined") {
	        
	        players[data.id] = {
	            id: data.id,
	            name: data.name,
	            marker: new google.maps.Marker({
	                position: new google.maps.LatLng(data.latitude, data.longitude),
	                map: map,
	                icon: markerIcon,
	                visible: true
	            })
	        };
	    } else {
	        //update 
	        var p = players[data.id];
	            p.marker.setPosition(new google.maps.LatLng(data.latitude, data.longitude));
	            p.marker.setIcon(markerIcon);
	    }	        
	
//        if(typeof players[data.id] == "undefined") {
//        
//            players[data.id] = {
//                id: data.id,
//                name: data.name,
//                team: data.team,
//                points_cache: data.points_cache
//            };
//        } else {
//            var p = players[data.id];
//            p.team = data.team;
//            p.points_cache = data.points_cache;
//        }
   
}



/**
TASK ICONS... 
*/
var playerIconSize = new google.maps.Size(32, 32);
var playerIconOrigin = new google.maps.Point(0,0);
var playerIconAnchor = new google.maps.Point(16, 32);

var taskIcon1 = "/img/task_icon1.png";
var taskIcon2 =  "/img/task_icon2.png";
var taskIcon3 =  "/img/task_icon3.png";
var taskIcon4 = "/img/task_icon4.png";

var chosen_task_type = 0;

function receiveTaskData(task){
        chosen_task_type = task.type;

		var taskIcon= getTaskIcon();
		point = new google.maps.LatLng(task.latitude,task.longitude);
                
    	var marker = new google.maps.Marker({
                	position: point,
                	map: map,
                	icon: taskIcon
        });
}


function getTaskIcon() {

	var imageURL = ""
	if (chosen_task_type == 1) {
		imageURL = taskIcon1; 
	}
	else if (chosen_task_type == 2) {
		imageURL = taskIcon2;
	}
	else if (chosen_task_type == 3) {
		imageURL = taskIcon3;
	}
	else if (chosen_task_type == 4) {
		imageURL = taskIcon4;
	}
	
    var icon = new google.maps.MarkerImage(imageURL, playerIconSize, playerIconOrigin, playerIconAnchor);
	
	return icon;
}

//var GameMap = {
//	fitToRadius: function(radius) {
//	  var center = map.getCenter();
//	  var topMiddle = google.maps.geometry.spherical.computeOffset(center, radius, 0);
//	  var bottomMiddle = google.maps.geometry.spherical.computeOffset(center, radius, 180);
//	  var bounds = new google.maps.LatLngBounds();
//	  bounds.extend(topMiddle);
//	  bounds.extend(bottomMiddle);
//	  map.fitBounds(bounds);
//	},
//
//	goToAddress: function(address) {
//		var geocoder = new google.maps.Geocoder();
//		geocoder.geocode({address: address, bounds: map.getBounds()}, function(response) {
//				if(response.length > 0) {
//					var place = response[0];
//					map.setCenter(place.geometry.location);
//				}
//			}
//		);
//	}
//}
