// Only the callback type is needed by the production job observer.
public class SettingsDaemon.Utils.SysupdateTarget : Object {
    public delegate void ProgressCallback (string message, uint percentage);
}
