/**
 * The up-flowing values a bundle's primaries still owe - one `(row, field,
 * strategy)` per primary row per deferred field. Collected while the bundle is
 * generated and drained during the `DEFERRED` flush, once the whole forest
 * exists and the descendants those values read from are real. A work order for a
 * later phase, kept apart from the graph shape the bundle holds.
 */
@IsTest
public class XFTY_DeferredValueQueue {

    private final List<Entry> entries = new List<Entry>();

    /** One primary row's field, still to be filled by an up-flow strategy. */
    public class Entry {
        public final Integer primaryRow;
        public final SObjectField field;
        public final XFTY_DeferredExpressionIntf strategy;

        public Entry(Integer primaryRow, SObjectField field, XFTY_DeferredExpressionIntf strategy) {
            this.primaryRow = primaryRow;
            this.field = field;
            this.strategy = strategy;
        }
    }

    /** Queue each `byField` entry for every one of `rowCount` primary rows. */
    public void addForEachRow(Integer rowCount, Map<SObjectField, XFTY_DeferredExpressionIntf> byField) {
        for (Integer row = 0; row < rowCount; row++) {
            for (SObjectField field : byField.keySet()) {
                this.entries.add(new Entry(row, field, byField.get(field)));
            }
        }
    }

    public List<Entry> entries() {
        return this.entries;
    }
}
