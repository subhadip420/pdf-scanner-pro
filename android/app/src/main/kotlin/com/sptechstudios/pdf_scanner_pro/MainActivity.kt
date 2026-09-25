package com.sptechstudios.pdf_scanner_pro

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity // Notice: FragmentActivity use kiya hai

class MainActivity : FlutterFragmentActivity() { // Notice: Yahan bhi FragmentActivity
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}