package top.tau2c.pds.client

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import top.tau2c.pds.core.IPdsChangeListener
import top.tau2c.pds.core.IPdsService
import java.util.concurrent.CopyOnWriteArrayList

/**
 * High-level Android SDK client for integrating with the central PDS Core background service.
 */
class PdsAndroidClient(private val context: Context) {

    companion object {
        const val PDS_SERVICE_ACTION = "top.tau2c.pds.core.PDS_SERVICE"
        const val PDS_PACKAGE_NAME = "top.tau2c.pds.core"
    }

    private var pdsService: IPdsService? = null
    private var isBound = false

    fun interface ChangeListener {
        fun onChanges(changeEventsJson: String)
    }

    private class ListenerEntry(
        val listener: ChangeListener,
        val filterJson: String,
        val aidlCallback: IPdsChangeListener.Stub
    )

    private val activeSubscriptions = CopyOnWriteArrayList<ListenerEntry>()

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            pdsService = IPdsService.Stub.asInterface(service)
            isBound = true

            // Re-register active subscriptions after reconnect
            activeSubscriptions.forEach { entry ->
                try {
                    pdsService?.registerChangeListener(entry.filterJson, entry.aidlCallback)
                } catch (_: Exception) {}
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            pdsService = null
            isBound = false
        }
    }

    /**
     * Binds to the background PDS Core service.
     */
    fun connect(): Boolean {
        val intent = Intent(PDS_SERVICE_ACTION).apply {
            setPackage(PDS_PACKAGE_NAME)
        }
        isBound = context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        return isBound
    }

    /**
     * Unbinds from the PDS Core service.
     */
    fun disconnect() {
        if (isBound) {
            activeSubscriptions.forEach { entry ->
                try {
                    pdsService?.unregisterChangeListener(entry.aidlCallback)
                } catch (_: Exception) {}
            }
            context.unbindService(serviceConnection)
            isBound = false
            pdsService = null
        }
    }

    fun isConnected(): Boolean {
        return isBound && pdsService != null
    }

    /**
     * Sends a raw JSON request to PDS and returns the raw JSON response.
     */
    fun executeRawRequest(requestJson: String): String {
        val service = pdsService ?: throw IllegalStateException("PdsService is not connected")
        return service.executeRequest(requestJson)
    }

    /**
     * Registers this client application.
     */
    fun register(clientName: String, publicKey: ByteArray): String {
        val service = pdsService ?: throw IllegalStateException("PdsService is not connected")
        return service.registerClient(clientName, publicKey)
    }

    /**
     * Checks if PDS storage engine is ready.
     */
    fun isReady(): Boolean {
        return pdsService?.isReady ?: false
    }

    /**
     * Subscribes to real-time storage changes.
     * @param entityType Specific entity type to watch, or "*" for all entities.
     * @param listener Callback invoked when changes occur.
     */
    fun subscribe(entityType: String = "*", listener: ChangeListener) {
        val service = pdsService ?: throw IllegalStateException("PdsService is not connected")
        val filterJson = """{"entity_type":"$entityType"}"""
        val callback = object : IPdsChangeListener.Stub() {
            override fun onChanges(changeEventsJson: String?) {
                if (changeEventsJson != null) {
                    listener.onChanges(changeEventsJson)
                }
            }
        }
        val entry = ListenerEntry(listener, filterJson, callback)
        activeSubscriptions.add(entry)
        service.registerChangeListener(filterJson, callback)
    }

    /**
     * Unsubscribes a previously registered listener.
     */
    fun unsubscribe(listener: ChangeListener) {
        val entry = activeSubscriptions.firstOrNull { it.listener == listener } ?: return
        activeSubscriptions.remove(entry)
        try {
            pdsService?.unregisterChangeListener(entry.aidlCallback)
        } catch (_: Exception) {}
    }

    /**
     * Retrieves pending changes for an offline/reconnecting client session.
     */
    fun getPendingChanges(sessionId: String, limit: Int? = null): String {
        val limitJson = if (limit != null) ""","limit":$limit""" else ""
        val req = """{"action":"get_pending_changes","session_id":"$sessionId"$limitJson}"""
        return executeRawRequest(req)
    }

    /**
     * Acknowledges processed changes and advances durable client cursor.
     */
    fun acknowledgeChanges(sessionId: String, changeId: String): String {
        val req = """{"action":"acknowledge_changes","session_id":"$sessionId","change_id":"$changeId"}"""
        return executeRawRequest(req)
    }

    /**
     * Reads durable client cursor position.
     */
    fun getClientCursor(sessionId: String): String {
        val req = """{"action":"get_client_cursor","session_id":"$sessionId"}"""
        return executeRawRequest(req)
    }

    /**
     * Checks if PDS Core package is installed on the device.
     */
    fun isPdsInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo(PDS_PACKAGE_NAME, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun installPdsApk(apkUriString: String): Boolean {
        return try {
            val uri = android.net.Uri.parse(apkUriString)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
