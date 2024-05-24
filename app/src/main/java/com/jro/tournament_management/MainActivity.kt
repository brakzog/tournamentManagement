package com.jro.tournament_management

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Color.Companion.Black
import androidx.compose.ui.graphics.Color.Companion.White
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.common.api.ApiException
import com.jro.tournament_management.ui.theme.TournamentManagementTheme
import com.jro.tournament_management.viewmodels.AuthViewModel

class MainActivity : ComponentActivity() {


    @SuppressLint("UnusedMaterial3ScaffoldPaddingParameter")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TournamentManagementTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    LoginPage(
                        onGoogleSignInCompleted = { token -> navigateToHomePage() },
                        onError = {
                            Toast.makeText(
                                this,
                                getString(R.string.toast_error),
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    )
                }
            }
        }
    }

    private fun navigateToHomePage() {
        // Utilisez l'intent pour naviguer vers HomePage ou utilisez la navigation Jetpack Compose si vous l'avez configurée
        //   startActivity(Intent(this, HomePageActivity::class.java))
        startActivity(Intent(this, HomePageActivity::class.java))
    }


    @SuppressLint("UnusedMaterial3ScaffoldPaddingParameter")
    @Composable
    fun LoginPage(
        onGoogleSignInCompleted: (String) -> Unit,
        onError: () -> Unit,
    ) {
        val authViewModel = AuthViewModel()

        val isLoggedIn = authViewModel.isConnected()

        if (isLoggedIn) {
            onGoogleSignInCompleted(authViewModel.getIdToken()!!) // Envoyer le token si déjà connecté
            return
        }

        val context = LocalContext.current

        val authResultLauncher =
            rememberLauncherForActivityResult(
                contract =
                AuthResultContract(authViewModel.getGoogleSignInClient(context))
            ) {
                val test = try {
                    val account = it?.getResult(ApiException::class.java)
                    if (account == null) {
                        null
                    } else {
                        account.idToken!!
                    }
                } catch (e: ApiException) {
                    null
                }
                if (test == null)
                    onError()
                else {
                    onGoogleSignInCompleted(test)
                }
            }

        Scaffold(
            content = {
                Column(
                    Modifier
                        .fillMaxSize()
                        .background(color = White),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(R.string.welcome),
                        color = Black,
                        fontSize = 40.sp
                    )

                    Spacer(modifier = Modifier.height(40.dp))

                    Button(
                        onClick = { authResultLauncher.launch(1) },
                        modifier = Modifier
                            .width(300.dp)
                            .height(45.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(White),
                        elevation = ButtonDefaults.elevatedButtonElevation(10.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                painter = painterResource(id = R.drawable.ic_launcher_background),
                                contentDescription = "Google icon",
                                tint = Color.Unspecified,
                            )
                            Text(
                                text = "Access using Google",
                                color = Black,
                                fontWeight = FontWeight.W600,
                                fontSize = 16.sp,
                                modifier = Modifier.padding(start = 10.dp)
                            )
                        }
                    }
                }
            }
        )
    }
}




//Keep as sample
/*@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    TournamentManagementTheme {
        Greeting("Android")
    }
}*/