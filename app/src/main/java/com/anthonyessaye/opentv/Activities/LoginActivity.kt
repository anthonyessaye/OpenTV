package com.anthonyessaye.opentv.Activities

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.RelativeLayout
import android.widget.Toast
import androidx.activity.ComponentActivity
import com.anthonyessaye.opentv.Builders.XtreamBuilder
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.REST.RESTHandler

class LoginActivity : ComponentActivity() {
    private lateinit var editTextProfileName: EditText
    private lateinit var editTextUserName: EditText
    private lateinit var editTextPassword: EditText
    private lateinit var editTextServerURL: EditText
    private lateinit var btnLogin: Button
    private lateinit var viewLottie: RelativeLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        editTextProfileName = findViewById(R.id.editTextProfileName)
        editTextUserName = findViewById(R.id.editTextUserName)
        editTextPassword = findViewById(R.id.editTextPassword)
        editTextServerURL = findViewById(R.id.editTextServerURL)
        btnLogin = findViewById(R.id.btnLogin)
        viewLottie = findViewById(R.id.viewLottie)

        btnLogin.setOnClickListener {
            val profileName = editTextProfileName.text.toString()
            val userName = editTextUserName.text.toString()
            val password = editTextPassword.text.toString()
            val hostURL = editTextServerURL.text.toString()

            if (profileName.isNotBlank() &&
                userName.isNotBlank() &&
                password.isNotBlank() &&
                hostURL.isNotBlank()) {
                val xtream = XtreamBuilder(userName, password, hostURL)

                runOnUiThread {
                    viewLottie.visibility = View.VISIBLE
                    RESTHandler.UserREST.getUserAndServerInfo(xtream) { user_info, server_info ->
                        viewLottie.visibility = View.GONE
                        if (user_info != null && server_info != null) {
                            DatabaseManager().openDatabase(applicationContext) { databaseManager ->
                                databaseManager.userDao().insertAll(user_info)
                                databaseManager.serverDao().insertAll(server_info)

                                val intent = Intent(this, CachingActivity::class.java)
                                startActivity(intent)
                            }
                        }

                        else {
                            Toast.makeText(this,
                                getString(R.string.something_went_wrong_cannot_login), Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }

            else {
                Toast.makeText(this, getString(R.string.one_or_more_fields_are_empty_cannot_login), Toast.LENGTH_LONG).show()
            }
        }

    }

    override fun onBackPressed() {
        if(viewLottie.visibility == View.GONE)
            super.onBackPressed()
    }
}
