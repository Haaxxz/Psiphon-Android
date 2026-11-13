package ca.psiphon.flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import ca.psiphon.PsiphonTunnel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.ArrayDeque
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern

/**
 * Shared thread-safe observable tunnel state pushed to Flutter via EventChannel.
 */
object TunnelState {
    private const val MAX_LOG_LINES = 300

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    private val logListeners = CopyOnWriteArraySet<(String) -> Unit>()
    private val logsLock = Any()
    private val logsBuffer = ArrayDeque<String>(MAX_LOG_LINES)

    @Volatile var status: String = "disconnected"
    @Volatile var selectedRegion: String = ""
    @Volatile var connectedRegion: String = ""
    @Volatile var clientRegion: String = ""
    @Volatile var availableRegions: List<String> = emptyList()
    @Volatile var activeProtocol: String = ""
    @Volatile var preferredProtocol: String = "AUTO"
    @Volatile var upstreamProxyUrl: String = ""
    @Volatile var bytesSent: Long = 0L
    @Volatile var bytesReceived: Long = 0L
    @Volatile var upSpeedBps: Long = 0L
    @Volatile var downSpeedBps: Long = 0L
    @Volatile var connectedSinceMs: Long = 0L
    @Volatile var lastError: String? = null

    fun addStateListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.add(listener)
    }

    fun removeStateListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.remove(listener)
    }

    fun addLogListener(listener: (String) -> Unit) {
        logListeners.add(listener)
    }

    fun removeLogListener(listener: (String) -> Unit) {
        logListeners.remove(listener)
    }

    fun snapshot(): Map<String, Any?> {
        val logsCopy: List<String> = synchronized(logsLock) { logsBuffer.toList() }
        return mapOf(
            "status" to status,
            "selectedRegion" to selectedRegion,
            "connectedRegion" to connectedRegion,
            "clientRegion" to clientRegion,
            "availableRegions" to availableRegions,
            "activeProtocol" to activeProtocol,
            "preferredProtocol" to preferredProtocol,
            "upstreamProxyUrl" to upstreamProxyUrl,
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived,
            "upSpeedBps" to upSpeedBps,
            "downSpeedBps" to downSpeedBps,
            "connectedSinceMs" to connectedSinceMs,
            "lastError" to lastError,
            "logs" to logsCopy
        )
    }

    fun emitState() {
        val data = snapshotWithoutLogs()
        mainHandler.post {
            for (listener in listeners) {
                listener(data)
            }
        }
    }

    fun appendLog(raw: String) {
        val clean = sanitizeDiagnostic(raw)
        if (clean.isEmpty()) return
        synchronized(logsLock) {
            if (logsBuffer.size >= MAX_LOG_LINES) {
                logsBuffer.removeFirst()
            }
            logsBuffer.addLast(clean)
        }
        mainHandler.post {
            for (listener in logListeners) {
                listener(clean)
            }
        }
    }

    fun clearLogs() {
        synchronized(logsLock) {
            logsBuffer.clear()
        }
        emitState()
    }

    fun resetSessionStats() {
        bytesSent = 0L
        bytesReceived = 0L
        upSpeedBps = 0L
        downSpeedBps = 0L
        connectedSinceMs = 0L
        connectedRegion = ""
        activeProtocol = ""
        lastError = null
    }

    private fun snapshotWithoutLogs(): Map<String, Any?> = mapOf(
        "status" to status,
        "selectedRegion" to selectedRegion,
        "connectedRegion" to connectedRegion,
        "clientRegion" to clientRegion,
        "availableRegions" to availableRegions,
        "activeProtocol" to activeProtocol,
        "preferredProtocol" to preferredProtocol,
        "upstreamProxyUrl" to upstreamProxyUrl,
        "bytesSent" to bytesSent,
        "bytesReceived" to bytesReceived,
        "upSpeedBps" to upSpeedBps,
        "downSpeedBps" to downSpeedBps,
        "connectedSinceMs" to connectedSinceMs,
        "lastError" to lastError
    )

    private fun sanitizeDiagnostic(msg: String): String {
        val trimmed = msg.trim()
        if (trimmed.contains("missing public key")) {
            return "Bootstrap roster: loaded embedded servers"
        }
        return trimmed
    }
}

