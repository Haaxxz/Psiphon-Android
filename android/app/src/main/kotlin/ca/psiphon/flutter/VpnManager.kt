package ca.psiphon.flutter

import android.net.VpnService
import android.os.ParcelFileDescriptor
import ca.psiphon.Tun2SocksJniLoader
import java.io.IOException
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages the Android TUN interface lifecycle and badvpn tun2socks native loop.
 */
class VpnManager {
    private data class PrivateSubnet(
        val ipAddress: String,
        val routerAddress: String,
        val netmask: String,
        val prefixLength: Int
    )

    companion object {
        private const val VPN_MTU = 1500
        private const val UDPGW_SERVER_ADDRESS = "127.0.0.1:7300"

        private val SUBNET_CANDIDATES = listOf(
            PrivateSubnet("10.0.0.2", "10.0.0.1", "255.255.255.0", 24),
            PrivateSubnet("192.168.0.2", "192.168.0.1", "255.255.255.0", 24),
            PrivateSubnet("192.168.100.2", "192.168.100.1", "255.255.255.0", 24),
            PrivateSubnet("172.16.0.2", "172.16.0.1", "255.255.255.0", 24),
            PrivateSubnet("10.111.222.2", "10.111.222.1", "255.255.255.0", 24)
        )

        @JvmStatic
        fun logTun2Socks(level: String?, channel: String?, msg: String?) {
            if (level == "DEBUG") return
            val line = "tun2socks [${level ?: "INFO"}/${channel ?: "core"}]: ${msg ?: ""}"
            TunnelState.appendLog(line)
        }
    }

    @Volatile
    private var tunInterface: ParcelFileDescriptor? = null

    @Volatile
    private var activeSubnet: PrivateSubnet = SUBNET_CANDIDATES.first()

    @Volatile
    private var tun2SocksThread: Thread? = null

    private val isRouting = AtomicBoolean(false)

    @Synchronized
    fun vpnEstablish(service: VpnService) {
        if (tunInterface != null) {
            return
        }
        val subnet = pickUnusedSubnet()
        activeSubnet = subnet

        val builder = service.Builder()
            .setSession("Psiphon")
            .setMtu(VPN_MTU)
            .addAddress(subnet.ipAddress, subnet.prefixLength)
            .addRoute("0.0.0.0", 0)
            .addDnsServer(subnet.routerAddress)

        try {
            builder.addDisallowedApplication(service.packageName)
        } catch (e: Exception) {
            TunnelState.appendLog("VPN notice: addDisallowedApplication skipped (${e.message})")
        }

        val established = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null")
        tunInterface = established
        TunnelState.appendLog("VPN TUN interface established (${subnet.ipAddress}/${subnet.prefixLength})")
    }

    @Synchronized
    fun routeThroughTunnel(socksPort: Int) {
        val pfd = tunInterface ?: return
        if (socksPort <= 0) return

        stopRouteThroughTunnel()

        val subnet = activeSubnet
        Tun2SocksJniLoader.initializeLogger(VpnManager::class.java.name, "logTun2Socks")
        isRouting.set(true)

        val thread = Thread({
            try {
                Tun2SocksJniLoader.runTun2Socks(
                    pfd.fd,
                    VPN_MTU,
                    subnet.ipAddress,
                    subnet.netmask,
                    null,
                    "127.0.0.1:$socksPort",
                    UDPGW_SERVER_ADDRESS,
                    1
                )
            } catch (t: Throwable) {
                TunnelState.appendLog("tun2socks error: ${t.message}")
            } finally {
                isRouting.set(false)
            }
        }, "psiphon-tun2socks").apply {
            isDaemon = true
            start()
        }
        tun2SocksThread = thread
        TunnelState.appendLog("Routing device traffic via SOCKS5 127.0.0.1:$socksPort")
    }

    @Synchronized
    fun stopRouteThroughTunnel() {
        val thread = tun2SocksThread ?: return
        if (isRouting.get()) {
            try {
                Tun2SocksJniLoader.terminateTun2Socks()
            } catch (t: Throwable) {
                TunnelState.appendLog("terminateTun2Socks warning: ${t.message}")
            }
        }
        try {
            thread.join(1500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        tun2SocksThread = null
        isRouting.set(false)
    }

    @Synchronized
    fun vpnTeardown() {
        stopRouteThroughTunnel()
        val pfd = tunInterface
        tunInterface = null
        if (pfd != null) {
            try {
                pfd.close()
            } catch (_: IOException) {
            }
            TunnelState.appendLog("VPN TUN interface closed")
        }
    }

    private fun pickUnusedSubnet(): PrivateSubnet {
        val usedPrefixes = HashSet<String>()
        try {
            val ifaces = NetworkInterface.getNetworkInterfaces()
            while (ifaces != null && ifaces.hasMoreElements()) {
                val iface = ifaces.nextElement()
                val addrs = iface.inetAddresses
                while (addrs.hasMoreElements()) {
                    val addr = addrs.nextElement()
                    if (addr is Inet4Address && !addr.isLoopbackAddress) {
                        val host = addr.hostAddress ?: continue
                        val parts = host.split('.')
                        if (parts.size == 4) {
                            usedPrefixes.add("${parts[0]}.${parts[1]}.${parts[2]}")
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }

        for (candidate in SUBNET_CANDIDATES) {
            val prefix = candidate.ipAddress.substringBeforeLast('.')
            if (!usedPrefixes.contains(prefix)) {
                return candidate
            }
        }
        return SUBNET_CANDIDATES.last()
    }
}
