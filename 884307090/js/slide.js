/**
 * Created by xtong on 2017/5/6 0006.
 */

// 幻灯片实现代码

/** 更新播放列表 */
function updateFileList(currentFiles) {
    // 列入播放列表
    for (var i = 0; i < currentFiles.length; ++i) {
        if(myList.indexOf(currentFiles[i]) === -1){
            myList.push(currentFiles[i]);
        }
    }
}

/** 计算切换周期 **/
var calculate = function(t){
    var res = 1;
    switch (t){
        case 1:
            // 1min
            res = 60;
            break;
        case 2:
            // 5min
            res = 5*60;
            break;
        case 3:
            // 10min
            res = 10*60;
            break;
        case 4:
            // 30min
            res = 30*60;
            break;
        case 5:
            // 60min
            res = 60*60;
            break;
        default:

    }
    return res*1000;
};

/** 变换背景 */
function changeBackground(){

	switch (wallpapermode){
        case 1://单一壁纸模式
			shouldShow();
            break;
        case 2://随机模式
			if(myList.length){
				if(random){
					// 随机模式);
					nextImage(random);
				}else{
					// 顺序模式
					nextImage();
				};
			}else{
				shouldShow();
			};
			t = setTimeout("changeBackground()",calculate(speed));
            break;
		case 3://视频模式
			shouldShow();
			break;	
        default:
    }
	//setInterval("changeBackground()",5000);
	
}

// 顺序切or随机切换
function nextImage(rands){
    var index = -1;
	var indexNow = -1;
	//首次为空
	if (currentImg)
	{
		indexNow = myList.indexOf(currentImg);
		index = indexNow;
	}
	//是否随机
    if(rands){
		while(index == indexNow)
		{
			index = Math.floor(Math.random()*(myList.length));
		}
		currentImg = myList[index];
    }else{
		if(index+1 == myList.length){
			// 播放循环到首个图片
			currentImg = myList[0];
		}else{
			// 播放下一张图片
			currentImg = myList[index+1];
		}
	}
    shouldShow();
	//setTimeout("nextImage()",5000);
}

/** 应该展示的背景 */
var shouldShow = function(){

	switch (wallpapermode){
        case 1://单一壁纸模式
			//关闭幻灯片特效
			$.backstretch("destroy", false);
			//关闭视频
			myvideo.src = null;
			//document.body.style.background = "";
			document.body.style.backgroundImage = "";
            if(custom){
				document.body.style.background ="url('"+'file:///' + custom + "')";
				//document.body.style.backgroundImage="url('"+'file:///' + custom + "')";
			}else{
				//document.body.style.background = "url('imgs/1.jpg')";
				document.body.style.background = backgroundRoute;
				//document.body.style.backgroundImage = "url('imgs/1.jpg')";
			}
			//设置但壁纸样式
			setBackgroundStyle();
            break;
        case 2://随机模式
			//关闭视频
			myvideo.src = null;
			if(myList.length){
				//$.backstretch('file:///' + currentImg, {fade: 1000});
				TransitionSwith();
			}else{
				$.backstretch("destroy", false);
				//document.body.style.backgroundImage = "url('imgs/1.jpg')";
				document.body.style.backgroundImage = backgroundRoute
			}
            break;
		case 3://视频模式
			//关闭幻灯片特效
			$.backstretch("destroy", false);
			ChangeVideoModel();
			break;
        default:
    }
};

/** 设置壁纸 */
var setBackgroundStyle = function(){
	//单壁纸样式
	switch (bgStyle){
		case 1:
			// 填充
			document.body.style.backgroundRepeat="no-repeat";
			document.body.style.backgroundSize="cover";
			document.body.style.backgroundPosition="center";
			break;
		case 2:
			// 拉伸
			//document.body.style.backgroundImage = "";
			//document.body.style.background="url('"+'file:///' + img + "')";
			document.body.style.backgroundRepeat="no-repeat";
			document.body.style.backgroundSize="100% 100%";
			document.body.style.backgroundPosition="center";
			break;
		case 3:
			// 适应
			//document.body.style.backgroundImage = "";
			//document.body.style.background="url('"+'file:///' + img + "')";
			document.body.style.backgroundRepeat="no-repeat";
			document.body.style.backgroundSize="contain";
			document.body.style.backgroundPosition="center";
			break;
		case 4:
			// 平铺
			//document.body.style.backgroundImage = "";
			//document.body.style.background="url('"+'file:///' + img + "')";
			document.body.style.backgroundRepeat="repeat";
			break;
		case 5:
			// 居中
			//document.body.style.backgroundImage = "";
			//document.body.style.background="url('"+'file:///' + img + "')";
			document.body.style.backgroundRepeat="no-repeat";
			document.body.style.backgroundPosition="center";
			break;
		default:
	}
};

var TransitionSwith = function(){
	switch (TransitionMode){
		case 1:
			$.backstretch('file:///' + currentImg, {fade: 1000})
			break;
		case 2:
			$.backstretch('file:///' + currentImg, {fadeInOut:1000})
			break;
		case 3:
			$.backstretch('file:///' + currentImg, {pushLeft: 1000})
			break;
		case 4:
			$.backstretch('file:///' + currentImg, {pushRight: 1000})
			break;
		case 5:
			$.backstretch('file:///' + currentImg, {pushUp: 1000})
			break;
		case 6:
			$.backstretch('file:///' + currentImg, {pushDown: 1000})
			break;
		case 7:
			$.backstretch('file:///' + currentImg, {coverLeft: 1000})
			break;
		case 8:
			$.backstretch('file:///' + currentImg, {coverRight: 1000})
			break;
		case 9:
			$.backstretch('file:///' + currentImg, {coverUp: 1000})
			break;
		case 10:
			$.backstretch('file:///' + currentImg, {coverDown: 1000})
			break;
		default:
	}
};
