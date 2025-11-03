#!/usr/bin/env bash
set -e

echo "Writing pubspec.yaml deps"
cat > pubspec.yaml <<'YAML'
name: recoverx
description: RecoverX Light Testing Build
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.1.4
  file_picker: ^8.1.2
  crypto: ^3.0.3
  http: ^1.2.2
  csv: ^6.0.0
  pdf: ^3.11.0
  printing: ^5.13.1
  sqlite3: ^2.4.6

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
YAML

echo "Creating lib/ sources"
mkdir -p lib/report lib/root lib/web

# main.dart
cat > lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'quick_scan_screen.dart';
import 'sms_dump_screen.dart';
import 'root/root_utils.dart';
import 'web/downloads_screen.dart';
import 'web/history_screen.dart';

void main() => runApp(const RecoverXLight());

class RecoverXLight extends StatelessWidget {
  const RecoverXLight({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RecoverX Light',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{
  bool rooted = false; String status = 'Detecting…';
  @override void initState(){ super.initState(); RootUtils.detectRoot().then((v)=> setState((){ rooted=v; status = v? 'Root detected' : 'No root'; })); }
  @override Widget build(BuildContext c)=>Scaffold(
    appBar: AppBar(title: const Text('RecoverX Light')),
    body: ListView(padding: const EdgeInsets.all(16), children:[
      ListTile(leading: const Icon(Icons.security), title: const Text('Root status'), subtitle: Text(status)),
      const SizedBox(height:8),
      _tile('Quick Scan', 'MediaStore + Downloads', const QuickScanScreen()),
      _tile('SMS/MMS Dump', 'Messages and MMS parts preview', const SmsDumpScreen()),
      _tile('Download History', 'Android Download Manager records', const DownloadsScreen()),
      _tile('Browser History', 'Import Chrome/Firefox DBs via SAF', const HistoryScreen()),
    ]),
  );
  Widget _tile(String t,String s,Widget page)=>Card(child: ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(s), trailing: const Icon(Icons.chevron_right), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=>page))));
}
DART

# android_bridge.dart
cat > lib/android_bridge.dart <<'DART'
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class AndroidBridge {
  static const _media = MethodChannel('rx.android.media');
  static const _sms = MethodChannel('rx.android.sms');
  static const _perm = MethodChannel('rx.android.perms');

  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    final ok = await _perm.invokeMethod<bool>('requestAll');
    return ok ?? false;
  }

  static Future<List<Map<String, dynamic>>> quickScan({int limit = 500}) async {
    if (!Platform.isAndroid) return [];
    final res = await _media.invokeMethod<String>('quickScan', {'limit': limit});
    final list = (jsonDecode(res ?? '[]') as List).cast<Map>();
    return list.map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
  }

  static Future<Map<String, dynamic>> dumpSmsMms({int max = 5000}) async {
    if (!Platform.isAndroid) return {};
    final res = await _sms.invokeMethod<String>('dump', {'max': max});
    return (jsonDecode(res ?? '{}') as Map).cast<String, dynamic>();
  }
}
DART

# quick_scan_screen.dart
cat > lib/quick_scan_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'android_bridge.dart';

class QuickScanScreen extends StatefulWidget { const QuickScanScreen({super.key}); @override State<QuickScanScreen> createState() => _QuickScanScreenState(); }
class _QuickScanScreenState extends State<QuickScanScreen> {
  bool busy = false; List<Map<String, dynamic>> rows = []; String status = 'Idle';

  Future<void> run() async {
    setState(() { busy = true; status = 'Requesting permissions'; });
    final ok = await AndroidBridge.requestPermissions();
    if (!ok) { setState(() { busy = false; status = 'Permissions denied'; }); return; }
    setState(() { status = 'Scanning MediaStore'; });
    final list = await AndroidBridge.quickScan(limit: 2000);
    setState(() { rows = list; busy = false; status = 'Done: '+list.length.toString(); });
  }

  @override Widget build(BuildContext ctx)=>Scaffold(appBar: AppBar(title: const Text('Quick Scan (Android)')),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children:[
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(status), if(busy) const CircularProgressIndicator()]),
      const SizedBox(height:8), Expanded(child: rows.isEmpty? const Center(child: Text('Tap START to scan.')): ListView.separated(itemCount: rows.length, separatorBuilder:(_,__)=>const Divider(height:1), itemBuilder:(_,i){ final r = rows[i]; return ListTile(
        title: Text(r['displayName']??'file'),
        subtitle: Text('${r['relativePath']??''} • ${(r['size']??0)} bytes'),
        trailing: Text(r['mimeType']??''),
      ); })),
      const SizedBox(height:8), Row(children:[Expanded(child: OutlinedButton(onPressed: busy? null: run, child: const Text('START')))])
    ])));
}
DART

