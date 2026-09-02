@IsTest
public class XFTY_DummySObjectBundle {
    private final Map<SObjectField, XFTY_DummySObjectBundle> sObjectBundleBySObjectFieldMap
            = new Map<SObjectField, XFTY_DummySObjectBundle>();

    private final Map<SObjectField, List<SObject>> sObjectListBySObjectFieldMap
            = new Map<SObjectField, List<SObject>>();

    /**
     * The field this bundle's primary records are keyed under. Set by
     * `XFTY_DummySObjectFactory.createBundle`; null on a bundle built by hand.
     */
    public SObjectField primaryTargetField;

    public XFTY_DummySObjectBundle put(SObjectField sObjectField, List<SObject> sObjectList) {
        this.sObjectListBySObjectFieldMap.put(sObjectField, sObjectList);
        return this;
    }

    public XFTY_DummySObjectBundle put(SObjectField sObjectField, XFTY_DummySObjectBundle sObjectBundle) {
        this.sObjectBundleBySObjectFieldMap.put(sObjectField, sObjectBundle);
        return this;
    }

    public XFTY_DummySObjectBundle getBundle(SObjectField sObjectField) {
        return this.sObjectBundleBySObjectFieldMap.get(sObjectField);
    }

    public List<SObject> getList(SObjectField sObjectField) {
        return this.sObjectListBySObjectFieldMap.get(sObjectField);
    }

    /**
     * Read one field several relationship hops up the generated ancestor graph -
     * `{ Contact.AccountId, Account.OwnerId }` reads the generated Account's
     * OwnerId for the primary at `rowIndex`. Null when a hop was not generated or
     * the row is out of range; throws only on a malformed path. See
     * `XFTY_AncestorPathWalker`.
     */
    public Object getValue(List<SObjectField> path, Integer rowIndex) {
        return XFTY_AncestorPathWalker.read(this, path, rowIndex);
    }

    /** `getValue(path, 0)` - for a single-primary bundle. */
    public Object getValue(List<SObjectField> path) {
        return XFTY_AncestorPathWalker.read(this, path, 0);
    }

    /** Record the primary records and the field they belong to. */
    public void putPrimaries(SObjectField primaryTargetField, List<SObject> records) {
        this.primaryTargetField = primaryTargetField;
        this.put(primaryTargetField, records);
    }

    /** The records this bundle is about; null when `primaryTargetField` is not set. */
    public List<SObject> primaryRecords() {
        return (this.primaryTargetField == null)
                ? null
                : this.getList(this.primaryTargetField);
    }

    /** The relationship fields that carry a generated sub-bundle (the parents). */
    public Set<SObjectField> relationshipFields() {
        return this.sObjectBundleBySObjectFieldMap.keySet();
    }

    // Up-flowing values - resolved during the DEFERRED flush, once the forest exists ----

    private final List<DeferredValue> deferredValues = new List<DeferredValue>();

    /** One primary row's field, still to be filled by an up-flow strategy. */
    public class DeferredValue {
        public final Integer primaryRow;
        public final SObjectField field;
        public final XFTY_DeferredExpressionIntf strategy;

        public DeferredValue(Integer primaryRow, SObjectField field, XFTY_DeferredExpressionIntf strategy) {
            this.primaryRow = primaryRow;
            this.field = field;
            this.strategy = strategy;
        }
    }

    /** Record that each primary row's `byField` entries are still to be resolved up from descendants. */
    public void deferValues(Map<SObjectField, XFTY_DeferredExpressionIntf> byField) {
        List<SObject> primaries = this.primaryRecords();
        for (Integer row = 0; row < primaries.size(); row++) {
            for (SObjectField field : byField.keySet()) {
                this.deferredValues.add(new DeferredValue(row, field, byField.get(field)));
            }
        }
    }

    public List<DeferredValue> deferredValues() {
        return this.deferredValues;
    }

    // Children - from XFTY_DummySObjectProvider.with(...) / withChildren(...) ----------------
    //
    // A child relationship field can carry more than one sub-bundle (one per
    // XFTY_SObjectChildProvider configured for it). getChildList / getChildBundle
    // present them merged, in the documented order: config declaration order,
    // then primary order, then per-primary quantity.

