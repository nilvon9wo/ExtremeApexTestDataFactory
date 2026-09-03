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

    // Serialization enrichment - re-express the graph in the shape put() rejects ----

    /**
     * New instances of the records at `getList(field)`, enriched per `config` -
     * populated parent relationships, child subqueries, forced scalars - so code
     * under test reads them straight off the SObject. Originals untouched. See
     * `XFTY_BundleEnricher`.
     */
    public List<SObject> inject(SObjectField field, XFTY_InjectConfig config) {
        return XFTY_BundleEnricher.enrich(this, field, config);
    }

    /** `inject` with everything the graph holds; throws if there is nothing to inject. */
    public List<SObject> injectAll(SObjectField field) {
        return XFTY_BundleEnricher.enrichEverything(this, field);
    }

    /** `inject` with every generated ancestor; children only if the config names them. */
    public List<SObject> injectAllParents(SObjectField field) {
        return this.inject(field, XFTY_InjectConfig.allParents());
    }

    /** `inject` with every generated child collection; parents only if the config names them. */
    public List<SObject> injectAllChildren(SObjectField field) {
        return this.inject(field, XFTY_InjectConfig.allChildren());
    }

    /**
     * The primary records generated pointing at `getList(relationshipField)` row
     * `ancestorRowIndex` - the inverse of the 1:1 parent alignment, so a shared
     * ancestor returns the several primaries that resolved to it. Matched on the
     * foreign key when Ids exist, else the 1:1 position. The upward counterpart of
     * `childRecordsOf`. Empty when the row is out of range.
     */
    public List<SObject> primariesResolvingTo(SObjectField relationshipField, Integer ancestorRowIndex) {
        List<SObject> ancestors = this.getList(relationshipField);
        if (this.primaryRecords() == null || ancestors == null
                || ancestorRowIndex < 0 || ancestorRowIndex >= ancestors.size()) {
            return new List<SObject>();
        }
        return XFTY_InverseAlignment.childrenPerParent(ancestors, this.primaryRecords(), relationshipField)[ancestorRowIndex];
    }

    // Up-flowing values - resolved during the DEFERRED flush, once the forest exists ----

    private final XFTY_DeferredValueQueue deferredValueQueue = new XFTY_DeferredValueQueue();

    /** Record that each primary row's `byField` entries are still to be resolved up from descendants. */
    public void deferValues(Map<SObjectField, XFTY_DeferredExpressionIntf> byField) {
        this.deferredValueQueue.addForEachRow(this.primaryRecords().size(), byField);
    }

    public List<XFTY_DeferredValueQueue.Entry> deferredValues() {
        return this.deferredValueQueue.entries();
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