# sms_dump_screen.dart
cat > lib/sms_dump_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'android_bridge.dart';

class SmsDumpScreen extends StatefulWidget { const SmsDumpScreen({super.key}); @override State<SmsDumpScreen> createState()=>_SmsDumpScreenState(); }
class _SmsDumpScreenState extends State<SmsDumpScreen>{
  Map<String,dynamic> data = {}; bool busy=false; String status='Idle';
  Future<void> run() async{ setState(()=>busy=true); final ok = await AndroidBridge.requestPermissions(); if(!ok){ setState(()=>busy=false); return; }
    setState(()=>status='Reading SMS/MMS'); final d = await AndroidBridge.dumpSmsMms(max: 5000); setState((){ data=d; busy=false; status='Done'; }); }
  @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: const Text('SMS/MMS Dump')),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children:[ Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(status), if(busy) const CircularProgressIndicator()]), const SizedBox(height:8), Expanded(child: ListView(children:[
      Text('SMS: ${(data['sms'] as List?)?.length ?? 0}'), Text('MMS: ${(data['mms'] as List?)?.length ?? 0}'), const Divider(),
      ...(((data['sms'] as List?)??[]).take(200).map((s)=>ListTile(title: Text('${s['address']??''}'), subtitle: Text('${s['date']??''} • ${s['body']??''}')))),
    ])), Row(children:[Expanded(child: FilledButton(onPressed: busy? null: run, child: const Text('Dump Now')))]) ])));
}
DART

# report/report_generator.dart
cat > lib/report/report_generator.dart <<'DART'
import 'dart:io';
import 'package:csv/csv.dart' as csv;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ArtifactRecord {
  final String type; final String nameOrId; final String pathOrAddress; final DateTime timestamp; final String sha256; final int sizeBytes;
  ArtifactRecord(this.type,this.nameOrId,this.pathOrAddress,this.timestamp,this.sha256,this.sizeBytes);
}

class ReportGenerator {
  static Future<File> writeCsv(List<ArtifactRecord> rows, Directory outDir, {String name='recoverx_report.csv'}) async {
    final header = ['type','name_or_id','path_or_address','timestamp','sha256','size_bytes'];
    final data = [header, ...rows.map((r)=>[r.type, r.nameOrId, r.pathOrAddress, r.timestamp.toIso8601String(), r.sha256, r.sizeBytes])];
    final csvStr = const csv.ListToCsvConverter().convert(data);
    final f = File('${outDir.path}/$name'); return f.writeAsString(csvStr);
  }
  static Future<File> writePdf(List<ArtifactRecord> rows, Directory outDir, {String name='recoverx_report.pdf'}) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)), build: (_)=>[
      pw.Text('RecoverX Case Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6), pw.Text('Generated: ${DateTime.now().toIso8601String()}'), pw.SizedBox(height: 16),
      pw.Table.fromTextArray(headers: ['Type','Name/ID','Path/Address','Timestamp','SHA-256','Size'], data: rows.map((r)=>[r.type,r.nameOrId,r.pathOrAddress,r.timestamp.toIso8601String(),r.sha256,'${r.sizeBytes} B']).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 9), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300))
    ]));
    final f = File('${outDir.path}/$name'); await f.writeAsBytes(await doc.save()); return f;
  }
}
DART

# root/root_utils.dart
cat > lib/root/root_utils.dart <<'DART'
import 'dart:io';
class RootUtils {
  static bool get isAndroid => Platform.isAndroid;
  static Future<bool> detectRoot() async {
    if (!isAndroid) return false;
    final suspects = ['/system/bin/su','/system/xbin/su','/sbin/su','/su/bin/su','/vendor/bin/su'];
    for (final p in suspects) { if (File(p).existsSync()) return true; }
    try { final res = await Process.run('which', ['su']); if ((res.stdout as String?)?.contains('su') == true) return true; } catch (_) {}
    return false;
  }
}
DART

