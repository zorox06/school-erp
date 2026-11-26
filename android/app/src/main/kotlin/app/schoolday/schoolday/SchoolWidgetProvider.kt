package app.schoolday.schoolday
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
abstract class SchoolWidgetProvider:HomeWidgetProvider(){
 abstract val kind:String
 override fun onUpdate(context:Context,appWidgetManager:AppWidgetManager,appWidgetIds:IntArray,widgetData:SharedPreferences){
  val enabled=widgetData.getBoolean("enabled",false)
  val updated=widgetData.getString("updated","")?:""
  val today=SimpleDateFormat("yyyy-MM-dd",Locale.US).format(Date())
  val valid=enabled&&(kind!="timetable"||updated.startsWith(today))
  val content=if(valid) widgetData.getString(kind,"")?:"" else ""
  for(id in appWidgetIds){val views=RemoteViews(context.packageName,R.layout.school_widget)
   views.setTextViewText(R.id.widget_title,if(kind=="timetable")"Today’s timetable" else "Homework due")
   views.setTextViewText(R.id.widget_body,if(!enabled)"Enable widgets in Schoolday settings" else if(!valid)"Open Schoolday to refresh today’s lessons" else if(content.isBlank())"Nothing published yet" else content)
   views.setOnClickPendingIntent(R.id.widget_root,HomeWidgetLaunchIntent.getActivity(context,MainActivity::class.java,Uri.parse(if(valid) widgetData.getString("${kind}_url","schoolday://$kind") ?: "schoolday://$kind" else "schoolday://$kind")))
   appWidgetManager.updateAppWidget(id,views)
  }
 }
}
class TimetableWidgetProvider:SchoolWidgetProvider(){override val kind="timetable"}
class HomeworkWidgetProvider:SchoolWidgetProvider(){override val kind="homework"}