/**
 * Android VpnService hosting ca.psiphon.PsiphonTunnel with full region selection unlocked.
 */
class PsiphonVpnService : VpnService(), PsiphonTunnel.HostService {

    companion object {
        const val ACTION_START = "ca.psiphon.flutter.ACTION_START"
        const val ACTION_STOP = "ca.psiphon.flutter.ACTION_STOP"
        const val ACTION_RESTART = "ca.psiphon.flutter.ACTION_RESTART"

        const val EXTRA_REGION = "region"
        const val EXTRA_PROTOCOL = "protocol"
        const val EXTRA_UPSTREAM_PROXY = "upstream_proxy"

        private const val NOTIFICATION_CHANNEL_ID = "psiphon_vpn_channel"
        private const val NOTIFICATION_ID = 4101
        private const val BOOTSTRAP_ASSET = "server_list.hex"

        private val PROTOCOL_PATTERN = Pattern.compile(
            """\b((?:UNFRONTED|FRONTED)-MEEK-(?:OSSH|SSH)|INPROXY-WEBRTC-OSSH|QUIC-OSSH|TLSHANDSHAKE-OSSH|OSSH|SSH)\b"""
        )
    }

    private val vpnManager = VpnManager()
    private val isRunning = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var tunnel: PsiphonTunnel? = null
    @Volatile private var stopLatch: CountDownLatch? = null
    @Volatile private var tunnelThread: Thread? = null
    @Volatile private var localSocksPort: Int = 0
    @Volatile private var isConnectedFlag: Boolean = false
    @Volatile private var lastBytesSampleMs: Long = 0L

