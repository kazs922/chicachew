package com.example.chicachew

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var mpTasks: MpTasks? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mpTasks = MpTasks(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
