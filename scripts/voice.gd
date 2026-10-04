extends Node
## 한국어 음성(TTS). 기기에서 가장 자연스러운 음성을 골라 쓴다.
##  - 우선순위: Edge/Windows의 "Natural/Online" 신경망 음성 > Google > Apple 고음질(Enhanced/Premium) > 기타
##  - 화자: 남자 주인공 / 여자 주인공 / 오박사 / 트레이너 / 포켓몬(이름을 외치는 울음소리)

var enabled := true
var speaking_t := 0.0

## 화자별 [원하는 성별, 높이, 빠르기]
const SPEAKERS := {
	"m": ["m", 1.0, 1.0],
	"f": ["f", 1.05, 1.0],
	"oak": ["m", 0.85, 0.92],
	"trainer": ["m", 1.0, 1.05],
	"mon": ["f", 1.7, 1.25],
}

const MALE := "injoon|hyunsu|minsu|jinho|인준|현수|민수|진호|male|남성|-koc|-kod"
const FEMALE := "sunhi|yuna|sora|heami|jimin|선희|유나|소라|혜미|지민|female|여성|-koa|-kob|google"


func speak(text: String, who := "m") -> void:
	if not enabled or text == "":
		return
	var sp: Array = SPEAKERS.get(who, SPEAKERS.m)
	if OS.has_feature("web"):
		var js := """
			(function(t,g,pitch,rate){try{var s=window.speechSynthesis;if(!s)return;
			var vs=s.getVoices().filter(function(v){return v.lang&&v.lang.toLowerCase().replace('_','-').indexOf('ko')==0;});
			var male=new RegExp('%s','i'),female=new RegExp('%s','i');
			function score(v){var id=v.name+' '+v.voiceURI,sc=0;
				if(/natural|online|neural/i.test(id))sc+=10;
				if(/google/i.test(id))sc+=4;
				if(/enhanced|premium|siri/i.test(id))sc+=4;
				var isM=male.test(id)&&!female.test(id),isF=female.test(id);
				if(g=='m'&&isM)sc+=6;if(g=='f'&&isF)sc+=6;
				if(g=='m'&&isF)sc-=3;if(g=='f'&&isM)sc-=3;
				return sc;}
			var best=null,bs=-99;for(var i=0;i<vs.length;i++){var sc=score(vs[i]);if(sc>bs){bs=sc;best=vs[i];}}
			var u=new SpeechSynthesisUtterance(t);u.lang='ko-KR';u.rate=rate;u.pitch=pitch;
			if(best){u.voice=best;var id=best.name+' '+best.voiceURI;
				var hasM=male.test(id)&&!female.test(id);
				if(g=='m'&&!hasM){u.pitch=pitch*0.72;}}
			s.cancel();s.speak(u);}catch(e){}})(%s,'%s',%s,%s);
		""" % [MALE, FEMALE, JSON.stringify(text), sp[0], str(sp[1]), str(sp[2])]
		JavaScriptBridge.eval(js, true)
		return
	# 데스크톱: Godot TTS
	var voices := DisplayServer.tts_get_voices_for_language("ko")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 80, sp[1], sp[2])


## 포켓몬 울음: 애니메이션처럼 이름을 외친다 (피카츄 → "피카피카!")
func cry(mon_name: String) -> void:
	var t := mon_name
	if mon_name == "피카츄":
		t = "피카, 피카츄!"
	elif mon_name.length() >= 2:
		t = mon_name + "!"
	speak(t, "mon")
