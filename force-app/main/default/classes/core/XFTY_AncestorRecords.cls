/** Generates the ancestor sub-bundle for each relationship the inclusivity covers. */
@IsTest
public class XFTY_AncestorRecords {

    public static XFTY_DummySObjectBundle forGeneration(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template,
            Integer quantity
    ) {
        XFTY_AncestorRecords ancestors = new XFTY_AncestorRecords(context, template);
        return ancestors.build(quantity);
    }

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    private XFTY_AncestorRecords(XFTY_GenerationContext context, XFTY_DummySObjectMasterTemplate template) {
        this.context = context;
        this.template = template;
    }

    private XFTY_DummySObjectBundle build(Integer quantity) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        for (SObjectField field : this.fieldsToGenerate()) {
            this.generate(bundle, field, quantity);
        }
        return bundle;
    }

    private List<SObjectField> fieldsToGenerate() {
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

    private void generate(XFTY_DummySObjectBundle bundle, SObjectField field, Integer quantity) {
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationshipOn(field);
        if (relationship instanceof XFTY_SharedRelationshipIntf) {
            XFTY_SharedRelationshipIntf shared = (XFTY_SharedRelationshipIntf) relationship;
            XFTY_SharedRelationshipWiring.wire(this.context, shared, bundle, field, quantity);
            return;
        }
        this.generatePlain(bundle, field, relationship, quantity);
    }

    private void generatePlain(
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            XFTY_DummyDefaultRelationshipIntf relationship,
            Integer quantity
    ) {
        XFTY_DummySobjectProviderIntf provider = this.providerFor(relationship);
        List<SObject> templates = this.clonesFor(relationship, quantity);
        XFTY_GenerationContext childContext = this.context.forRelated(field);
        XFTY_DummySObjectBundle generated = provider.createBundle(childContext, templates);
        this.place(generated, provider, bundle, field);
    }

    private List<SObject> clonesFor(XFTY_DummyDefaultRelationshipIntf relationship, Integer quantity) {
        SObject overrideTemplate = relationship.getOverrideTemplate();
        return XFTY_RecordClones.of(overrideTemplate, quantity);
    }

    private void place(
            XFTY_DummySObjectBundle generated,
            XFTY_DummySobjectProviderIntf provider,
            XFTY_DummySObjectBundle bundle,
            SObjectField field
    ) {
        SObjectField primaryField = provider.getPrimaryTargetField();
        List<SObject> primaries = generated.getList(primaryField);
        bundle.put(field, generated);
        bundle.put(field, primaries);
    }

    private XFTY_DummyDefaultRelationshipIntf relationshipOn(SObjectField field) {
        XFTY_DummyDefaultRelationshipIntf required = this.template.requiredRelationshipBySObjectFieldMap.get(field);
        XFTY_DummyDefaultRelationshipIntf optional = this.template.optionalRelationshipBySObjectFieldMap.get(field);
        return (required != null)
                ? required
                : optional;
    }

    private XFTY_DummySobjectProviderIntf providerFor(XFTY_DummyDefaultRelationshipIntf relationship) {
        XFTY_LookupKeyIntf key = relationship.resolveLookupKey(this.context.providerLookup);
        return this.context.providerLookup.get(key);
    }

    private Boolean inclusivityIs(XFTY_InsertInclusivityEnum value) {
        return value.equals(this.context.inclusivity);
    }
}
