/**
 * The single recipe for one shared ancestor's record - what
 * {@link XFTY_SharedAncestorResolver} builds from.
 *
 * It carries a Provider variant key and/or an override template, plus the same
 * per-record API a generated parent takes: `put(field, expression)`, the
 * record's own `putRequired` / `putOptional` relationships, `includeOptional`,
 * `put(path, ...)`, `setInclusivity`. Nothing that would describe more than one
 * record is on the type, so there is no runtime guard for it.
 *
 * Obtained by chaining onto `XFTY_SharedAncestor.put(name, ...)`; never `new`d
 * directly by a test.
 */
@IsTest
public class XFTY_SharedAncestorProvider {

    private final XFTY_SharedAncestor owner;
    private SObject overrideTemplate;
    private XFTY_LookupKeyIntf explicitKey;
    private XFTY_LookupKeyIntf resolvedKey;
    private SObjectField relatedField;
    private XFTY_InsertInclusivityEnum inclusivity;

    private final List<FieldValue> valuePuts = new List<FieldValue>();
    private final List<FieldValue> requiredRelationships = new List<FieldValue>();
    private final List<FieldValue> optionalRelationships = new List<FieldValue>();
    private final List<List<SObjectField>> forcedRelationshipPaths = new List<List<SObjectField>>();
    private final List<XFTY_PathValue> pathValues = new List<XFTY_PathValue>();

    public XFTY_SharedAncestorProvider(XFTY_SharedAncestor owner) {
        this.owner = owner;
    }

    // Configuration ---------------------------------------------------

    public XFTY_SharedAncestorProvider withTemplate(SObject overrideTemplate) {
        this.owner.assertUnresolved('put(name, template)');
        this.overrideTemplate = overrideTemplate;
        return this;
    }

    /** Pin the Provider variant that generates this shared record. */
    public XFTY_SharedAncestorProvider fromVariant(XFTY_LookupKeyIntf key) {
        this.owner.assertUnresolved('fromVariant(...)');
        this.explicitKey = key;
        return this;
    }

    /** Copy this field from the shared record into the child's lookup, instead of its Id. */
    public XFTY_SharedAncestorProvider copyingRelatedField(SObjectField relatedField) {
        this.owner.assertUnresolved('copyingRelatedField(...)');
        this.relatedField = relatedField;
        return this;
    }

    /** Inclusivity for the shared record's own relationships (default `REQUIRED`). */
    public XFTY_SharedAncestorProvider setInclusivity(XFTY_InsertInclusivityEnum inclusivity) {
        this.owner.assertUnresolved('setInclusivity(...)');
        this.inclusivity = inclusivity;
        return this;
    }

    public XFTY_SharedAncestorProvider put(SObjectField field, XFTY_ValueExpressionIntf expression) {
        return this.addValue(field, expression);
    }

    public XFTY_SharedAncestorProvider put(SObjectField field, XFTY_ContextAwareExpressionIntf expression) {
        return this.addValue(field, expression);
    }

    public XFTY_SharedAncestorProvider put(SObjectField field, Object literal) {
        return this.addValue(field, literal);
    }

    public XFTY_SharedAncestorProvider putRequired(SObjectField field, XFTY_DummyDefaultRelationshipIntf relationship) {
        this.owner.assertUnresolved('putRequired(...)');
        this.requiredRelationships.add(new FieldValue(field, relationship));
        return this;
    }

    public XFTY_SharedAncestorProvider putOptional(SObjectField field, XFTY_DummyDefaultRelationshipIntf relationship) {
        this.owner.assertUnresolved('putOptional(...)');
        this.optionalRelationships.add(new FieldValue(field, relationship));
        return this;
    }

    public XFTY_SharedAncestorProvider includeOptional(SObjectField relationshipField) {
        return this.includeOptional(new List<SObjectField>{ relationshipField });
    }

    public XFTY_SharedAncestorProvider includeOptional(List<SObjectField> relationshipPath) {
        this.owner.assertUnresolved('includeOptional(...)');
        this.forcedRelationshipPaths.add(relationshipPath);
        return this;
    }

    public XFTY_SharedAncestorProvider put(List<SObjectField> path, XFTY_ValueExpressionIntf expression) {
        return this.addPathValue(XFTY_PathValue.ofExpression(path, expression));
    }

    public XFTY_SharedAncestorProvider put(List<SObjectField> path, XFTY_ContextAwareExpressionIntf expression) {
        return this.addPathValue(XFTY_PathValue.ofContextAware(path, expression));
    }

    public XFTY_SharedAncestorProvider put(List<SObjectField> path, Object literal) {
        return this.addPathValue(XFTY_PathValue.ofLiteral(path, literal));
    }

    public XFTY_SharedAncestorProvider putRequired(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf relationship) {
        return this.addPathValue(XFTY_PathValue.ofRequiredRelationship(path, relationship));
    }

    public XFTY_SharedAncestorProvider putOptional(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf relationship) {
        return this.addPathValue(XFTY_PathValue.ofOptionalRelationship(path, relationship));
    }