    /** One configured child collection: its bundle + which primary row each child row belongs to. */
    public class ChildEntry {
        public final XFTY_DummySObjectBundle bundle;
        public final List<Integer> parentRowByChildRow;

        public ChildEntry(XFTY_DummySObjectBundle bundle, List<Integer> parentRowByChildRow) {
            this.bundle = bundle;
            this.parentRowByChildRow = parentRowByChildRow;
        }
    }

    private final Map<SObjectField, List<ChildEntry>> childEntriesByRelationshipField
            = new Map<SObjectField, List<ChildEntry>>();

    public XFTY_DummySObjectBundle putChild(
            SObjectField childRelationshipField,
            XFTY_DummySObjectBundle childBundle,
            List<Integer> parentRowByChildRow
    ) {
        if (!this.childEntriesByRelationshipField.containsKey(childRelationshipField)) {
            this.childEntriesByRelationshipField.put(childRelationshipField, new List<ChildEntry>());
        }
        this.childEntriesByRelationshipField.get(childRelationshipField)
                .add(new ChildEntry(childBundle, parentRowByChildRow));
        return this;
    }

    /** Every child relationship field this bundle carries children for. */
    public Set<SObjectField> childRelationshipFields() {
        return this.childEntriesByRelationshipField.keySet();
    }

    /** The configured child collections for a relationship field, in declaration order (empty if none). */
    public List<ChildEntry> childEntries(SObjectField childRelationshipField) {
        List<ChildEntry> entries = this.childEntriesByRelationshipField.get(childRelationshipField);
        return (entries == null) ? new List<ChildEntry>() : entries;
    }

    /** The sub-bundles for a child relationship field, in config declaration order (empty list if none). */
    public List<XFTY_DummySObjectBundle> childBundles(SObjectField childRelationshipField) {
        List<XFTY_DummySObjectBundle> bundles = new List<XFTY_DummySObjectBundle>();
        for (ChildEntry entry : this.childEntries(childRelationshipField)) {
            bundles.add(entry.bundle);
        }
        return bundles;
    }

    /** The first child generated for `childRelationshipField`; null if none. */
    public SObject getChild(SObjectField childRelationshipField) {
        List<SObject> all = this.getChildList(childRelationshipField);
        return all.isEmpty() ? null : all[0];
    }

    /** Every child generated for `childRelationshipField`, merged across configs, in the documented order. */
    public List<SObject> getChildList(SObjectField childRelationshipField) {
        List<SObject> all = new List<SObject>();
        for (XFTY_DummySObjectBundle childBundle : this.childBundles(childRelationshipField)) {
            List<SObject> primaries = childBundle.primaryRecords();
            if (primaries != null) {
                all.addAll(primaries);
            }
        }
        return all;
    }

    /**
     * Just the children of one primary row - the slice of `getChildList` that
     * belongs to `primaryRecords()[parentRowIndex]`, read from the recorded
     * parent-of-child map so the caller never has to derive it by arithmetic.
     * Same order as `getChildList`, filtered to that parent. Empty if none.
     */
    public List<SObject> childRecordsOf(Integer parentRowIndex, SObjectField childRelationshipField) {
        List<SObject> matching = new List<SObject>();
        for (ChildEntry entry : this.childEntries(childRelationshipField)) {
            List<SObject> childRecords = entry.bundle.primaryRecords();
            if (childRecords == null) {
                continue;
            }
            for (Integer childRow = 0; childRow < childRecords.size(); childRow++) {
                if (entry.parentRowByChildRow[childRow] == parentRowIndex) {
                    matching.add(childRecords[childRow]);
                }
            }
        }
        return matching;
    }

    /**
     * A single bundle of every child for `childRelationshipField` - merged
     * primaries plus each child's own generated parents - so a caller can
     * navigate on to the children's other ancestors. Null if none.
     */
    public XFTY_DummySObjectBundle getChildBundle(SObjectField childRelationshipField) {
        List<XFTY_DummySObjectBundle> bundles = this.childBundles(childRelationshipField);
        if (bundles.isEmpty()) {
            return null;
        }
        if (bundles.size() == 1) {
            return bundles[0];
        }
        return XFTY_BundleMerger.combine(bundles);
    }
}
