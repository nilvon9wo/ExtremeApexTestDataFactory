/** Points each primary record's lookup at the matching generated ancestor. */
@IsTest
public class XFTY_LookupWiring {

    public static void wire(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template,
            XFTY_DummySObjectBundle bundle,
            List<SObject> records
    ) {
        XFTY_LookupWiring wiring = new XFTY_LookupWiring(context, template);
        wiring.into(bundle, records);
    }

    private final XFTY_GenerationContext context;
    private final Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationships;

    private XFTY_LookupWiring(XFTY_GenerationContext context, XFTY_DummySObjectMasterTemplate template) {
        this.context = context;
        this.relationships = merged(template);
    }

    private void into(XFTY_DummySObjectBundle bundle, List<SObject> records) {
        if (XFTY_InsertInclusivityEnum.NONE.equals(this.context.inclusivity)) {
            return;
        }
        for (Integer row = 0; row < records.size(); row++) {
            SObject record = records[row];
            this.wireRow(bundle, record, row);
        }
    }

    private void wireRow(XFTY_DummySObjectBundle bundle, SObject record, Integer row) {
        for (SObjectField field : this.relationships.keySet()) {
            this.wireField(bundle, record, row, field);
        }
    }

    private void wireField(XFTY_DummySObjectBundle bundle, SObject record, Integer row, SObjectField field) {
        Boolean alreadySet = record.get(field) != null;
        if (alreadySet) {
            return;
        }
        SObject parent = parentAt(bundle, field, row);
        if (parent == null) {
            return;
        }
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationships.get(field);
        SObjectField sourceField = relationship.getRelatedField();
        Object value = valueFrom(parent, sourceField);
        record.put(field, value);
    }

    private static Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> merged(
            XFTY_DummySObjectMasterTemplate template
    ) {
        Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> all = new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>();
        all.putAll(template.requiredRelationshipBySObjectFieldMap);
        all.putAll(template.optionalRelationshipBySObjectFieldMap);
        return all;
    }

    private static SObject parentAt(XFTY_DummySObjectBundle bundle, SObjectField field, Integer row) {
        List<SObject> parents = bundle.getList(field);
        if (parents == null) {
            return null;
        }
        if (row >= parents.size()) {
            return null;
        }
        return parents[row];
    }

    private static Object valueFrom(SObject parent, SObjectField sourceField) {
        return (sourceField != null)
                ? parent.get(sourceField)
                : parent.Id;
    }
}
