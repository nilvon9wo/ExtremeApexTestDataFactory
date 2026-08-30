@IsTest
public class XFTY_DummySObjectMasterTemplate {
    public SObjectField primaryTargetField { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap { get; private set; }

    // Insertion order of the value fields. Apex Map iteration order is not
    // guaranteed, and the context-aware value pass needs a deterministic order
    // (a context-aware value may read an earlier one). Kept in step with
    // defaultBySObjectFieldMap by put(...) / remove(...) / copy().
    private final List<SObjectField> defaultFieldOrder;

    public XFTY_DummySObjectMasterTemplate(
            SObjectField primaryTargetField,
            Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap
    ) {
        this.primaryTargetField = primaryTargetField;
        this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
        this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
        this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
        this.defaultFieldOrder = new List<SObjectField>(defaultBySObjectFieldMap.keySet());
    }

    public XFTY_DummySObjectMasterTemplate(SObjectField primaryFieldTarget) {
        this(
                primaryFieldTarget,
                new Map<SObjectField, XFTY_DummyDefaultValueIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>()
        );
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultValueIntf valueTemplate) {
        if (!this.defaultBySObjectFieldMap.containsKey(sObjectField)) {
            this.defaultFieldOrder.add(sObjectField);
        }
        this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate putRequired(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.requiredRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate putOptional(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.optionalRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    /**
     * Convenience overload. A value strategy is routed to its typed overload; any
     * other value is treated as an exact literal and wrapped in
     * `XFTY_DummyDefaultValueExact`, so Providers can write
     * `.put(Account.Type, 'Customer')`.
     *
     * Relationships are rejected here: their requiredness has to be stated, so
     * use `putRequired(...)` / `putOptional(...)` explicitly.
     */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DummyDefaultValueIntf) {
            return this.put(sObjectField, (XFTY_DummyDefaultValueIntf) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipIntf) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Relationships must be added with putRequired(...) or putOptional(...), not put(...).'
            );
        }
        return this.put(sObjectField, new XFTY_DummyDefaultValueExact(value));
    }

    /** The value fields in the order they were `put`, for a deterministic value pass. */
    public List<SObjectField> orderedDefaultFields() {
        return this.defaultFieldOrder.clone();
    }

    /**
     * Returns an independent copy of this template.
     *
     * The three field maps (and the field-order list) are recreated so that
     * callers (typically `XFTY_DummySObjectProvider`) can add or remove entries
     * without mutating the shared, statically-held Master Template a Provider
     * exposes. The value and relationship strategy instances themselves are
     * intentionally shared: they are treated as immutable configuration by the
     * engine.
     *
     * The implicit Apex `clone()` is a shallow copy and would leave these maps
     * aliased to the original, so it must not be used for this purpose.
     */
    public XFTY_DummySObjectMasterTemplate copy() {
        XFTY_DummySObjectMasterTemplate theCopy = new XFTY_DummySObjectMasterTemplate(
                this.primaryTargetField,
                new Map<SObjectField, XFTY_DummyDefaultValueIntf>(this.defaultBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(this.requiredRelationshipBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(this.optionalRelationshipBySObjectFieldMap)
        );
        theCopy.defaultFieldOrder.clear();
        theCopy.defaultFieldOrder.addAll(this.defaultFieldOrder);
        return theCopy;
    }

    public XFTY_DummySObjectMasterTemplate remove(SObjectField sObjectField) {
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.requiredRelationshipBySObjectFieldMap.remove(sObjectField);
        this.optionalRelationshipBySObjectFieldMap.remove(sObjectField);
        for (Integer i = this.defaultFieldOrder.size() - 1; i >= 0; i--) {
            if (this.defaultFieldOrder[i] == sObjectField) {
                this.defaultFieldOrder.remove(i);
            }
        }
        return this;
    }
}