# web/android_web_bridge.dart
cat > lib/web/android_web_bridge.dart <<'DART'
import 'dart:convert';
import 'package:flutter/services.dart';

class AndroidWebBridge {
  static const _web = MethodChannel('rx.android.web');
  static Future<List<Map<String,dynamic>>> downloads({int max=1000}) async {
    final res = await _web.invokeMethod<String>('downloads', {'max': max});
    final list = (jsonDecode(res ?? '[]') as List).cast<Map>();
    return list.map((e)=> e.map((k,v)=> MapEntry(k.toString(), v))).toList();
  }
}
DART

# web/downloads_screen.dart
cat > lib/web/downloads_screen.dart <<'DART'
import 'package:flutter/material.dart';
import 'android_web_bridge.dart';

class DownloadsScreen extends StatefulWidget { const DownloadsScreen({super.key}); @override State<DownloadsScreen> createState()=>_State(); }
class _State extends State<DownloadsScreen>{
  List<Map<String,dynamic>> rows=[]; bool busy=false;
  Future<void> run() async { setState(()=>busy=true); final r = await AndroidWebBridge.downloads(); setState(()=>rows=r); setState(()=>busy=false); }
  @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: const Text('Download History')),
    body: Column(children:[ if(busy) const LinearProgressIndicator(),
      Expanded(child: ListView.separated(itemCount: rows.length, separatorBuilder:(_,__)=>const Divider(height:1), itemBuilder:(_,i){ final r=rows[i]; return ListTile(title: Text(r['title']??'(no title)'), subtitle: Text('${r['url']??''} • ${(r['bytes']??0)} bytes'), trailing: Text(((r['lastModified']??0) is int)? DateTime.fromMillisecondsSinceEpoch((r['lastModified'])*1000, isUtc: true).toLocal().toIso8601String() : '')); })),
      Padding(padding: const EdgeInsets.all(12), child: FilledButton(onPressed: run, child: const Text('Scan')))
    ]));
}
DART

# web/saf_picker.dart
cat > lib/web/saf_picker.dart <<'DART'
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SafPicker {
  static Future<List<File>> pickFiles({List<String>? allowedExt}) async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: allowedExt);
    if (res == null) return [];
    return res.files.where((f)=> f.path != null).map((f)=> File(f.path!)).toList();
  }
}
DART

# web/history_parser.dart
cat > lib/web/history_parser.dart <<'DART'
import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class VisitRecord { final String url; final String title; final DateTime when; final int visits; VisitRecord(this.url,this.title,this.when,this.visits); }

class BrowserParsers {
  static List<VisitRecord> parseChromeHistory(File historyDb){
    final db = sqlite.sqlite3.open(historyDb.path, readOnly: true);
    final rs = db.select('SELECT urls.url, urls.title, visits.visit_time, urls.visit_count FROM urls JOIN visits ON urls.id=visits.url;');
    List<VisitRecord> out=[];
    for (final row in rs){
      final chromeEpoch = row['visit_time'] as int;
      final ts = DateTime.utc(1601,1,1).add(Duration(microseconds: chromeEpoch));
      out.add(VisitRecord(row['url'] as String? ?? '', row['title'] as String? ?? '', ts, row['visit_count'] as int? ?? 0));
    }
    db.dispose();
    return out;
  }

  static List<VisitRecord> parseFirefoxPlaces(File places){
    final db = sqlite.sqlite3.open(places.path, readOnly: true);
    final rs = db.select('SELECT moz_places.url, moz_places.title, moz_historyvisits.visit_date, moz_places.visit_count FROM moz_places JOIN moz_historyvisits ON moz_places.id = moz_historyvisits.place_id;');
    List<VisitRecord> out=[];
    for (final row in rs){
      final micro = row['visit_date'] as int? ?? 0;
      final ts = DateTime.fromMicrosecondsSinceEpoch(micro, isUtc: true);
      out.add(VisitRecord(row['url'] as String? ?? '', row['title'] as String? ?? '', ts, row['visit_count'] as int? ?? 0));
    }
    db.dispose();
    return out;
  }
}
DART

# web/history_screen.dart
cat > lib/web/history_screen.dart <<'DART'
import 'dart:io';
import 'package:flutter/material.dart';
import 'saf_picker.dart';
import 'history_parser.dart';

