/** Generates the ancestor sub-bundle for each relationship the inclusivity covers. */
@IsTest
public class XFTY_AncestorRecords {

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;
    private final Integer quantity;
    private final XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

    public XFTY_AncestorRecords(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template,
            Integer quantity
    ) {
        this.context = context;
        this.template = template;
        this.quantity = quantity;
    }

    public XFTY_DummySObjectBundle generate() {
        for (SObjectField field : this.relationshipFields()) {
            this.addAncestor(field);
        }
        return this.bundle;
    }

    private List<SObjectField> relationshipFields() {
        List<SObjectField> fields = new List<SObjectField>();
        if (this.inclusivityIs(XFTY_InsertInclusivityEnum.NONE)) {
            return fields;
        }
        fields.addAll(this.template.requiredRelationshipBySObjectFieldMap.keySet());
        if (this.inclusivityIs(XFTY_InsertInclusivityEnum.ALL)) {
            fields.addAll(this.template.optionalRelationshipBySObjectFieldMap.keySet());
        }
        return fields;
    }

    private void addAncestor(SObjectField field) {
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationshipOn(field);
        if (relationship instanceof XFTY_SharedRelationshipIntf) {
            new XFTY_SharedRelationshipWiring(this.context, (XFTY_SharedRelationshipIntf) relationship)
                    .wire(this.bundle, field, this.quantity);
            return;
        }
        this.addGeneratedAncestor(field, relationship);
    }

    private void addGeneratedAncestor(SObjectField field, XFTY_DummyDefaultRelationshipIntf relationship) {
        XFTY_DummySobjectProviderIntf provider = this.providerFor(relationship);
        List<SObject> templates = this.clonedTemplatesFor(relationship);
        XFTY_GenerationContext childContext = this.context.forRelated(field);
        XFTY_DummySObjectBundle generated = provider.createBundle(childContext, templates);
        SObjectField primaryField = provider.getPrimaryTargetField();
        List<SObject> primaries = generated.getList(primaryField);
        this.bundle.put(field, generated);
        this.bundle.put(field, primaries);
    }

    private List<SObject> clonedTemplatesFor(XFTY_DummyDefaultRelationshipIntf relationship) {
        SObject overrideTemplate = relationship.getOverrideTemplate();
        return XFTY_RecordClones.deepClone(overrideTemplate, this.quantity);
    }

    private XFTY_DummyDefaultRelationshipIntf relationshipOn(SObjectField field) {
        XFTY_DummyDefaultRelationshipIntf required = this.template.requiredRelationshipBySObjectFieldMap.get(field);
        return (required != null)
                ? required
                : this.template.optionalRelationshipBySObjectFieldMap.get(field);
    }

    private XFTY_DummySobjectProviderIntf providerFor(XFTY_DummyDefaultRelationshipIntf relationship) {
        XFTY_LookupKeyIntf key = relationship.resolveLookupKey(this.context.providerLookup);
        return this.context.providerLookup.get(key);
    }

    private Boolean inclusivityIs(XFTY_InsertInclusivityEnum value) {
        return value.equals(this.context.inclusivity);
    }
}
