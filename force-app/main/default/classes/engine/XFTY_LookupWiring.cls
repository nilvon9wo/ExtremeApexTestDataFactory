/** Points each primary record's lookup at the matching generated ancestor. */
@IsTest
public class XFTY_LookupWiring {

    private final XFTY_DummySObjectBundle bundle;
    private final XFTY_GenerationContext context;
    private final Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationships;

    public XFTY_LookupWiring(
            XFTY_DummySObjectBundle bundle,
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template
    ) {
        this.bundle = bundle;
        this.context = context;
        this.relationships = mergeRelationships(template);
    }

    public void wire() {
        if (XFTY_InsertInclusivityEnum.NONE == this.context.inclusivity) {
            return;
        }
        List<SObject> records = this.bundle.primaryRecords();
        for (Integer row = 0; row < records.size(); row++) {
            SObject record = records[row];
            this.wireRecord(record, row);
        }
    }

    private void wireRecord(SObject record, Integer row) {
        for (SObjectField field : this.relationships.keySet()) {
            this.wireField(record, row, field);
        }
    }

    private void wireField(SObject record, Integer row, SObjectField field) {
        if (record.get(field) != null) {
            return;
        }
        SObject parent = this.parentAt(field, row);
        if (parent != null) {
            this.pointToParent(record, field, parent);
        }
    }

    private void pointToParent(SObject record, SObjectField field, SObject parent) {
        XFTY_DummyDefaultRelationshipIntf relationship = this.relationships.get(field);
        SObjectField sourceField = relationship.getRelatedField();
        Object value = readValue(parent, sourceField);
        record.put(field, value);
    }

    private SObject parentAt(SObjectField field, Integer row) {
        List<SObject> parents = this.bundle.getList(field);
        Boolean noParentForRow = parents == null
                || row >= parents.size();
        if (noParentForRow) {
            return null;
        }
        return parents[row];
    }

    private static Object readValue(SObject parent, SObjectField sourceField) {
        return sourceField != null
                ? parent.get(sourceField)
                : parent.Id;
    }

    private static Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> mergeRelationships(
            XFTY_DummySObjectMasterTemplate template
    ) {
        Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> merged =
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>();
        merged.putAll(template.requiredRelationshipBySObjectFieldMap);
        merged.putAll(template.optionalRelationshipBySObjectFieldMap);
        return merged;
    }
}
