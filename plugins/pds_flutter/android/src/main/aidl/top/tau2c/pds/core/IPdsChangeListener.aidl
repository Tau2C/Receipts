package top.tau2c.pds.core;

/**
 * Callback interface for receiving real-time PDS storage change notifications.
 */
interface IPdsChangeListener {
    /**
     * Called when entities are inserted, modified, or deleted.
     * changeEventsJson is a JSON array string of change events.
     */
    oneway void onChanges(String changeEventsJson);
}