class HistoryScreen extends StatefulWidget { const HistoryScreen({super.key}); @override State<HistoryScreen> createState()=>_State(); }
class _State extends State<HistoryScreen>{
  List<VisitRecord> rows=[]; bool busy=false;
  Future<void> importChrome() async { setState(()=>busy=true); final files = await SafPicker.pickFiles(allowedExt:['db','sqlite','History','history']); for (final f in files){ try { rows.addAll(BrowserParsers.parseChromeHistory(f)); } catch(_) {} } setState(()=>busy=false); }
  Future<void> importFirefox() async { setState(()=>busy=true); final files = await SafPicker.pickFiles(allowedExt:['sqlite']); for (final f in files){ try { rows.addAll(BrowserParsers.parseFirefoxPlaces(f)); } catch(_) {} } setState(()=>busy=false); }
  @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: const Text('Browser History')),
    body: Column(children:[ if(busy) const LinearProgressIndicator(),
      Expanded(child: rows.isEmpty? const Center(child: Text('Import Chrome/Firefox history DBs or exports.')): ListView.separated(itemCount: rows.length, separatorBuilder:(_,__)=>const Divider(height:1), itemBuilder:(_,i){ final r=rows[i]; return ListTile(title: Text(r.title.isEmpty? r.url : r.title), subtitle: Text(r.url), trailing: Text(r.when.toLocal().toIso8601String())); })),
      Padding(padding: const EdgeInsets.all(12), child: Row(children:[ Expanded(child: OutlinedButton(onPressed: importChrome, child: const Text('Import Chrome'))), const SizedBox(width:8), Expanded(child: OutlinedButton(onPressed: importFirefox, child: const Text('Import Firefox'))), ]))
    ]));
}
DART

echo "Creating Android Kotlin bridge"
mkdir -p android/app/src/main/kotlin/com/recoverx/app

cat > android/app/src/main/kotlin/com/recoverx/app/MainActivity.kt <<'KT'
package com.recoverx.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        // Channels are registered in RecoverXBridge
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "noop").setMethodCallHandler { _, result -> result.success(null) }
        RecoverXBridge.register(engine)
    }
}
KT

