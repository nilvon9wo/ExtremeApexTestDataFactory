@IsTest
public class XFTY_DummySObjectMasterTemplate {
    public SObjectField primaryTargetField { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap { get; private set; }

    public XFTY_DummySObjectMasterTemplate(
            SObjectField primaryTargetField,
            Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap
    ) {
        this.primaryTargetField = primaryTargetField;
        this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
        this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
        this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
    }

    public XFTY_DummySObjectMasterTemplate(SObjectField primaryFieldTarget) {
        this(
                primaryFieldTarget,
                new Map<SObjectField, XFTY_DummyDefaultValueIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipRequired>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipOptional>()
        );
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultValueIntf valueTemplate) {
        this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate);
        return this;
    }

    /**
     * Convenience overload. Anything that is already a generation strategy or a
     * relationship template is routed to its typed overload; any other value is
     * treated as an exact literal and wrapped in `XFTY_DummyDefaultValueExact`,
     * so Providers can write `.put(Account.Type, 'Customer')` instead of
     * `.put(Account.Type, new XFTY_DummyDefaultValueExact('Customer'))`.
     */
    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DummyDefaultValueIntf) {
            return this.put(sObjectField, (XFTY_DummyDefaultValueIntf) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipRequired) {
            return this.put(sObjectField, (XFTY_DummyDefaultRelationshipRequired) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipOptional) {
            return this.put(sObjectField, (XFTY_DummyDefaultRelationshipOptional) value);
        }
        return this.put(sObjectField, new XFTY_DummyDefaultValueExact(value));
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipRequired relationshipTemplate) {
        this.requiredRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipOptional relationshipTemplate) {
        this.optionalRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    /**
     * Returns an independent copy of this template.
     *
     * The three field maps are recreated so that callers (typically
     * `XFTY_DummySObjectProvider`) can add or remove entries without mutating the
     * shared, statically-held Master Template a Provider exposes. The value and
     * relationship strategy instances themselves are intentionally shared: they
     * are treated as immutable configuration by the engine.
     *
     * The implicit Apex `clone()` is a shallow copy and would leave these maps
     * aliased to the original, so it must not be used for this purpose.
     */
    public XFTY_DummySObjectMasterTemplate copy() {
        return new XFTY_DummySObjectMasterTemplate(
                this.primaryTargetField,
                new Map<SObjectField, XFTY_DummyDefaultValueIntf>(this.defaultBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipRequired>(this.requiredRelationshipBySObjectFieldMap),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipOptional>(this.optionalRelationshipBySObjectFieldMap)
        );
    }

    public XFTY_DummySObjectMasterTemplate remove(SObjectField sObjectField) {
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.requiredRelationshipBySObjectFieldMap.remove(sObjectField);
        this.optionalRelationshipBySObjectFieldMap.remove(sObjectField);
        return this;
    }
}