
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lime = Color(0xFFB7FF3C);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.gf.musicplayer.audio',
    androidNotificationChannelName: 'G&F Music Player',
    androidNotificationOngoing: true,
  );
  runApp(const GFApp());
}
class Song {
  final String id, path, title, artist;
  Song(this.id, this.path, this.title, this.artist);
  Map<String,dynamic> toJson()=>{'id':id,'path':path,'title':title,'artist':artist};
  factory Song.fromJson(Map<String,dynamic> j)=>Song(j['id'],j['path'],j['title'],j['artist']);
}
class GFApp extends StatelessWidget {
  const GFApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'G&F Music Player', debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:lime,brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xFF101014)),
    home:const Home());
}
class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home> {
  final player=AudioPlayer();
  List<Song> songs=[],queue=[];
  Map<String,List<String>> playlists={};
  String selected='All songs',query='',preset='Normal';
  bool shuffle=false,loading=true;
  LoopMode repeat=LoopMode.off;
  int currentIndex=0;
  Song? get current => queue.isNotEmpty && currentIndex<queue.length ? queue[currentIndex] : null;
  @override void initState(){super.initState();player.currentIndexStream.listen((i){if(i!=null&&mounted)setState(()=>currentIndex=i);});_load();}
  @override void dispose(){player.dispose();super.dispose();}
  Future<Directory> get musicDir async {final d=Directory('${(await getApplicationDocumentsDirectory()).path}/music');if(!await d.exists())await d.create(recursive:true);return d;}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    try { songs=(jsonDecode(p.getString('songs')??'[]') as List).map((e)=>Song.fromJson(e)).where((s)=>File(s.path).existsSync()).toList(); playlists=(jsonDecode(p.getString('playlists')??'{}') as Map).map((k,v)=>MapEntry(k,List<String>.from(v))); }
    catch(_){songs=[];playlists={};}
    if(mounted)setState(()=>loading=false); await _refreshQueue();
  }
  Future<void> _save() async {final p=await SharedPreferences.getInstance();await p.setString('songs',jsonEncode(songs.map((s)=>s.toJson()).toList()));await p.setString('playlists',jsonEncode(playlists));}
  List<Song> get visible {
    var list=songs;
    if(selected!='All songs'&&playlists.containsKey(selected)){final ids=playlists[selected]!;list=list.where((s)=>ids.contains(s.id)).toList();}
    if(query.isNotEmpty){final q=query.toLowerCase();list=list.where((s)=>s.title.toLowerCase().contains(q)||s.artist.toLowerCase().contains(q)).toList();}
    return list;
  }
  Future<void> _refreshQueue() async {
    queue=List.of(visible); if(shuffle)queue.shuffle();
    if(queue.isEmpty){await player.stop();if(mounted)setState((){});return;}
    try {await player.setAudioSources(queue.map((s)=>AudioSource.file(s.path,tag:MediaItem(id:s.id,title:s.title,artist:s.artist))).toList());await player.setLoopMode(repeat);} catch(_){}
    if(mounted)setState((){});
  }
  Future<void> _import() async {
    try {
      final result=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);
      if(result==null)return; int count=0; final d=await musicDir;
      for(final f in result.files){if(f.path==null)continue;final name='${DateTime.now().microsecondsSinceEpoch}_${f.name.replaceAll(RegExp(r"[^A-Za-z0-9._ -]"),"_")}';final dest=File('${d.path}/$name');await File(f.path!).copy(dest.path);songs.add(Song(DateTime.now().microsecondsSinceEpoch.toString(),dest.path,f.name.replaceFirst(RegExp(r'\.[^.]+$'),''),'Unknown artist'));count++;}
      await _save();await _refreshQueue();if(mounted)_msg('Imported $count song(s) for offline listening.');
    }catch(e){_msg('Import failed: $e');}
  }
  Future<void> _play(Song s) async {
    queue=List.of(visible);
    if(shuffle){queue.removeWhere((x)=>x.id==s.id);queue.shuffle();queue.insert(0,s);}
    final i=queue.indexWhere((x)=>x.id==s.id);
    try {await player.setAudioSources(queue.map((x)=>AudioSource.file(x.path,tag:MediaItem(id:x.id,title:x.title,artist:x.artist))).toList(),initialIndex:i<0?0:i);await player.setLoopMode(repeat);await player.play();if(mounted)setState(()=>currentIndex=i<0?0:i);}catch(_){_msg('Unable to play this audio file.');}
  }
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> _newPlaylist() async {
    final c=TextEditingController();
    final n=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('New playlist'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(hintText:'Playlist name')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Create'))]));
    if(n==null||n.isEmpty)return;if(n=='All songs'||playlists.containsKey(n)){_msg('That playlist already exists.');return;}
    setState((){playlists[n]=[];selected=n;});await _save();await _refreshQueue();
  }
  Future<void> _addPlaylist(Song s) async {
    if(playlists.isEmpty){await _newPlaylist();if(playlists.isEmpty)return;}
    if(!mounted)return;
    final n=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Add to playlist'),children:playlists.keys.map((k)=>SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,k),child:Text(k))).toList()));
    if(n==null)return;if(!playlists[n]!.contains(s.id))playlists[n]!.add(s.id);await _save();_msg('Added to $n');
  }
  Future<void> _remove(Song s) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Remove song?'),content:Text('Remove ${s.title} from this app?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Remove'))]));
    if(ok!=true)return;if(current?.id==s.id)await player.stop();try{await File(s.path).delete();}catch(_){}songs.removeWhere((x)=>x.id==s.id);for(final ids in playlists.values){ids.remove(s.id);}await _save();await _refreshQueue();
  }
  Future<void> _edit(Song s) async {
    final t=TextEditingController(text:s.title),a=TextEditingController(text:s.artist);
    final v=await showDialog<List<String>>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Edit song'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,decoration:const InputDecoration(labelText:'Title')),TextField(controller:a,decoration:const InputDecoration(labelText:'Artist'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,[t.text.trim(),a.text.trim()]),child:const Text('Save'))]));
    if(v==null||v[0].isEmpty)return;final i=songs.indexWhere((x)=>x.id==s.id);songs[i]=Song(s.id,s.path,v[0],v[1].isEmpty?'Unknown artist':v[1]);await _save();await _refreshQueue();
  }
  Future<void> _eq() async {
    final p=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const ListTile(title:Text('Equalizer presets'),subtitle:Text('Android system EQ support depends on device. iOS app-level EQ is not implemented in this starter.')),
      ...['Normal','Bass boost','Treble','Vocal','Rock'].map((x)=>ListTile(title:Text(x),trailing:x==preset?const Icon(Icons.check,color:lime):null,onTap:()=>Navigator.pop(ctx,x))),
    ])));
    if(p==null)return;setState(()=>preset=p);final prefs=await SharedPreferences.getInstance();await prefs.setString('eqPreset',p);
    _msg(Platform.isAndroid?'Preset selected: $p. Device EQ support may vary.':'Preset saved. App-controlled EQ requires an iOS audio-engine implementation.');
  }
  String _time(Duration d)=>'${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  @override Widget build(BuildContext context){
    final list=visible;
    return Scaffold(
      appBar:AppBar(title:const Text('G&F Music Player',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:_eq,icon:const Icon(Icons.equalizer),tooltip:'Equalizer'),IconButton(onPressed:_newPlaylist,icon:const Icon(Icons.playlist_add),tooltip:'New playlist'),IconButton(onPressed:_import,icon:const Icon(Icons.library_add),tooltip:'Import music')]),
      body:loading?const Center(child:CircularProgressIndicator()):Column(children:[
        Container(margin:const EdgeInsets.fromLTRB(16,6,16,14),padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF303B20),Color(0xFF1C1C23)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('YOUR MUSIC. YOUR RULES.',style:TextStyle(color:lime,letterSpacing:2,fontWeight:FontWeight.bold,fontSize:11)),const SizedBox(height:8),const Text('Play it your way.',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),Text('${songs.length} songs stored offline',style:const TextStyle(color:Colors.white70)),const SizedBox(height:12),FilledButton.icon(onPressed:_import,icon:const Icon(Icons.add),label:const Text('Import music'))])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search songs or artists',filled:true,fillColor:const Color(0xFF1B1B22),border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none)))),
        SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14),children:[
          _chip('All songs',selected=='All songs',()async{setState(()=>selected='All songs');await _refreshQueue();}),
          ...playlists.keys.map((n)=>_chip(n,selected==n,()async{setState(()=>selected=n);await _refreshQueue();}))
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(18,8,18,6),child:Row(children:[Expanded(child:Text(selected,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),Text('${list.length} tracks',style:const TextStyle(color:Colors.white60))])),
        Expanded(child:list.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.music_note,size:60,color:lime),Text(query.isEmpty?'Your library is empty':'No matching songs',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Padding(padding:EdgeInsets.all(12),child:Text('Import audio files from your phone to listen offline.',textAlign:TextAlign.center)),FilledButton(onPressed:_import,child:const Text('Choose music files'))])):ListView.separated(itemCount:list.length,separatorBuilder:(_,__)=>const Divider(height:1,indent:76),itemBuilder:(ctx,i){
          final s=list[i];return ListTile(leading:Container(width:46,height:46,decoration:BoxDecoration(color:const Color(0xFF2A3320),borderRadius:BorderRadius.circular(12)),child:Icon(s.id==current?.id?Icons.graphic_eq:Icons.music_note,color:lime)),title:Text(s.title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:FontWeight.bold,color:s.id==current?.id?lime:null)),subtitle:Text(s.artist),onTap:()=>_play(s),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='add')_addPlaylist(s);if(v=='edit')_edit(s);if(v=='remove')_remove(s);},itemBuilder:(_)=>const [PopupMenuItem(value:'add',child:Text('Add to playlist')),PopupMenuItem(value:'edit',child:Text('Edit details')),PopupMenuItem(value:'remove',child:Text('Remove song'))]));})),
      ]),
      bottomNavigationBar:Container(color:const Color(0xFF1B1B22),padding:const EdgeInsets.fromLTRB(10,6,10,8),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[const Icon(Icons.album,color:lime,size:32),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(current?.title??'Choose a song',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),Text(current?.artist??'Offline music library',style:const TextStyle(color:Colors.white60,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis)])),IconButton(onPressed:queue.isEmpty?null:()=>player.seekToPrevious(),icon:const Icon(Icons.skip_previous)),StreamBuilder<PlayerState>(stream:player.playerStateStream,builder:(ctx,s){final playing=s.data?.playing??false;return IconButton.filled(onPressed:queue.isEmpty?_import:()=>playing?player.pause():player.play(),style:IconButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),icon:Icon(playing?Icons.pause:Icons.play_arrow));}),IconButton(onPressed:queue.isEmpty?null:()=>player.seekToNext(),icon:const Icon(Icons.skip_next))]),
        StreamBuilder<Duration>(stream:player.positionStream,builder:(ctx,s){final pos=s.data??Duration.zero;final dur=player.duration??Duration.zero;final max=dur.inMilliseconds>0?dur.inMilliseconds.toDouble():1.0;return Row(children:[Text(_time(pos),style:const TextStyle(fontSize:10,color:Colors.white60)),Expanded(child:Slider(value:pos.inMilliseconds.clamp(0,max.toInt()).toDouble(),max:max,onChanged:dur.inMilliseconds==0?null:(v)=>player.seek(Duration(milliseconds:v.round())),activeColor:lime)),Text(_time(dur),style:const TextStyle(fontSize:10,color:Colors.white60))]);}),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          TextButton.icon(onPressed:()async{setState(()=>shuffle=!shuffle);final c=current;if(c!=null){final playing=player.playing;await _play(c);if(!playing)await player.pause();}else{await _refreshQueue();}},icon:Icon(Icons.shuffle,color:shuffle?lime:Colors.white60),label:Text('Shuffle',style:TextStyle(color:shuffle?lime:Colors.white60))),
          TextButton.icon(onPressed:()async{setState(()=>repeat=repeat==LoopMode.off?LoopMode.all:repeat==LoopMode.all?LoopMode.one:LoopMode.off);await player.setLoopMode(repeat);},icon:Icon(repeat==LoopMode.one?Icons.repeat_one:Icons.repeat,color:repeat==LoopMode.off?Colors.white60:lime),label:Text(repeat==LoopMode.off?'Repeat off':repeat==LoopMode.one?'Repeat one':'Repeat all',style:TextStyle(color:repeat==LoopMode.off?Colors.white60:lime)))
        ])
      ]))
    );
  }
  Widget _chip(String s,bool active,VoidCallback tap)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(s),selected:active,onSelected:(_)=>tap(),selectedColor:lime,labelStyle:TextStyle(color:active?Colors.black:Colors.white,fontWeight:FontWeight.bold)));
}
