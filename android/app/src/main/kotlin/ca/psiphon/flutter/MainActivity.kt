package ca.psiphon.flutter

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "ca.psiphon.flutter/vpn"
        private const val EVENT_CHANNEL = "ca.psiphon.flutter/events"
        private const val REQ_VPN_PERMISSION = 7001
        private const val REQ_NOTIFICATION_PERMISSION = 7002
    }

    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingStartArgs: Map<String, Any?>? = null

    private var stateListener: ((Map<String, Any?>) -> Unit)? = null
    private var logListener: ((String) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return
                    val sListener: (Map<String, Any?>) -> Unit = { map ->
                        events.success(mapOf("type" to "state", "data" to map))
                    }
                    val lListener: (String) -> Unit = { line ->
                        events.success(mapOf("type" to "log", "line" to line))
                    }
                    stateListener = sListener
                    logListener = lListener
                    TunnelState.addStateListener(sListener)
                    TunnelState.addLogListener(lListener)
                    events.success(mapOf("type" to "snapshot", "data" to TunnelState.snapshot()))
                }

                override fun onCancel(arguments: Any?) {
                    stateListener?.let { TunnelState.removeStateListener(it) }
                    logListener?.let { TunnelState.removeLogListener(it) }
                    stateListener = null
                    logListener = null
                }
            })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                requestNotificationsIfNeeded()
                val prepareIntent = VpnService.prepare(this)
                if (prepareIntent != null) {
                    pendingStartResult?.error("CANCELLED", "Superseded by newer start request", null)
                    pendingStartResult = result
                    pendingStartArgs = args
                    @Suppress("DEPRECATION")
                    startActivityForResult(prepareIntent, REQ_VPN_PERMISSION)
                } else {
                    dispatchServiceAction(PsiphonVpnService.ACTION_START, args)
                    result.success(true)
                }
            }
            "restartVpn" -> {
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                dispatchServiceAction(PsiphonVpnService.ACTION_RESTART, args)
                result.success(true)
            }
            "stopVpn" -> {
                val intent = Intent(this, PsiphonVpnService::class.java).apply {
                    action = PsiphonVpnService.ACTION_STOP
                }
                startService(intent)
                result.success(true)
            }
            "getState" -> {
                result.success(TunnelState.snapshot())
            }
            "clearLogs" -> {
                TunnelState.clearLogs()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun dispatchServiceAction(actionName: String, args: Map<String, Any?>) {
        val region = (args["region"] as? String) ?: ""
        val protocol = (args["protocol"] as? String) ?: "AUTO"
        val upstreamProxy = (args["upstreamProxyUrl"] as? String) ?: ""

        val intent = Intent(this, PsiphonVpnService::class.java).apply {
            action = actionName
            putExtra(PsiphonVpnService.EXTRA_REGION, region)
            putExtra(PsiphonVpnService.EXTRA_PROTOCOL, protocol)
            putExtra(PsiphonVpnService.EXTRA_UPSTREAM_PROXY, upstreamProxy)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && actionName != PsiphonVpnService.ACTION_STOP) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun requestNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATION_PERMISSION)
            }
        }
    }

    @Deprecated("Required for VpnService.prepare system consent result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_VPN_PERMISSION) {
            val result = pendingStartResult
            val args = pendingStartArgs ?: emptyMap()
            pendingStartResult = null
            pendingStartArgs = null
            if (resultCode == RESULT_OK) {
                dispatchServiceAction(PsiphonVpnService.ACTION_START, args)
                result?.success(true)
            } else {
                result?.success(false)
            }
        }
    }
}
