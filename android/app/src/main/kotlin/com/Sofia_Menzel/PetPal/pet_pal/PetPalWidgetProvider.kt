package com.Sofia_Menzel.PetPal.pet_pal

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class PetPalWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget habilitado
    }

    override fun onDisabled(context: Context) {
        // Widget deshabilitado
    }

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.pet_pal_widget)
            
            // El contenido real se actualizará desde Flutter vía home_widget
            // Este es un placeholder básico
            views.setTextViewText(R.id.widget_text, "PetPal - Abre la app")
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