    private XFTY_SharedAncestorProvider addValue(SObjectField field, Object value) {
        this.owner.assertUnresolved('put(...)');
        this.valuePuts.add(new FieldValue(field, value));
        return this;
    }

    private XFTY_SharedAncestorProvider addPathValue(XFTY_PathValue pathValue) {
        this.owner.assertUnresolved('put(path, ...)');
        this.pathValues.add(pathValue);
        return this;
    }

    // Used by XFTY_SharedAncestor / XFTY_SharedAncestorResolver -------

    /** The field copied from the shared record into the child's lookup, or null. */
    public SObjectField relatedField() {
        return this.relatedField;
    }

    /** The override template, if one was given - for `XFTY_DummyDefaultRelationshipIntf`. */
    public SObject overrideTemplate() {
        return this.overrideTemplate;
    }

    /** This ancestor's whole graph, generated with no persistence, ready for the depth-batched insert. */
    public XFTY_DummySObjectBundle buildInMemory(XFTY_DummySObjectProviderLookupIntf lookup) {
        XFTY_InsertInclusivityEnum effectiveInclusivity =
                (this.inclusivity == null) ? XFTY_InsertInclusivityEnum.REQUIRED : this.inclusivity;
        XFTY_GenerationContext context = new XFTY_GenerationContext(
                        lookup, XFTY_InsertModeEnum.NEVER, effectiveInclusivity
                )
                .withForcedRelationshipPaths(this.forcedRelationshipPaths)
                .withPathValues(this.pathValues);
        SObject seed = this.recordTemplate(lookup).clone(true, true, true, true);
        return XFTY_DummySObjectFactory.createBundle(context, this.masterTemplate(lookup), new List<SObject>{ seed });
    }

    /** The primary target field (the record's `Id` field). */
    public SObjectField primaryField(XFTY_DummySObjectProviderLookupIntf lookup) {
        return this.baseProvider(lookup).getPrimaryTargetField();
    }

    /** The Master Template the pre-phase scans for nested shared ancestors - with this ancestor's puts applied. */
    public XFTY_DummySObjectMasterTemplate masterTemplate(XFTY_DummySObjectProviderLookupIntf lookup) {
        XFTY_DummySObjectMasterTemplate template = this.baseProvider(lookup).getMasterTemplate().copy();
        for (FieldValue put : this.valuePuts) {
            template.put(put.field, put.value);
        }
        for (FieldValue put : this.requiredRelationships) {
            template.putRequired(put.field, (XFTY_DummyDefaultRelationshipIntf) put.value);
        }
        for (FieldValue put : this.optionalRelationships) {
            template.putOptional(put.field, (XFTY_DummyDefaultRelationshipIntf) put.value);
        }
        return template;
    }

    /**
     * True when the shared record is a single row with no sub-graph of its own -
     * no relationships on its merged Master Template, no forced paths, no
     * relationship-kind path value. Such a record is cheap enough to resolve
     * on-demand; a "heavy" one needs `resolveNow(...)` up front under
     * {@link XFTY_SharedAncestor#manualResolutionOnly}.
     */
    public Boolean isLightweight(XFTY_DummySObjectProviderLookupIntf lookup) {
        if (!this.requiredRelationships.isEmpty()
                || !this.optionalRelationships.isEmpty()
                || !this.forcedRelationshipPaths.isEmpty()) {
            return false;
        }
        for (XFTY_PathValue pathValue : this.pathValues) {
            if (pathValue.isRelationshipKind()) {
                return false;
            }
        }
        XFTY_DummySObjectMasterTemplate base = this.baseProvider(lookup).getMasterTemplate();
        return base.requiredRelationshipBySObjectFieldMap.isEmpty()
                && base.optionalRelationshipBySObjectFieldMap.isEmpty();
    }

    /** The lookup key this ancestor resolves under. */
    public XFTY_LookupKeyIntf lookupKey(XFTY_DummySObjectProviderLookupIntf lookup) {
        if (this.resolvedKey == null) {
            this.resolvedKey = (this.explicitKey != null)
                    ? this.explicitKey
                    : XFTY_ProviderLookups.resolve(lookup, this.requireTemplate());
        }
        return this.resolvedKey;
    }

    // ---------------------------------------------------------------

    private XFTY_DummySobjectProviderIntf baseProvider(XFTY_DummySObjectProviderLookupIntf lookup) {
        return lookup.get(this.lookupKey(lookup));
    }

    private SObject recordTemplate(XFTY_DummySObjectProviderLookupIntf lookup) {
        return (this.overrideTemplate != null)
                ? this.overrideTemplate
                : this.lookupKey(lookup).getSObjectType().newSObject();
    }

    private SObject requireTemplate() {
        if (this.overrideTemplate == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.owner.getSharedName() + '" needs XFTY_SharedAncestor.putAsTemplate(...) '
                            + 'or put(name, key) before it can resolve.'
            );
        }
        return this.overrideTemplate;
    }

    private class FieldValue {
        final SObjectField field;
        final Object value;

        FieldValue(SObjectField field, Object value) {
            this.field = field;
            this.value = value;
        }
    }
}
