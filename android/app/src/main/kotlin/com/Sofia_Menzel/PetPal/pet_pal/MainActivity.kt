package com.Sofia_Menzel.PetPal.pet_pal

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (y no FlutterActivity) es obligatorio para que el
// plugin local_auth pueda mostrar el diálogo de BiometricPrompt; con
// FlutterActivity lanza MissingFragmentActivity y la autenticación falla.
class MainActivity : FlutterFragmentActivity()
