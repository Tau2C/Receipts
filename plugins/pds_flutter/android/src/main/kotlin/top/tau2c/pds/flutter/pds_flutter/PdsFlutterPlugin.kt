package top.tau2c.pds.flutter.pds_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import top.tau2c.pds.client.PdsAndroidClient

/**
 * Android implementation of the PDS Flutter plugin bridging Flutter to PdsAndroidClient.
 */
class PdsFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var pdsClient: PdsAndroidClient? = null

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val changeListener = PdsAndroidClient.ChangeListener { changeEventsJson ->
        mainHandler.post {
            eventSink?.success(changeEventsJson)
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        pdsClient = PdsAndroidClient(context)

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "top.tau2c.pds/client")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "top.tau2c.pds/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val client = pdsClient ?: run {
            result.error("NOT_INITIALIZED", "PDS Client is not initialized", null)
            return
        }

        when (call.method) {
            "connect" -> {
                try {
                    val connected = client.connect()
                    result.success(connected)
                } catch (e: Exception) {
                    result.error("CONNECT_ERROR", e.message, null)
                }
            }
            "disconnect" -> {
                try {
                    client.disconnect()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("DISCONNECT_ERROR", e.message, null)
                }
            }
            "isConnected" -> {
                result.success(client.isConnected())
            }
            "isReady" -> {
                result.success(client.isReady())
            }
            "executeRawRequest" -> {
                val requestJson = call.argument<String>("requestJson")
                if (requestJson == null) {
                    result.error("INVALID_ARGUMENT", "requestJson must not be null", null)
                    return
                }
                try {
                    val responseJson = client.executeRawRequest(requestJson)
                    result.success(responseJson)
                } catch (e: Exception) {
                    result.error("EXECUTE_ERROR", e.message, null)
                }
            }
            "register" -> {
                val clientName = call.argument<String>("clientName")
                val publicKey = call.argument<ByteArray>("publicKey")
                if (clientName == null || publicKey == null) {
                    result.error("INVALID_ARGUMENT", "clientName and publicKey are required", null)
                    return
                }
                try {
                    val clientId = client.register(clientName, publicKey)
                    result.success(clientId)
                } catch (e: Exception) {
                    result.error("REGISTER_ERROR", e.message, null)
                }
            }
            "getPendingChanges" -> {
                val sessionId = call.argument<String>("sessionId")
                val limit = call.argument<Int>("limit")
                if (sessionId == null) {
                    result.error("INVALID_ARGUMENT", "sessionId must not be null", null)
                    return
                }
                try {
                    val pendingJson = client.getPendingChanges(sessionId, limit)
                    result.success(pendingJson)
                } catch (e: Exception) {
                    result.error("PENDING_CHANGES_ERROR", e.message, null)
                }
            }
            "acknowledgeChanges" -> {
                val sessionId = call.argument<String>("sessionId")
                val changeId = call.argument<String>("changeId")
                if (sessionId == null || changeId == null) {
                    result.error("INVALID_ARGUMENT", "sessionId and changeId are required", null)
                    return
                }
                try {
                    val ackJson = client.acknowledgeChanges(sessionId, changeId)
                    result.success(ackJson)
                } catch (e: Exception) {
                    result.error("ACK_ERROR", e.message, null)
                }
            }
            "getClientCursor" -> {
                val sessionId = call.argument<String>("sessionId")
                if (sessionId == null) {
                    result.error("INVALID_ARGUMENT", "sessionId must not be null", null)
                    return
                }
                try {
                    val cursorJson = client.getClientCursor(sessionId)
                    result.success(cursorJson)
                } catch (e: Exception) {
                    result.error("CURSOR_ERROR", e.message, null)
                }
            }
            "isPdsInstalled" -> {
                result.success(client.isPdsInstalled())
            }
            "installPdsApk" -> {
                val apkUriString = call.argument<String>("apkUriString")
                if (apkUriString == null) {
                    result.error("INVALID_ARGUMENT", "apkUriString must not be null", null)
                    return
                }
                result.success(client.installPdsApk(apkUriString))
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val entityType = (arguments as? Map<*, *>)?.get("entityType") as? String ?: "*"
        try {
            pdsClient?.subscribe(entityType, changeListener)
        } catch (_: Exception) {}
    }

    override fun onCancel(arguments: Any?) {
        try {
            pdsClient?.unsubscribe(changeListener)
        } catch (_: Exception) {}
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        pdsClient?.disconnect()
        pdsClient = null
    }
}
