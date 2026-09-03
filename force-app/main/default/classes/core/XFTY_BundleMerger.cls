/**
 * Combines the sibling child bundles one relationship field can carry - one per
 * `XFTY_SObjectChildProvider` configured for it - into a single bundle: every
 * child across the configs as primaries, and each generated parent merged so the
 * whole collection navigates as one unit.
 *
 * Behaviour-preserving extraction of what `XFTY_DummySObjectBundle.getChildBundle`
 * needs when a field has more than one child config.
 */
@IsTest
public class XFTY_BundleMerger {

    public static XFTY_DummySObjectBundle combine(List<XFTY_DummySObjectBundle> bundles) {
        XFTY_DummySObjectBundle merged = new XFTY_DummySObjectBundle();
        for (XFTY_DummySObjectBundle each : bundles) {
            combineParentsInto(merged, each);
        }
        putMergedPrimaries(merged, bundles);
        return merged;
    }

    private static void combineParentsInto(XFTY_DummySObjectBundle merged, XFTY_DummySObjectBundle source) {
        for (SObjectField parentField : source.relationshipFields()) {
            XFTY_DummySObjectBundle soFar = merged.getBundle(parentField);
            XFTY_DummySObjectBundle incoming = source.getBundle(parentField);
            XFTY_DummySObjectBundle result = (soFar == null)
                    ? incoming
                    : combinedPrimaries(soFar, incoming);
            merged.put(parentField, result);
        }
    }

    private static XFTY_DummySObjectBundle combinedPrimaries(
            XFTY_DummySObjectBundle soFar,
            XFTY_DummySObjectBundle incoming
    ) {
        List<SObject> records = new List<SObject>(soFar.primaryRecords());
        records.addAll(incoming.primaryRecords());
        XFTY_DummySObjectBundle rebuilt = new XFTY_DummySObjectBundle();
        rebuilt.putPrimaries(incoming.primaryTargetField, records);
        return rebuilt;
    }

    private static void putMergedPrimaries(
            XFTY_DummySObjectBundle merged,
            List<XFTY_DummySObjectBundle> bundles
    ) {
        SObjectField primaryField = bundles[0].primaryTargetField;
        if (primaryField == null) {
            return;
        }
        List<SObject> allPrimaries = new List<SObject>();
        for (XFTY_DummySObjectBundle each : bundles) {
            List<SObject> primaries = each.primaryRecords();
            if (primaries != null) {
                allPrimaries.addAll(primaries);
            }
        }
        merged.putPrimaries(primaryField, allPrimaries);
    }
}
