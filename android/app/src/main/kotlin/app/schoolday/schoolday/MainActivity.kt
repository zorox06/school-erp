package app.schoolday.schoolday

import android.app.ActivityManager
import android.content.Intent
import android.os.Build
import android.os.PowerManager
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
    "deviceInfo" -> result.success(deviceInfo())
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

 private fun deviceInfo(): Map<String, Any> {
  val activityManager = getSystemService(ActivityManager::class.java)
  val memory = ActivityManager.MemoryInfo()
  activityManager?.getMemoryInfo(memory)
  val power = getSystemService(PowerManager::class.java)
  val lowRam = activityManager?.isLowRamDevice == true || memory.totalMem in 1L..(3L * 1024 * 1024 * 1024)
  val thermalPressure = power != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
      power.currentThermalStatus >= PowerManager.THERMAL_STATUS_MODERATE
  return mapOf(
      "timezone" to TimeZone.getDefault().id,
      "low_ram" to lowRam,
      "reduce_work" to (lowRam || memory.lowMemory || power?.isPowerSaveMode == true || thermalPressure),
  )
 }
}
