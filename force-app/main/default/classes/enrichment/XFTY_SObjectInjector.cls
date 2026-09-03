/**
 * Writes onto SObject instances what `record.put(...)` rejects - a populated
 * parent relationship, a child subquery, a formula / roll-up / system /
 * read-only field, a compound field - through one `JSON.serialize` /
 * `JSON.deserialize` round-trip over the whole list.
 *
 * Standalone: no bundle, no generation. Collect the grafts fluently, then
 * `result()` does exactly one serialize and one deserialize regardless of how
 * many rows or grafts. Inputs are untouched; the returned list is new instances.
 * `Blob` fields are carried across by `XFTY_BlobCarrier`.
 *
 * ```
 * List<Contact> withAccount = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
 *     .relationship('Account', accountsAligned1to1)
 *     .value(Contact.CreatedDate, aDatetime)
 *     .result();
 * ```
 */
@IsTest
public class XFTY_SObjectInjector {

    private static final Boolean DONE = true;

    private final List<SObject> records;
    private final Map<String, List<SObject>> parentByRelationshipName = new Map<String, List<SObject>>();
    private final Map<String, List<List<SObject>>> childrenByRelationshipName = new Map<String, List<List<SObject>>>();
    private final Map<SObjectField, Object> uniformValueByField = new Map<SObjectField, Object>();
    private final Map<SObjectField, List<Object>> perRowValuesByField = new Map<SObjectField, List<Object>>();

    private XFTY_SObjectInjector(List<SObject> records) {
        if (records == null) {
            throw new XFTY_DummySObjectFtyProviderException('XFTY_SObjectInjector needs a records list, not null.');
        }
        this.records = records;
    }

    public static XFTY_SObjectInjector inject(List<SObject> records) {
        return new XFTY_SObjectInjector(records);
    }

    /** Graft `parents[row]` onto `records[row]` as `relationshipName` (e.g. 'Account', 'Parent', 'Who', 'Foo__r'). */
    public XFTY_SObjectInjector relationship(String relationshipName, List<SObject> parents) {
        this.parentByRelationshipName.put(relationshipName, parents);
        return this;
    }

    /** Graft `childrenPerRow[row]` onto `records[row]` as the `relationshipName` subquery (e.g. 'Contacts'). */
    public XFTY_SObjectInjector childRelationship(String relationshipName, List<List<SObject>> childrenPerRow) {
        this.childrenByRelationshipName.put(relationshipName, childrenPerRow);
        return this;
    }

    /**
     * Set `field` to the same value on every row. A compound field takes a
     * `Map<String, Object>` of its lowercase components (`{ 'city' => 'X' }`).
     */
    public XFTY_SObjectInjector value(SObjectField field, Object valueForEveryRow) {
        this.uniformValueByField.put(field, valueForEveryRow);
        return this;
    }

    /** Set `field` to `values[row]` on each row. */
    public XFTY_SObjectInjector valuePerRow(SObjectField field, List<Object> values) {
        this.perRowValuesByField.put(field, values);
        return this;
    }

    public List<SObject> result() {
        if (this.records.isEmpty()) {
            return new List<SObject>();
        }
        this.rejectMisalignedGrafts();
        List<Map<String, Object>> forcedValues = this.forcedValuesPerRow();
        List<Map<String, Blob>> blobsByRow = XFTY_BlobCarrier.capture(this.records, forcedValues);
        List<Object> rawRecords = (List<Object>) JSON.deserializeUntyped(JSON.serialize(this.records));
        this.graftInto(rawRecords, forcedValues, blobsByRow);
        List<SObject> grafted = (List<SObject>) JSON.deserialize(JSON.serialize(rawRecords), this.listType());
        XFTY_BlobCarrier.restore(grafted, blobsByRow);
        return grafted;
    }

    private void graftInto(
            List<Object> rawRecords,
            List<Map<String, Object>> forcedValues,
            List<Map<String, Blob>> blobsByRow
    ) {
        for (Integer row = 0; row < rawRecords.size(); row++) {
            Map<String, Object> rawRecord = (Map<String, Object>) rawRecords[row];
            XFTY_BlobCarrier.keepOut(rawRecord, blobsByRow[row].keySet());
            this.graftRow(rawRecord, row, forcedValues[row]);
        }
    }

    private void graftRow(Map<String, Object> rawRecord, Integer row, Map<String, Object> forcedForRow) {
        for (String relationshipName : this.parentByRelationshipName.keySet()) {
            rawRecord.put(relationshipName, rawOf(this.parentByRelationshipName.get(relationshipName)[row]));
        }
        for (String relationshipName : this.childrenByRelationshipName.keySet()) {
            rawRecord.put(relationshipName, subqueryOf(this.childrenByRelationshipName.get(relationshipName)[row]));
        }
        for (String field : forcedForRow.keySet()) {
            putUnlessBlob(rawRecord, field, forcedForRow.get(field));
        }
    }

    private static void putUnlessBlob(Map<String, Object> rawRecord, String field, Object value) {
        if (!(value instanceof Blob)) {
            rawRecord.put(field, value);
        }
    }

    private List<Map<String, Object>> forcedValuesPerRow() {
        List<Map<String, Object>> perRow = new List<Map<String, Object>>();
        for (Integer row = 0; row < this.records.size(); row++) {
            perRow.add(this.forcedValuesForRow(row));
        }
        return perRow;
    }

    private Map<String, Object> forcedValuesForRow(Integer row) {
        Map<String, Object> here = new Map<String, Object>();
        for (SObjectField field : this.uniformValueByField.keySet()) {
            here.put(fieldName(field), this.uniformValueByField.get(field));
        }
        for (SObjectField field : this.perRowValuesByField.keySet()) {
            here.put(fieldName(field), this.perRowValuesByField.get(field)[row]);
        }
        return here;
    }

    private static Object rawOf(SObject record) {
        if (record == null) {
            return null;
        }
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(record));
        XFTY_BlobCarrier.keepOut(raw, XFTY_BlobCarrier.blobFieldNames(record));
        return raw;
    }

    private static Map<String, Object> subqueryOf(List<SObject> children) {
        List<Object> rawChildren = new List<Object>();
        for (SObject child : children) {
            rawChildren.add(rawOf(child));
        }
        return new Map<String, Object>{
                'totalSize' => rawChildren.size(),
                'done' => DONE,
                'records' => rawChildren
        };
    }

    private static String fieldName(SObjectField field) {
        return field.getDescribe().getName();
    }

    private Type listType() {
        String sObjectName = this.records[0].getSObjectType()
                .getDescribe()
                .getName();
        return Type.forName('List<' + sObjectName + '>');
    }

    private void rejectMisalignedGrafts() {
        Integer rows = this.records.size();
        for (String relationshipName : this.parentByRelationshipName.keySet()) {
            rejectWrongLength(relationshipName, this.parentByRelationshipName.get(relationshipName).size(), rows);
        }
        for (String relationshipName : this.childrenByRelationshipName.keySet()) {
            rejectWrongLength(relationshipName, this.childrenByRelationshipName.get(relationshipName).size(), rows);
        }
        for (SObjectField field : this.perRowValuesByField.keySet()) {
            rejectWrongLength('valuePerRow(' + fieldName(field) + ')', this.perRowValuesByField.get(field).size(), rows);
        }
    }

    private static void rejectWrongLength(String label, Integer actual, Integer expected) {
        if (actual == expected) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'XFTY_SObjectInjector: ' + label + ' has ' + actual + ' entries but there are ' + expected
                        + ' records - grafts must align 1:1 with the records.'
        );
    }
}
