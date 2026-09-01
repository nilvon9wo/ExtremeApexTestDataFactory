@IsTest
public class XFTY_DummySObjectMasterTemplate {
    public SObjectField primaryTargetField { get; private set; }
    public Map<SObjectField, XFTY_ValueExpressionIntf> defaultBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_ContextAwareExpressionIntf> contextAwareBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DeferredExpressionIntf> deferredExpressionBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap { get; private set; }

    // Insertion order of the value fields (plain + context-aware). Apex Map
    // iteration order is not guaranteed, and the value passes need a deterministic
    // order - a context-aware value may read an earlier one. Kept in step by
    // put(...) / remove(...) / copy().
    private final List<SObjectField> valueFieldOrder;

    public XFTY_DummySObjectMasterTemplate(
            SObjectField primaryTargetField,
            Map<SObjectField, XFTY_ValueExpressionIntf> defaultBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> requiredRelationshipBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> optionalRelationshipBySObjectFieldMap
    ) {
        this.primaryTargetField = primaryTargetField;
        this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
        this.contextAwareBySObjectFieldMap = new Map<SObjectField, XFTY_ContextAwareExpressionIntf>();
        this.deferredExpressionBySObjectFieldMap = new Map<SObjectField, XFTY_DeferredExpressionIntf>();
        this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
        this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
        this.valueFieldOrder = new List<SObjectField>(defaultBySObjectFieldMap.keySet());
    }

    public XFTY_DummySObjectMasterTemplate(SObjectField primaryFieldTarget) {
        this(
                primaryFieldTarget,
                new Map<SObjectField, XFTY_ValueExpressionIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>()
        );
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_ValueExpressionIntf valueTemplate) {
        this.trackFieldOrder(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredExpressionBySObjectFieldMap.remove(sObjectField);
        this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_ContextAwareExpressionIntf contextAwareExpression) {
        this.trackFieldOrder(sObjectField);
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.deferredExpressionBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.put(sObjectField, contextAwareExpression);
        return this;
    }

    /** An up-flowing value ({@link XFTY_CopyFromDescendantExpression}) - resolved during the DEFERRED flush. */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DeferredExpressionIntf deferredValue) {
        this.trackFieldOrder(sObjectField);
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredExpressionBySObjectFieldMap.put(sObjectField, deferredValue);
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
     * - `XFTY_ContextAwareExpressionIntf` -> the context-aware slot;
     * - `XFTY_ValueExpressionIntf` -> the plain value slot;
     * - a relationship -> rejected (its requiredness has to be stated, so use
     *   `putRequired(...)` / `putOptional(...)`);
     * - anything else -> treated as an exact literal, so a Provider can write
     *   `.put(Account.Type, 'Customer')`.
     */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DeferredExpressionIntf) {
            return this.put(sObjectField, (XFTY_DeferredExpressionIntf) value);
        }
        if (value instanceof XFTY_ContextAwareExpressionIntf) {
            return this.put(sObjectField, (XFTY_ContextAwareExpressionIntf) value);
        }
        if (value instanceof XFTY_ValueExpressionIntf) {
            return this.put(sObjectField, (XFTY_ValueExpressionIntf) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipIntf) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Relationships must be added with putRequired(...) or putOptional(...), not put(...).'
            );
        }
        return this.put(sObjectField, new XFTY_LiteralExpression(value));
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
     * expression instances themselves are intentionally shared: they are treated as
     * immutable configuration by the engine.
     *
     * The implicit Apex `clone()` is a shallow copy and would leave these maps
     * aliased to the original, so it must not be used for this purpose.
     */
    public XFTY_DummySObjectMasterTemplate copy() {
        XFTY_DummySObjectMasterTemplate theCopy = new XFTY_DummySObjectMasterTemplate(
                this.primaryTargetField,
                new Map<SObjectField, XFTY_ValueExpressionIntf>(this.defaultBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(this.requiredRelationshipBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(this.optionalRelationshipBySObjectFieldMap)
        );
        theCopy.contextAwareBySObjectFieldMap.putAll(this.contextAwareBySObjectFieldMap);
        theCopy.deferredExpressionBySObjectFieldMap.putAll(this.deferredExpressionBySObjectFieldMap);
        theCopy.valueFieldOrder.clear();
        theCopy.valueFieldOrder.addAll(this.valueFieldOrder);
        return theCopy;
    }

    public XFTY_DummySObjectMasterTemplate remove(SObjectField sObjectField) {
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.contextAwareBySObjectFieldMap.remove(sObjectField);
        this.deferredExpressionBySObjectFieldMap.remove(sObjectField);
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
                || this.deferredExpressionBySObjectFieldMap.containsKey(sObjectField);
        if (!alreadyTracked) {
            this.valueFieldOrder.add(sObjectField);
        }
    }
}
