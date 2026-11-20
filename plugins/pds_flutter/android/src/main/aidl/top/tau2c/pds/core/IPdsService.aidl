package top.tau2c.pds.core;

import top.tau2c.pds.core.IPdsChangeListener;

/**
 * Android Binder IPC interface for Personal Data Store (PDS).
 * Enables third-party Android applications to communicate with the centralized
 * PDS Core background service.
 */
interface IPdsService {
    /**
     * Executes a PDS IPC JSON request (IpcRequest) and returns the JSON response (IpcResponse).
     */
    String executeRequest(String requestJson);

    /**
     * Registers a new client application with its Ed25519 public key.
     * Returns the assigned ClientId (ULID).
     */
    String registerClient(String clientName, in byte[] publicKey);

    /**
     * Approves client permissions.
     */
    boolean approveClient(String clientId, String permissionsJson);

    /**
     * Checks if PDS Core storage engine is initialized and ready.
     */
    boolean isReady();

    /**
     * Subscribes to real-time storage changes.
     * filterJson: e.g. '{"entity_type": "notes"}' or '{"entity_type": "*"}'.
     */
    void registerChangeListener(String filterJson, IPdsChangeListener listener);

    /**
     * Unsubscribes from storage changes.
     */
    void unregisterChangeListener(IPdsChangeListener listener);
}
