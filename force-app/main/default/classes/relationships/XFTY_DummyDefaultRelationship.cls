/**
 * The standard relationship implementation: generate a fresh parent record from
 * the given override template.
 *
 * Replaces the former `XFTY_DummyDefaultRelationshipRequired` /
 * `XFTY_DummyDefaultRelationshipOptional` pair - requiredness is now decided by
 * the Master Template slot, not by the type.
 *
 * Constructors:
 * - `(SObject template)` - Provider variant derived from the template
 * - `(SObject template, SObjectField relatedField)` - copy `relatedField` from
 *    the parent instead of its Id
 * - `(XFTY_LookupKeyIntf key, SObject template)` - pin the Provider variant
 * - `(XFTY_LookupKeyIntf key, SObject template, SObjectField relatedField)`
 */
@IsTest
public class XFTY_DummyDefaultRelationship implements XFTY_DummyDefaultRelationshipIntf {
    private final SObject overrideTemplate;
    private final SObjectField relatedField;
    private final XFTY_LookupKeyIntf explicitLookupKey;
    private XFTY_LookupKeyIntf resolvedLookupKey;

    public XFTY_DummyDefaultRelationship(SObject overrideTemplate) {
        this(null, overrideTemplate, null);
    }

    public XFTY_DummyDefaultRelationship(SObject overrideTemplate, SObjectField relatedField) {
        this(null, overrideTemplate, relatedField);
    }

    public XFTY_DummyDefaultRelationship(XFTY_LookupKeyIntf lookupKey, SObject overrideTemplate) {
        this(lookupKey, overrideTemplate, null);
    }

    public XFTY_DummyDefaultRelationship(
            XFTY_LookupKeyIntf lookupKey,
            SObject overrideTemplate,
            SObjectField relatedField
    ) {
        this.explicitLookupKey = lookupKey;
        this.overrideTemplate = overrideTemplate;
        this.relatedField = relatedField;
    }

    public SObject getOverrideTemplate() {
        return this.overrideTemplate;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
    }

    public XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        if (this.resolvedLookupKey == null) {
            this.resolvedLookupKey = XFTY_ProviderLookups.reconcile(
                    providerLookup, this.explicitLookupKey, this.overrideTemplate);
        }
        return this.resolvedLookupKey;
    }
}
