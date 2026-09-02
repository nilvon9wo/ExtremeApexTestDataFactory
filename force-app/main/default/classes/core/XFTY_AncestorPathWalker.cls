/**
 * Reads one field several relationship hops up a generated ancestor graph,
 * without the caller holding on to every intermediate bundle and list.
 *
 * `path` is one or more relationship fields then the field to read. Each leading
 * relationship field is a `getBundle(...)` step down from the starting bundle;
 * the last relationship field selects the parent list, aligned 1:1 with the
 * starting bundle's primaries, and the final field is read off the parent at
 * `rowIndex`.
 *
 * Returns `null` when a hop was not generated (an optional relationship the
 * inclusivity skipped) or `rowIndex` is out of range. Only walks generated
 * ancestors - child relationships are not followed. Throws only when the path
 * itself is malformed.
 */
@IsTest
public class XFTY_AncestorPathWalker {

    public static Object read(XFTY_DummySObjectBundle source, List<SObjectField> path, Integer rowIndex) {
        rejectMalformed(path);
        XFTY_DummySObjectBundle owningBundle = descend(source, path);
        Boolean cannotRead = owningBundle == null
                || rowIndex == null
                || rowIndex < 0;
        if (cannotRead) {
            return null;
        }
        return valueAt(owningBundle, path, rowIndex);
    }

    private static XFTY_DummySObjectBundle descend(XFTY_DummySObjectBundle source, List<SObjectField> path) {
        XFTY_DummySObjectBundle bundle = source;
        for (Integer hop = 0; hop < path.size() - 2; hop++) {
            bundle = (bundle == null)
                    ? null
                    : bundle.getBundle(path[hop]);
        }
        return bundle;
    }

    private static Object valueAt(
            XFTY_DummySObjectBundle owningBundle,
            List<SObjectField> path,
            Integer rowIndex
    ) {
        SObjectField lastRelationshipField = path[path.size() - 2];
        SObjectField fieldToRead = path[path.size() - 1];
        List<SObject> parents = owningBundle.getList(lastRelationshipField);
        Boolean noParentAtRow = parents == null
                || rowIndex >= parents.size()
                || parents[rowIndex] == null;
        if (noParentAtRow) {
            return null;
        }
        return parents[rowIndex].get(fieldToRead);
    }

    private static void rejectMalformed(List<SObjectField> path) {
        if (path == null || path.size() < 2) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'getValue needs a path of at least one relationship field then the field to read.'
            );
        }
        for (SObjectField step : path) {
            if (step == null) {
                throw new XFTY_DummySObjectFtyProviderException('getValue path steps cannot be null.');
            }
        }
    }
}
