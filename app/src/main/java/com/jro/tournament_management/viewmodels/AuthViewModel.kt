package com.jro.tournament_management.viewmodels

import android.content.Context
import androidx.lifecycle.ViewModel
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

class AuthViewModel : ViewModel() {
    val CLIENT_ID = "77372019755-vj6ak16sp30gsi5rc5ffmtfj1c0oqm58.apps.googleusercontent.com"


    // Création d'un flux mutable pour représenter l'état de l'authentification
    private val _isUserLoggedIn = MutableStateFlow(false)
    val isUserLoggedIn: Flow<Boolean> = _isUserLoggedIn

    // Méthode pour mettre à jour l'état de l'authentification
    fun isConnected(): Boolean {
        // Logique pour vérifier si l'utilisateur est connecté
        val user = FirebaseAuth.getInstance().currentUser
        _isUserLoggedIn.value = (user != null)
        return _isUserLoggedIn.value
    }

    fun getIdToken() = FirebaseAuth.getInstance().currentUser?.getIdToken(true)?.result?.token


    fun getGoogleSignInClient(context: Context): GoogleSignInClient {
        val signInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(CLIENT_ID)
            .build()

        return GoogleSignIn.getClient(context, signInOptions)
    }
}


