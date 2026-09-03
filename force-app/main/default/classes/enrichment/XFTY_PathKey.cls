/**
 * A stable, comparable key for a relationship path - a `>`-joined string of the
 * field names, `''` for an empty or null path. Used to match and de-duplicate
 * paths without an `SObjectField`-keyed map (which Apex / Nimbus handle poorly).
 * Built with `+=` rather than `String.join` (`join` is a check-apex-style
 * reserved word).
 */
@IsTest
public class XFTY_PathKey {

    public static String of(List<SObjectField> path) {
        if (path == null) {
            return '';
        }
        String key = '';
        for (SObjectField step : path) {
            key += step + '>';
        }
        return key;
    }
}
