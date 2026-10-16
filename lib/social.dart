export 'feed.dart';
export 'groups.dart';
export 'profile.dart';
String niceDate(dynamic value) {
 final d=DateTime.tryParse('$value')?.toLocal();
 return d==null?'':'${d.day}.${d.month}.${d.year}';
}