cat > android/app/src/main/kotlin/com/recoverx/app/RecoverXBridge.kt <<'KT'
package com.recoverx.app

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class RecoverXBridge {
    companion object {
        fun register(engine: FlutterEngine) {
            val context = engine.dartExecutor.binaryMessenger
            val media = MethodChannel(context, "rx.android.media")
            val sms = MethodChannel(context, "rx.android.sms")
            val perms = MethodChannel(context, "rx.android.perms")
            val web = MethodChannel(context, "rx.android.web")

            media.setMethodCallHandler { call, result ->
                when(call.method){
                    "quickScan" -> {
                        val limit = (call.argument<Int>("limit") ?: 500)
                        result.success(quickScanJson(engine, limit))
                    }
                    else -> result.notImplemented()
                }
            }
            sms.setMethodCallHandler { call, result ->
                when(call.method){
                    "dump" -> result.success(dumpSmsMmsJson(engine, call.argument<Int>("max") ?: 5000))
                    else -> result.notImplemented()
                }
            }
            perms.setMethodCallHandler { call, result ->
                when(call.method){
                    "requestAll" -> result.success(requestAllPerms(engine))
                    else -> result.notImplemented()
                }
            }
            web.setMethodCallHandler { call, result ->
                when(call.method){
                    "downloads" -> result.success(dumpDownloadsJson(engine, call.argument<Int>("max") ?: 1000))
                    else -> result.notImplemented()
                }
            }
        }

        private fun requestAllPerms(engine: FlutterEngine): Boolean {
            val activity = engine.plugins.get(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding::class.java)
            val ctx = engine.applicationContext
            val wants = mutableListOf(
                Manifest.permission.READ_SMS
            )
            if (Build.VERSION.SDK_INT >= 33){
                wants.add(Manifest.permission.READ_MEDIA_IMAGES)
                wants.add(Manifest.permission.READ_MEDIA_VIDEO)
            } else {
                wants.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            val missing = wants.filter { ContextCompat.checkSelfPermission(ctx, it) != PackageManager.PERMISSION_GRANTED }
            if (missing.isNotEmpty()){
                val act = (engine.activity as? Activity)
                if (act != null) {
                    ActivityCompat.requestPermissions(act, missing.toTypedArray(), 1001)
                }
            }
            return missing.isEmpty()
        }

        private fun quickScanJson(engine: FlutterEngine, limit: Int): String {
            val ctx = engine.applicationContext
            val arr = JSONArray()
            val fields = arrayOf(
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.RELATIVE_PATH,
                MediaStore.MediaColumns.DATE_ADDED
            )
            val q = ctx.contentResolver.query(
                MediaStore.Files.getContentUri("external"),
                fields, null, null,
                MediaStore.MediaColumns.DATE_ADDED + " DESC LIMIT " + limit
            )
            q?.use { c: Cursor ->
                while(c.moveToNext()){
                    val o = JSONObject()
                    o.put("displayName", c.getString(0))
                    o.put("mimeType", c.getString(1))
                    o.put("size", c.getLong(2))
                    o.put("relativePath", c.getString(3))
                    o.put("dateAdded", c.getLong(4))
                    arr.put(o)
                }
            }
            return arr.toString()
        }

        private fun dumpSmsMmsJson(engine: FlutterEngine, max:Int): String {
            val ctx = engine.applicationContext
            val root = JSONObject()
            val smsArr = JSONArray()
            val smsUri = Telephony.Sms.CONTENT_URI
            val smsProj = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.DATE, Telephony.Sms.BODY, Telephony.Sms.TYPE)
            ctx.contentResolver.query(smsUri, smsProj, null, null, Telephony.Sms.DATE + " DESC LIMIT " + max)?.use { c ->
                while(c.moveToNext()){
                    val o = JSONObject()
                    o.put("address", c.getString(0))
                    o.put("date", c.getLong(1))
                    o.put("body", c.getString(2))
                    o.put("type", c.getInt(3))
                    smsArr.put(o)
                }
            }
            root.put("sms", smsArr)

            val mmsArr = JSONArray()
            val mmsUri = Uri.parse("content://mms")
            val mmsProj = arrayOf("_id", "date", "sub")
            ctx.contentResolver.query(mmsUri, mmsProj, null, null, "date DESC LIMIT " + max)?.use { c ->
                while(c.moveToNext()){
                    val msg = JSONObject()
                    val id = c.getString(0)
                    msg.put("_id", id)
                    msg.put("date", c.getLong(1))
                    msg.put("sub", c.getString(2))

                    val parts = JSONArray()
                    ctx.contentResolver.query(Uri.parse("content://mms/$id/part"), arrayOf("_id","ct","name","text"), null, null, null)?.use { p ->
                        while(p.moveToNext()){
                            val part = JSONObject()
                            val partId = p.getString(0)
                            part.put("_id", partId)
                            part.put("ct", p.getString(1))
                            part.put("name", p.getString(2))
                            val maybeText = p.getString(3)
                            if (maybeText != null) part.put("text", maybeText)
                            parts.put(part)
                        }
                    }
                    msg.put("parts", parts)
                    mmsArr.put(msg)
                }
            }
            root.put("mms", mmsArr)
            return root.toString()
        }

        private fun dumpDownloadsJson(engine: FlutterEngine, max:Int): String {
            val ctx = engine.applicationContext
            val arr = JSONArray()
            val uri = Uri.parse("content://downloads/my_downloads")
            val proj = arrayOf("_id","title","description","uri","lastmod","status","total_bytes")
            ctx.contentResolver.query(uri, proj, null, null, "lastmod DESC LIMIT " + max)?.use { c ->
                while (c.moveToNext()){
                    val o = JSONObject()
                    o.put("id", c.getLong(0))
                    o.put("title", c.getString(1))
                    o.put("desc", c.getString(2))
                    o.put("url", c.getString(3))
                    o.put("lastModified", c.getLong(4))
                    o.put("status", c.getInt(5))
                    o.put("bytes", c.getLong(6))
                    arr.put(o)
                }
            }
            return arr.toString()
        }
    }
}
KT

echo "Patching AndroidManifest permissions"
MANIFEST="android/app/src/main/AndroidManifest.xml"
# In freshly created project, this file exists. We'll append permissions at top-level.
if [ -f "$MANIFEST" ]; then
  # Insert uses-permission lines after <manifest ...> line if not present
  perl -0777 -pe 's#(<manifest[^>]*>)#\\1\n    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />\n    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n    <uses-permission android:name="android.permission.READ_SMS" />\n#g' -i "$MANIFEST"
fi

echo "Setup complete."
