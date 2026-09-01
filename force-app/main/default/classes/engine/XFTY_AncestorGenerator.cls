/** Generates the ancestor sub-bundle for each relationship the inclusivity covers. */
@IsTest
public class XFTY_AncestorGenerator {

    private final XFTY_GenerationContext context;
    private final Integer quantity;
    private final XFTY_DummySObjectMasterTemplate template;

    public XFTY_AncestorGenerator(
            XFTY_GenerationContext context,
            Integer quantity,
            XFTY_DummySObjectMasterTemplate template
    ) {
        this.context = context;
        this.quantity = quantity;
        this.template = template;
    }

    public XFTY_DummySObjectBundle generate() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        Set<SObjectField> forcedHeads = this.explicitlyRequestedRelationshipHeads();
        for (SObjectField field : this.relationshipFields()) {
            this.addAncestor(bundle, field, forcedHeads.contains(field));
        }
        return bundle;
    }

    private List<SObjectField> relationshipFields() {
        Set<SObjectField> fields = new Set<SObjectField>();
        if (!this.inclusivityIs(XFTY_InsertInclusivityEnum.NONE)) {
            fields.addAll(this.template.requiredRelationshipBySObjectFieldMap.keySet());
            if (this.inclusivityIs(XFTY_InsertInclusivityEnum.ALL)) {
                fields.addAll(this.template.optionalRelationshipBySObjectFieldMap.keySet());
            }
        }
        // `includeOptional(...)` / `put(path, ...)` name a relationship for THIS call -
        // generate it whatever the inclusivity says.
        fields.addAll(this.explicitlyRequestedRelationshipHeads());
        return new List<SObjectField>(fields);
    }

    private Set<SObjectField> explicitlyRequestedRelationshipHeads() {
        Set<SObjectField> heads = new Set<SObjectField>();
        for (List<SObjectField> path : this.context.forcedRelationshipPaths) {
            if (!path.isEmpty() && this.isRelationshipHere(path[0])) {
                heads.add(path[0]);
            }
        }
        for (XFTY_PathValue pathValue : this.context.pathValues) {
            // A relationship on the way here, or a putRequired/putOptional(path, ...) that
            // targets a relationship on this ancestor - either way, generate it.
            Boolean namesARelationshipToGenerate = this.isRelationshipHere(pathValue.head())
                    && (!pathValue.isAtTarget() || pathValue.isRelationshipKind());
            if (namesARelationshipToGenerate) {
                heads.add(pathValue.head());
            }
        }
        return heads;
    }

    private Boolean isRelationshipHere(SObjectField field) {
        return this.template.requiredRelationshipBySObjectFieldMap.containsKey(field)
                || this.template.optionalRelationshipBySObjectFieldMap.containsKey(field);
    }

    private void addAncestor(XFTY_DummySObjectBundle bundle, SObjectField field, Boolean isForced) {
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationshipOn(field);
        if (relationship instanceof XFTY_SharedRelationshipIntf) {
            this.assertNoPathValueInto(field);
            this.wireSharedAncestor(bundle, field, relationship);
            return;
        }
        this.generateAncestor(bundle, field, relationship, isForced);
    }

    /**
     * A `put(path, ...)` that sets a plain value on a shared ancestor is rejected -
     * the shared record is resolved once and shared by every child, so a per-call
     * value has no well-defined meaning; configure it with
     * `XFTY_SharedAncestor.put(name, template)`. Wiring a shared ancestor *in* as a
     * relationship value (`putRequired(path, XFTY_SharedAncestor.get(name))`) is
     * fine - on-demand or declared - and is not blocked here.
     */
    private void assertNoPathValueInto(SObjectField field) {
        for (XFTY_PathValue pathValue : this.context.pathValues) {
            if (pathValue.head() != field || pathValue.isSharedRelationshipValue()) {
                continue;
            }
            Boolean setsAValueOnTheSharedRecord = !pathValue.isAtTarget() || pathValue.isRelationshipKind();
            if (setsAValueOnTheSharedRecord) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'put(...) with a path through ' + field + ' sets a value on a shared ancestor. '
                                + 'Configure the shared record with XFTY_SharedAncestor.put(name, ...) instead.'
                );
            }
        }
    }

    private void wireSharedAncestor(
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            XFTY_DummyDefaultRelationshipIntf relationship
    ) {
        XFTY_SharedRelationshipIntf shared = (XFTY_SharedRelationshipIntf) relationship;
        new XFTY_SharedRelationshipWiring(this.context, shared)
                .wire(bundle, field, this.quantity);
    }

    private void generateAncestor(
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            XFTY_DummyDefaultRelationshipIntf relationship,
            Boolean isForced
    ) {
        XFTY_LookupKeyIntf childKey = relationship.resolveLookupKey(this.context.providerLookup);
        this.assertNoAncestorCycle(field, childKey);
        XFTY_DummySobjectProviderIntf provider = this.context.providerLookup.get(childKey);
        XFTY_GenerationContext childContext = this.forcedChildContext(this.context.forRelated(field), isForced)
                .enteringProviderFor(childKey.getHashKey());
        List<SObject> templates = this.clonedTemplatesFor(relationship);
        XFTY_DummySObjectBundle generated = provider.createBundle(childContext, templates);
        SObjectField primaryField = provider.getPrimaryTargetField();
        List<SObject> primaries = generated.getList(primaryField);
        bundle.put(field, generated);
        bundle.put(field, primaries);
    }

    /**
     * An explicitly forced ancestor (`includeOptional` / `put(path, ...)`) is
     * generated **fully formed** - its own required relationships fill in - even
     * when the surrounding call asked for `NONE`. Everything not on a forced path
     * still follows the call's inclusivity.
     */
    private XFTY_GenerationContext forcedChildContext(XFTY_GenerationContext childContext, Boolean isForced) {
        Boolean bumpNeeded = isForced
                && childContext.inclusivity == XFTY_InsertInclusivityEnum.NONE;
        return bumpNeeded
                ? childContext.withInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                : childContext;
    }

    private void assertNoAncestorCycle(SObjectField field, XFTY_LookupKeyIntf childKey) {
        if (!this.context.cycleGuard.wouldCycleOn(childKey.getHashKey())) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'Relationship ' + field + ' would generate another ' + childKey.getSObjectType()
                        + ', but one is already being generated further up this graph - a cycle.'
                        + ' Use distinct per-level Providers (different lookup keys), PREVENT_CASCADE,'
                        + ' or .allowAncestorCycles() when the chain terminates on its own.'
        );
    }

    private List<SObject> clonedTemplatesFor(XFTY_DummyDefaultRelationshipIntf relationship) {
        SObject overrideTemplate = relationship.getOverrideTemplate();
        return XFTY_RecordCloneFactory.deepClones(overrideTemplate, this.quantity);
    }

    private XFTY_DummyDefaultRelationshipIntf relationshipOn(SObjectField field) {
        XFTY_DummyDefaultRelationshipIntf required = this.template.requiredRelationshipBySObjectFieldMap.get(field);
        return required != null
                ? required
                : this.template.optionalRelationshipBySObjectFieldMap.get(field);
    }

    private Boolean inclusivityIs(XFTY_InsertInclusivityEnum value) {
        return value == this.context.inclusivity;
    }

    private static List<SObjectField> fieldsOf(
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationships
    ) {
        Set<SObjectField> fields = relationships.keySet();
        return new List<SObjectField>(fields);
    }
}
