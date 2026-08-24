 var ChangeVideoModel = function(){

	if(cusvideoRoute != "")
	{
		myvideo.src = cusvideoRoute;
		myvideo.play();
	}
	else
	{
		myvideo.src = videoRoute;
		myvideo.play();
	}
};

var ChangeAudioModel = function(){

	if(cusaudioRoute != ""){
		myAudio.src = cusaudioRoute;
		myAudio.play();
	}else{
		myAudio.src = audioRoute;
		myAudio.play();
	}
	
};
