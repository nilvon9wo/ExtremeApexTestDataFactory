@IsTest
public class XFTY_DummySObjectBundle {
    private final Map<SObjectField, XFTY_DummySObjectBundle> sObjectBundleBySObjectFieldMap
            = new Map<SObjectField, XFTY_DummySObjectBundle>();

    private final Map<SObjectField, List<SObject>> sObjectListBySObjectFieldMap
            = new Map<SObjectField, List<SObject>>();

    /**
     * The field this bundle's primary records are keyed under - the primary
     * target field of the Provider that produced it. Set by
     * `XFTY_DummySObjectFactory.createBundle`; used by `XFTY_DeferredInsertBuffer`
     * to walk the graph. Null on a bundle built by hand in a test.
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

    /** The relationship fields that carry a generated sub-bundle (the parents). */
    public Set<SObjectField> relationshipFields() {
        return this.sObjectBundleBySObjectFieldMap.keySet();
    }
}
