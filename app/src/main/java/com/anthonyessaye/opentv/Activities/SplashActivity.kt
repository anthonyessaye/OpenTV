package com.anthonyessaye.opentv.Activities

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.R

@SuppressLint("CustomSplashScreen")
class SplashActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)


        DatabaseManager().openDatabase(this) { db ->
            val allUsers = db.userDao().getAll()
            lateinit var intent: Intent

            if (allUsers.isEmpty()) {
                intent = Intent(this, LoginActivity::class.java)
            }

            else if (allUsers.count() == 1) {
                val user = allUsers.first()
                val auth = user.auth

                // This user is authenticated
                if (auth == 1) {
                    checkCache(this) { isCacheOkay ->
                        if (isCacheOkay)
                            intent = Intent(this, MainActivity::class.java)
                        else
                            intent = Intent(this, CachingActivity::class.java)
                    }
                }

                else
                    intent = Intent(this, LoginActivity::class.java)
            }

            // Go to a page to select user
            else {

            }

            // Yes I introduced an artificial delay, I like my splashscreen
            val pendingIntent: PendingIntent = PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE);

            val mgr: AlarmManager =  (this.getSystemService(ALARM_SERVICE)) as AlarmManager
            mgr.set(AlarmManager.RTC, 100, pendingIntent)
        }
    }

    fun checkCache(context: Context, completion: (isCacheOkay: Boolean) -> Unit) {
        DatabaseManager().openDatabase(context) { db ->
            val liveStreamCache = db.liveStreamDao().getAll()

            if (liveStreamCache.isEmpty())
                completion(false)

            completion(true)
        }
    }

}