    private val speedDecayRunnable = object : Runnable {
        override fun run() {
            if (!isRunning.get()) return
            val elapsed = System.currentTimeMillis() - lastBytesSampleMs
            if (elapsed > 2200L && (TunnelState.upSpeedBps > 0L || TunnelState.downSpeedBps > 0L)) {
                TunnelState.upSpeedBps = 0L
                TunnelState.downSpeedBps = 0L
                TunnelState.emitState()
            }
            mainHandler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? {
        val action = intent?.action
        if (action == SERVICE_INTERFACE) {
            return super.onBind(intent)
        }
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            ACTION_RESTART -> {
                applyIntentConfig(intent)
                if (isRunning.get()) {
                    restartTunnelInPlace()
                    return START_STICKY
                }
            }
            else -> {
                applyIntentConfig(intent)
            }
        }

        startForegroundCompat("Connecting to Psiphon...")
        startTunnelIfNeeded()
        return START_STICKY
    }

    override fun onRevoke() {
        TunnelState.appendLog("VPN permission revoked by system")
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        mainHandler.removeCallbacks(speedDecayRunnable)
        super.onDestroy()
    }

    private fun applyIntentConfig(intent: Intent?) {
        if (intent == null) return
        if (intent.hasExtra(EXTRA_REGION)) {
            TunnelState.selectedRegion = (intent.getStringExtra(EXTRA_REGION) ?: "").uppercase()
        }
        if (intent.hasExtra(EXTRA_PROTOCOL)) {
            TunnelState.preferredProtocol = intent.getStringExtra(EXTRA_PROTOCOL) ?: "AUTO"
        }
        if (intent.hasExtra(EXTRA_UPSTREAM_PROXY)) {
            TunnelState.upstreamProxyUrl = intent.getStringExtra(EXTRA_UPSTREAM_PROXY) ?: ""
        }
    }

    private fun startTunnelIfNeeded() {
        if (!isRunning.compareAndSet(false, true)) {
            return
        }

        TunnelState.resetSessionStats()
        TunnelState.status = "connecting"
        TunnelState.emitState()
        lastBytesSampleMs = System.currentTimeMillis()
        mainHandler.postDelayed(speedDecayRunnable, 1000L)

        val latch = CountDownLatch(1)
        stopLatch = latch

        tunnelThread = Thread({
            var psiphonTunnel: PsiphonTunnel? = null
            try {
                vpnManager.vpnEstablish(this)
                val entries = loadBootstrapServerEntries()
                TunnelState.appendLog("Loaded bootstrap server entries (${entries.lines().count { it.isNotBlank() }} servers)")

                psiphonTunnel = PsiphonTunnel.newPsiphonTunnel(this).also {
                    tunnel = it
                    it.setVpnMode(true)
                    it.startTunneling(entries)
                }

                latch.await()
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            } catch (t: Throwable) {
                val msg = t.message ?: t.javaClass.simpleName
                TunnelState.lastError = msg
                TunnelState.appendLog("Tunnel failed: $msg")
            } finally {
                isConnectedFlag = false
                localSocksPort = 0
                TunnelState.status = "disconnecting"
                TunnelState.emitState()

                vpnManager.vpnTeardown()
                try {
                    psiphonTunnel?.stop()
                } catch (_: Throwable) {
                }
                tunnel = null
                stopLatch = null
                isRunning.set(false)
                mainHandler.removeCallbacks(speedDecayRunnable)

                TunnelState.upSpeedBps = 0L
                TunnelState.downSpeedBps = 0L
                TunnelState.connectedSinceMs = 0L
                TunnelState.status = "disconnected"
                TunnelState.emitState()

                stopForegroundCompat()
                stopSelf()
            }
        }, "psiphon-tunnel-runner").apply {
            isDaemon = true
            start()
        }
    }

    private fun restartTunnelInPlace() {
        val activeTunnel = tunnel ?: return
        isConnectedFlag = false
        vpnManager.stopRouteThroughTunnel()
        TunnelState.connectedRegion = ""
        TunnelState.activeProtocol = ""
        TunnelState.connectedSinceMs = 0L
        TunnelState.status = "connecting"
        TunnelState.emitState()
        updateNotification("Switching region...")

        Thread({
            try {
                activeTunnel.restartPsiphon()
            } catch (t: Throwable) {
                TunnelState.lastError = t.message
                TunnelState.appendLog("Restart failed: ${t.message}")
            }
        }, "psiphon-restart").start()
    }

    private fun stopVpn() {
        if (!isRunning.get()) {
            stopForegroundCompat()
            stopSelf()
            return
        }
        TunnelState.status = "disconnecting"
        TunnelState.emitState()
        updateNotification("Disconnecting...")
        stopLatch?.countDown()
    }

    private fun loadBootstrapServerEntries(): String {
        return assets.open(BOOTSTRAP_ASSET).use { stream ->
            BufferedReader(InputStreamReader(stream)).use { it.readText() }
        }
    }

    // ---- PsiphonTunnel.HostService implementation ----

    override fun getContext(): Context = applicationContext

    override fun getPsiphonConfig(): String {
        val dataRoot = File(filesDir, "psiphon").apply { mkdirs() }.absolutePath
        val cfg = JSONObject().apply {
            put("PropagationChannelId", "FFFFFFFFFFFFFFFF")
            put("SponsorId", "FFFFFFFFFFFFFFFF")
            put("ClientVersion", "1")
            put("EgressRegion", TunnelState.selectedRegion)
            put("EmitDiagnosticNotices", true)
            put("EmitBytesTransferred", true)
            put("UseIndistinguishableTLS", true)
            put("EstablishTunnelTimeoutSeconds", 0)
            put(
                "DNSResolverAlternateServers",
                JSONArray(listOf("1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"))
            )
            put("DataRootDirectory", dataRoot)

            val preferredProto = TunnelState.preferredProtocol
            if (preferredProto.isNotEmpty() && preferredProto != "AUTO") {
                put("TunnelProtocol", preferredProto)
            }
            val upstream = TunnelState.upstreamProxyUrl.trim()
            if (upstream.isNotEmpty()) {
                put("UpstreamProxyUrl", upstream)
            }
        }
        return cfg.toString()
    }

    override fun bindToDevice(fileDescriptor: Long) {
        if (!protect(fileDescriptor.toInt())) {
            throw PsiphonTunnel.Exception("VpnService.protect($fileDescriptor) failed")
        }
    }

    override fun onAvailableEgressRegions(regions: MutableList<String>) {
        TunnelState.availableRegions = regions.map { it.uppercase() }.distinct().sorted()
        TunnelState.emitState()
        TunnelState.appendLog("Server regions reported: ${TunnelState.availableRegions.joinToString(", ")}")
    }

    override fun onListeningSocksProxyPort(port: Int) {
        localSocksPort = port
        TunnelState.appendLog("Local SOCKS5 proxy listening on 127.0.0.1:$port")
        if (isConnectedFlag) {
            vpnManager.routeThroughTunnel(port)
        }
    }

    override fun onConnecting() {
        isConnectedFlag = false
        TunnelState.status = "connecting"
        TunnelState.emitState()
        updateNotification(
            if (TunnelState.selectedRegion.isEmpty()) "Connecting (Best Performance)..."
            else "Connecting to ${TunnelState.selectedRegion}..."
        )
    }

    override fun onConnected() {
        isConnectedFlag = true
        val port = localSocksPort
        if (port > 0) {
            vpnManager.routeThroughTunnel(port)
        }
        TunnelState.status = "connected"
        if (TunnelState.connectedSinceMs == 0L) {
            TunnelState.connectedSinceMs = System.currentTimeMillis()
        }
        TunnelState.lastError = null
        TunnelState.emitState()

        val labelRegion = TunnelState.connectedRegion.ifEmpty {
            TunnelState.selectedRegion.ifEmpty { "Auto" }
        }
        updateNotification("Connected ($labelRegion)")
        TunnelState.appendLog("Tunnel connected ($labelRegion)")
    }

    override fun onConnectedServerRegion(region: String) {
        TunnelState.connectedRegion = region.uppercase()
        TunnelState.emitState()
        if (isConnectedFlag) {
            updateNotification("Connected (${TunnelState.connectedRegion})")
        }
    }

    override fun onClientRegion(region: String) {
        TunnelState.clientRegion = region.uppercase()
        TunnelState.emitState()
    }

    override fun onBytesTransferred(sent: Long, received: Long) {
        val now = System.currentTimeMillis()
        val elapsedMs = (now - lastBytesSampleMs).coerceAtLeast(250L)
        lastBytesSampleMs = now

        TunnelState.bytesSent += sent
        TunnelState.bytesReceived += received
        TunnelState.upSpeedBps = (sent * 1000L) / elapsedMs
        TunnelState.downSpeedBps = (received * 1000L) / elapsedMs
        TunnelState.emitState()
    }

    override fun onUpstreamProxyError(message: String) {
        TunnelState.lastError = "Upstream proxy: $message"
        TunnelState.appendLog("Upstream proxy error: $message")
        TunnelState.emitState()
    }

    override fun onDiagnosticMessage(message: String) {
        val matcher = PROTOCOL_PATTERN.matcher(message)
        if (matcher.find()) {
            val foundProto = matcher.group(1)
            if (!foundProto.isNullOrEmpty() && foundProto != TunnelState.activeProtocol) {
                TunnelState.activeProtocol = foundProto
                TunnelState.emitState()
            }
        }
        TunnelState.appendLog(message)
    }

    override fun onExiting() {
        isConnectedFlag = false
        stopLatch?.countDown()
    }

    // ---- Notification helpers ----

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Psiphon VPN Tunnel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent status for the active Psiphon VPN connection"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentPi = PendingIntent.getActivity(this, 1, openAppIntent, piFlags)

        val stopIntent = Intent(this, PsiphonVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(this, 2, stopIntent, piFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val disconnectAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_stat_psiphon),
                "Disconnect",
                stopPi
            ).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(
                R.drawable.ic_stat_psiphon,
                "Disconnect",
                stopPi
            ).build()
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_psiphon)
            .setContentTitle("Psiphon")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPi)
            .addAction(disconnectAction)

        return builder.build()
    }

    private fun startForegroundCompat(text: String) {
        val notif = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notif)
        }
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
