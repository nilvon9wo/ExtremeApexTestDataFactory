@IsTest
public class XFTY_DummySObjectMasterTemplate {
    public SObjectField primaryTargetField { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_ContextAwareValueIntf> contextAwareBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DeferredValueIntf> deferredValueBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap { get; private set; }

    // Insertion order of the value fields (plain + context-aware). Apex Map
    // iteration order is not guaranteed, and the value passes need a deterministic
    // order - a context-aware value may read an earlier one. Kept in step by
    // put(...) / remove(...) / copy().
    private final List<SObjectField> valueFieldOrder;

    public XFTY_DummySObjectMasterTemplate(
            SObjectField primaryTargetField,
            Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap
    ) {
        this.primaryTargetField = primaryTargetField;
        this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
        this.contextAwareBySObjectFieldMap = new Map<SObjectField, XFTY_ContextAwareValueIntf>();
        this.deferredValueBySObjectFieldMap = new Map<SObjectField, XFTY_DeferredValueIntf>();
        this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
        this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
        this.valueFieldOrder = new List<SObjectField>(defaultBySObjectFieldMap.keySet());
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
        this.trackFieldOrder(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredValueBySObjectFieldMap.remove(sObjectField);
        this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_ContextAwareValueIntf contextAwareValue) {
        this.trackFieldOrder(sObjectField);
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.deferredValueBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.put(sObjectField, contextAwareValue);
        return this;
    }

    /** An up-flowing value ({@link XFTY_CopyFromDescendant}) - resolved during the DEFERRED flush. */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DeferredValueIntf deferredValue) {
        this.trackFieldOrder(sObjectField);
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredValueBySObjectFieldMap.put(sObjectField, deferredValue);
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
     * Convenience overload. Routed by type:
     * - `XFTY_ContextAwareValueIntf` -> the context-aware slot;
     * - `XFTY_DummyDefaultValueIntf` -> the plain value slot;
     * - a relationship -> rejected (its requiredness has to be stated, so use
     *   `putRequired(...)` / `putOptional(...)`);
     * - anything else -> treated as an exact literal, so a Provider can write
     *   `.put(Account.Type, 'Customer')`.
     */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DeferredValueIntf) {
            return this.put(sObjectField, (XFTY_DeferredValueIntf) value);
        }
        if (value instanceof XFTY_ContextAwareValueIntf) {
            return this.put(sObjectField, (XFTY_ContextAwareValueIntf) value);
        }
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

    /** Every value field (plain + context-aware) in the order it was `put`. */
    public List<SObjectField> orderedValueFields() {
        return this.valueFieldOrder.clone();
    }

    /**
     * Returns an independent copy of this template.
     *
     * The field maps (and the field-order list) are recreated so that callers
     * (typically `XFTY_DummySObjectProvider`) can add or remove entries without
     * mutating the shared, statically-held Master Template a Provider exposes. The
     * strategy instances themselves are intentionally shared: they are treated as
     * immutable configuration by the engine.
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
        theCopy.contextAwareBySObjectFieldMap.putAll(this.contextAwareBySObjectFieldMap);
        theCopy.deferredValueBySObjectFieldMap.putAll(this.deferredValueBySObjectFieldMap);
        theCopy.valueFieldOrder.clear();
        theCopy.valueFieldOrder.addAll(this.valueFieldOrder);
        return theCopy;
    }

    public XFTY_DummySObjectMasterTemplate remove(SObjectField sObjectField) {
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredValueBySObjectFieldMap.remove(sObjectField);
        this.requiredRelationshipBySObjectFieldMap.remove(sObjectField);
        this.optionalRelationshipBySObjectFieldMap.remove(sObjectField);
        for (Integer i = this.valueFieldOrder.size() - 1; i >= 0; i--) {
            if (this.valueFieldOrder[i] == sObjectField) {
                this.valueFieldOrder.remove(i);
            }
        }
        return this;
    }

    private void trackFieldOrder(SObjectField sObjectField) {
        Boolean alreadyTracked = this.defaultBySObjectFieldMap.containsKey(sObjectField)
                || this.contextAwareBySObjectFieldMap.containsKey(sObjectField)
                || this.deferredValueBySObjectFieldMap.containsKey(sObjectField);
        if (!alreadyTracked) {
            this.valueFieldOrder.add(sObjectField);
        }
    }
}
