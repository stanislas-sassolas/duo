package com.duo.duo_draw

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget d'écran d'accueil : le dernier dessin reçu, façon polaroïd.
 *
 * Les données sont écrites par l'app Flutter (DrawingWidgetService) :
 * - duo_latest     : chemin du PNG du dessin
 * - duo_caption    : petit mot (optionnel)
 * - duo_sub        : « Alex · 10:57 »
 * - duo_drawing_id : dessin ouvert quand on touche le widget
 */
class DuoWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val imagePath = widgetData.getString("duo_latest", null)
    val caption = widgetData.getString("duo_caption", null).orEmpty()
    val sub = widgetData.getString("duo_sub", null).orEmpty()
    val drawingId = widgetData.getString("duo_drawing_id", null)
    val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.duo_widget)

      if (bitmap != null) {
        views.setImageViewBitmap(R.id.widget_image, bitmap)
        views.setViewVisibility(R.id.widget_image, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty, View.GONE)
      } else {
        views.setViewVisibility(R.id.widget_image, View.GONE)
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
      }

      views.setTextViewText(R.id.widget_caption, caption)
      views.setViewVisibility(
          R.id.widget_caption,
          if (caption.isBlank()) View.GONE else View.VISIBLE,
      )
      views.setTextViewText(R.id.widget_sub, sub)

      val uri = Uri.parse(if (drawingId != null) "duo://drawing/$drawingId" else "duo://home")
      views.setOnClickPendingIntent(
          R.id.widget_root,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
      )

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
