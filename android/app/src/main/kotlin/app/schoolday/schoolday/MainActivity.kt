package app.schoolday.schoolday

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.TimeZone

class MainActivity: FlutterFragmentActivity() {
 override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"schoolday/native").setMethodCallHandler { call,result ->
   when(call.method){
    "deviceInfo" -> {
     val manager=getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
     val memory=ActivityManager.MemoryInfo();manager.getMemoryInfo(memory)
     result.success(mapOf("timezone" to TimeZone.getDefault().id,"low_ram" to (manager.isLowRamDevice||memory.totalMem<=3L*1024*1024*1024)))
    }
    "protectReport" -> {if(call.argument<Boolean>("enabled")==true)window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE);result.success(null)}
    "openFile" -> {
     try {
      val file=File(call.argument<String>("path")?:"").canonicalFile
      val allowed=listOf(filesDir.canonicalPath+File.separator,cacheDir.canonicalPath+File.separator)
      val mime=call.argument<String>("mime")?:""
      if(!file.isFile||allowed.none{file.path.startsWith(it)}||mime !in listOf("application/pdf","image/jpeg","image/png")){result.error("file_access","Document unavailable",null)}else{
       val uri=FileProvider.getUriForFile(this,"$packageName.documents",file)
       startActivity(Intent.createChooser(Intent(Intent.ACTION_VIEW).setDataAndType(uri,mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),"Open school document"))
       result.success(null)
      }
     }catch(e:Exception){result.error("document_viewer","No document viewer is available",null)}
    }
    else -> result.notImplemented()
   }
  }
 }
}
