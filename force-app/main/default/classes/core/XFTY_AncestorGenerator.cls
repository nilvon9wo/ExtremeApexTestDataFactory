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
        for (SObjectField field : this.relationshipFields()) {
            this.addAncestor(bundle, field);
        }
        return bundle;
    }

    private List<SObjectField> relationshipFields() {
        if (this.inclusivityIs(XFTY_InsertInclusivityEnum.NONE)) {
            return new List<SObjectField>();
        }
        List<SObjectField> fields = fieldsOf(this.template.requiredRelationshipBySObjectFieldMap);
        if (this.inclusivityIs(XFTY_InsertInclusivityEnum.ALL)) {
            this.addOptionalFieldsTo(fields);
        }
        return fields;
    }

    private void addOptionalFieldsTo(List<SObjectField> fields) {
        List<SObjectField> optional = fieldsOf(this.template.optionalRelationshipBySObjectFieldMap);
        fields.addAll(optional);
    }

    private void addAncestor(XFTY_DummySObjectBundle bundle, SObjectField field) {
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationshipOn(field);
        if (relationship instanceof XFTY_SharedRelationshipIntf) {
            this.wireSharedAncestor(bundle, field, relationship);
            return;
        }
        this.generateAncestor(bundle, field, relationship);
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
            XFTY_DummyDefaultRelationshipIntf relationship
    ) {
        XFTY_DummySobjectProviderIntf provider = this.providerFor(relationship);
        List<SObject> templates = this.clonedTemplatesFor(relationship);
        XFTY_GenerationContext childContext = this.context.forRelated(field);
        XFTY_DummySObjectBundle generated = provider.createBundle(childContext, templates);
        SObjectField primaryField = provider.getPrimaryTargetField();
        List<SObject> primaries = generated.getList(primaryField);
        bundle.put(field, generated);
        bundle.put(field, primaries);
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

    private XFTY_DummySobjectProviderIntf providerFor(XFTY_DummyDefaultRelationshipIntf relationship) {
        XFTY_LookupKeyIntf key = relationship.resolveLookupKey(this.context.providerLookup);
        return this.context.providerLookup.get(key);
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
